// ═══════════════════════════════════════════════════════════════════════════════
// ChatDatabase — sqflite local message store
//
// Yalnızca çözülmüş plaintext metin mesajlar saklanır.
// Medya mesajları için sadece yerel .aes dosya yolu saklanır.
// ═══════════════════════════════════════════════════════════════════════════════

import 'package:sqflite/sqflite.dart';
import '../domain/message_model.dart';


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
      version: 1,
      onCreate: _onCreate,
    );
  }

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
        media_deleted    INTEGER NOT NULL DEFAULT 0
      )
    ''');
    // İndeks: konuşmaya göre sıralı çekme
    await db.execute(
      'CREATE INDEX idx_messages_conv ON ${MessageModel.tableName}(sender_id, receiver_id, sent_at)',
    );
  }

  // ── CRUD ────────────────────────────────────────────────────────────────

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

  Future<void> deleteAll() async {
    final db = await database;
    await db.delete(MessageModel.tableName);
  }
}
