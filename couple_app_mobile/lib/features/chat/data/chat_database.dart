// ═══════════════════════════════════════════════════════════════════════════════
// ChatDatabase — sqflite local message store  (v2: outbox tablosu eklendi)
//
// v1 → messages tablosu (plaintext + medya yolu)
// v2 → outbox_messages tablosu + messages.send_status kolonu
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:sqflite/sqflite.dart';
import '../domain/message_model.dart';
import '../domain/outbox_message.dart';


class ChatDatabase {
  ChatDatabase._();
  static final ChatDatabase instance = ChatDatabase._();

  Database? _db;

  // ── Singleton DB bağlantısı ──────────────────────────────────────────────
  Future<Database> get database async {
    _db ??= await _open();
    return _db!;
  }

  Future<Database> _open() async {
    final dir  = await getDatabasesPath();
    final path = '$dir/couple_chat.db';

    return openDatabase(
      path,
      version: 2,               // ← v2
      onCreate:  _onCreate,
      onUpgrade: _onUpgrade,
    );
  }

  // ── Schema v1 ────────────────────────────────────────────────────────────
  Future<void> _onCreate(Database db, int version) async {
    await db.execute('''
      CREATE TABLE ${MessageModel.tableName} (
        id               TEXT    PRIMARY KEY,
        sender_id        TEXT    NOT NULL,
        receiver_id      TEXT    NOT NULL,
        plain_text       TEXT    NOT NULL DEFAULT '',
        type             INTEGER NOT NULL DEFAULT 0,
        sent_at          INTEGER NOT NULL,
        is_mine          INTEGER NOT NULL DEFAULT 0,
        is_read          INTEGER NOT NULL DEFAULT 0,
        is_delivered     INTEGER NOT NULL DEFAULT 1,
        local_media_path TEXT,
        remote_media_id  TEXT,
        media_deleted    INTEGER NOT NULL DEFAULT 0,
        send_status      INTEGER NOT NULL DEFAULT 0
      )
    ''');
    await db.execute(
      'CREATE INDEX idx_messages_conv ON ${MessageModel.tableName}(sender_id, receiver_id, sent_at)',
    );

    await _createOutboxTable(db);
  }

  // ── Migration v1 → v2 ────────────────────────────────────────────────────
  Future<void> _onUpgrade(Database db, int oldVersion, int newVersion) async {
    if (oldVersion < 2) {
      // Yeni kolon mevcut tabloya ekle
      try {
        await db.execute(
          'ALTER TABLE ${MessageModel.tableName} ADD COLUMN send_status INTEGER NOT NULL DEFAULT 0',
        );
      } catch (_) {
        // Kolon zaten varsa sessizce geç
      }
      await _createOutboxTable(db);
    }
  }

  // ── Outbox tablosu ───────────────────────────────────────────────────────
  Future<void> _createOutboxTable(Database db) async {
    await db.execute('''
      CREATE TABLE IF NOT EXISTS ${OutboxMessage.tableName} (
        local_id                   TEXT    PRIMARY KEY,
        encrypted_text             TEXT    NOT NULL,
        encrypted_text_for_sender  TEXT    NOT NULL,
        iv                         TEXT    NOT NULL DEFAULT '',
        media_id                   TEXT,
        type                       INTEGER NOT NULL DEFAULT 0,
        created_at                 INTEGER NOT NULL,
        status                     INTEGER NOT NULL DEFAULT 0,
        retry_count                INTEGER NOT NULL DEFAULT 0
      )
    ''');
  }

  // ── Messages CRUD ────────────────────────────────────────────────────────

  Future<void> insertMessage(MessageModel msg) async {
    final db = await database;
    await db.insert(
      MessageModel.tableName,
      msg.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  /// Son [limit] mesajı döndür (sent_at ASC — ekranda yukarıdan aşağı)
  Future<List<MessageModel>> getMessages({
    required String myId,
    required String partnerId,
    int limit = 100,
  }) async {
    final db = await database;
    final rows = await db.query(
      MessageModel.tableName,
      where: '''
        (sender_id = ? AND receiver_id = ?)
        OR
        (sender_id = ? AND receiver_id = ?)
      ''',
      whereArgs: [myId, partnerId, partnerId, myId],
      orderBy: 'sent_at ASC',
      limit: limit,
    );
    return rows.map(MessageModel.fromMap).toList();
  }

  Future<void> markRead(String messageId) async {
    final db = await database;
    await db.update(
      MessageModel.tableName,
      {'is_read': 1},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> markMediaDeleted(String messageId) async {
    final db = await database;
    await db.update(
      MessageModel.tableName,
      {'media_deleted': 1},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> updateLocalMediaPath(String messageId, String path) async {
    final db = await database;
    await db.update(
      MessageModel.tableName,
      {'local_media_path': path},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  /// Mesajın sunucu ID ve send_status'unu güncelle (optimistic → confirmed)
  Future<void> confirmMessage({
    required String localId,
    required String serverId,
    required int sendStatus,
  }) async {
    final db = await database;
    await db.update(
      MessageModel.tableName,
      {'id': serverId, 'send_status': sendStatus, 'is_delivered': 1},
      where: 'id = ?',
      whereArgs: [localId],
    );
  }

  /// Sadece send_status güncelle (pending → failed vs.)
  Future<void> updateSendStatus(String messageId, SendStatus status) async {
    final db = await database;
    await db.update(
      MessageModel.tableName,
      {'send_status': status.index},
      where: 'id = ?',
      whereArgs: [messageId],
    );
  }

  Future<void> deleteAll() async {
    final db = await database;
    await db.delete(MessageModel.tableName);
  }

  // ── Outbox CRUD ──────────────────────────────────────────────────────────

  Future<void> insertOutbox(OutboxMessage msg) async {
    final db = await database;
    await db.insert(
      OutboxMessage.tableName,
      msg.toMap(),
      conflictAlgorithm: ConflictAlgorithm.replace,
    );
  }

  Future<List<OutboxMessage>> getPendingOutbox() async {
    final db = await database;
    final rows = await db.query(
      OutboxMessage.tableName,
      where: 'status = ?',
      whereArgs: [OutboxStatus.pending.index],
      orderBy: 'created_at ASC',
    );
    return rows.map(OutboxMessage.fromMap).toList();
  }

  Future<void> markOutboxSent(String localId) async {
    final db = await database;
    await db.update(
      OutboxMessage.tableName,
      {'status': OutboxStatus.sent.index},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> markOutboxFailed(String localId) async {
    final db = await database;
    await db.update(
      OutboxMessage.tableName,
      {'status': OutboxStatus.failed.index},
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }

  Future<void> incrementOutboxRetry(String localId) async {
    final db = await database;
    await db.rawUpdate(
      'UPDATE ${OutboxMessage.tableName} SET retry_count = retry_count + 1 WHERE local_id = ?',
      [localId],
    );
  }

  Future<void> deleteOutbox(String localId) async {
    final db = await database;
    await db.delete(
      OutboxMessage.tableName,
      where: 'local_id = ?',
      whereArgs: [localId],
    );
  }
}
