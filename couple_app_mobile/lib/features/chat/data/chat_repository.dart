// ═══════════════════════════════════════════════════════════════════════════════
// ChatRepository — Bridge between DB, API and SignalR
// v2: Offline-First Outbox Queue + Exponential Backoff Retry
// ═══════════════════════════════════════════════════════════════════════════════

import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:dio/dio.dart';
import 'package:image_picker/image_picker.dart';
import 'package:uuid/uuid.dart';
import '../../crypto/crypto_service.dart';
import '../../media/media_storage_service.dart';
import '../domain/message_model.dart';
import '../domain/outbox_message.dart';
import 'chat_database.dart';
import 'media_api_service.dart';
import 'signalr_service.dart';


class ChatRepository {
  ChatRepository({
    required this.myId,
    required this.partnerId,
    required this.partnerPublicKeyPem,
    required this.crypto,
    required this.mediaStorage,
    required this.signalR,
    required this.mediaApi,
    required this.dio,
  });

  final String myId;
  final String partnerId;
  final String partnerPublicKeyPem;

  final CryptoService crypto;
  final MediaStorageService mediaStorage;
  final SignalRService signalR;
  final MediaApiService mediaApi;
  final Dio dio;

  final _db   = ChatDatabase.instance;
  final _uuid = const Uuid();

  static const int _maxRetries = 5;

  /// Flush işlemi çalışıyor mu? paralel flush önlemek için.
  bool _flushing = false;

  // ── Veritabanından mesajları yükle ──────────────────────────────────────

  Future<List<MessageModel>> loadLocalMessages() =>
      _db.getMessages(myId: myId, partnerId: partnerId);

  // ── Sunucudan geçmişi çek + DB'ye kaydet ───────────────────────────────

  Future<List<MessageModel>> fetchAndSyncHistory() async {
    try {
      final resp = await dio.get(
        '/Messages/history/$partnerId',
        queryParameters: {'page': 1, 'pageSize': 50},
      );
      final list = (resp.data as List).cast<Map<String, dynamic>>();
      final messages = <MessageModel>[];

      for (final raw in list.reversed) {
        final isMine = (raw['senderId'] as String) == myId;
        final encText = raw['encryptedText'] as String? ?? '';
        final type = MsgType.values[raw['type'] as int? ?? 0];

        String plainText = '';
        if (type == MsgType.text && encText.isNotEmpty) {
          try {
            final payload = EncryptedPayload.fromBase64(encText);
            plainText = crypto.decryptText(payload);
          } catch (_) {
            plainText = '[şifre çözülemedi]';
          }
        }

        final msg = MessageModel(
          id:           raw['id'] as String,
          senderId:     raw['senderId'] as String,
          receiverId:   raw['receiverId'] as String,
          plainText:    plainText,
          type:         type,
          sentAt:       DateTime.parse(raw['sentAt'] as String).toLocal(),
          isMine:       isMine,
          isRead:       raw['isRead'] as bool? ?? false,
          isDelivered:  raw['isDelivered'] as bool? ?? false,
          remoteMediaId: raw['mediaId'] as String?,
          sendStatus:   SendStatus.sent,
        );

        await _db.insertMessage(msg);
        messages.add(msg);
      }
      return messages;
    } catch (_) {
      // Offline → yerel DB'den dön
      return loadLocalMessages();
    }
  }

  // ── Metin mesajı gönder (offline-first) ────────────────────────────────

  Future<MessageModel> sendTextMessage(String text) async {
    // 1. İki kopya şifrele (alıcı + gönderici için)
    final forPartner = crypto.encrypt(
      Uint8List.fromList(utf8.encode(text)),
      partnerPublicKeyPem,
    );
    final forSelf = crypto.encryptForSelf(
      Uint8List.fromList(utf8.encode(text)),
    );

    final tempId = _uuid.v4();

    // 2. Optimistik UI için DB'ye kaydet (pending)
    final msg = MessageModel(
      id:          tempId,
      senderId:    myId,
      receiverId:  partnerId,
      plainText:   text,
      type:        MsgType.text,
      sentAt:      DateTime.now(),
      isMine:      true,
      isDelivered: false,
      sendStatus:  SendStatus.pending,
    );
    await _db.insertMessage(msg);

    // 3. Outbox'a yaz
    final outbox = OutboxMessage(
      localId:                tempId,
      encryptedText:          forPartner.toBase64(),
      encryptedTextForSender: forSelf.toBase64(),
      iv:                     '',
      type:                   0,
      createdAt:              msg.sentAt,
    );
    await _db.insertOutbox(outbox);

    return msg;
  }

  // ── Medya mesajı gönder (image_picker XFile) ────────────────────────────

  Future<MessageModel> sendMediaMessage(XFile file) async {
    final rawBytes = Uint8List.fromList(await file.readAsBytes());
    final fileId   = _uuid.v4();

    // 1. Alıcı için şifrele + API'ye yükle (şifreli blob)
    final encryptedPayload = crypto.encrypt(rawBytes, partnerPublicKeyPem);
    final encryptedBytes   = encryptedPayload.toBytes();

    final mediaId = await mediaApi.uploadEncryptedMedia(
      encryptedBytes: encryptedBytes,
      messageId:      fileId,
    );

    // 2. Kendi kopyamızı yerel .aes olarak kaydet
    final selfPath = await mediaStorage.saveEncryptedMediaForSelf(
      rawBytes: rawBytes,
      fileId:   fileId,
    );

    // 3. Sunucu mesaj kaydı için minimal metin
    final forPartner = crypto.encrypt(
      Uint8List.fromList(utf8.encode('[image]')),
      partnerPublicKeyPem,
    );
    final forSelf = crypto.encryptForSelf(
      Uint8List.fromList(utf8.encode('[image]')),
    );

    // 4. DB'ye kaydet (pending)
    final msg = MessageModel(
      id:             fileId,
      senderId:       myId,
      receiverId:     partnerId,
      plainText:      '',
      type:           MsgType.image,
      sentAt:         DateTime.now(),
      isMine:         true,
      localMediaPath: selfPath,
      remoteMediaId:  mediaId,
      sendStatus:     SendStatus.pending,
    );
    await _db.insertMessage(msg);

    // 5. Outbox'a yaz
    final outbox = OutboxMessage(
      localId:                fileId,
      encryptedText:          forPartner.toBase64(),
      encryptedTextForSender: forSelf.toBase64(),
      iv:                     '',
      mediaId:                mediaId,
      type:                   1,
      createdAt:              msg.sentAt,
    );
    await _db.insertOutbox(outbox);

    return msg;
  }

  // ── Outbox Flush — bağlantı gelince çağrılır ────────────────────────────

  /// Tüm pending outbox mesajlarını sırayla SignalR'a gönderir.
  /// Exponential backoff: 1s, 2s, 4s, 8s, 16s → max [_maxRetries] deneme.
  Future<void> flushOutbox({
    required void Function(String localId, SendStatus status) onStatusChanged,
  }) async {
    if (_flushing) return;
    _flushing = true;

    try {
      final pending = await _db.getPendingOutbox();

      for (final item in pending) {
        await _trySend(item, onStatusChanged: onStatusChanged);
      }
    } finally {
      _flushing = false;
    }
  }

  Future<void> _trySend(
    OutboxMessage item, {
    required void Function(String localId, SendStatus status) onStatusChanged,
  }) async {
    final currentRetry = item.retryCount;

    if (currentRetry >= _maxRetries) {
      // Max retry aşıldı → kalıcı hata
      await _db.markOutboxFailed(item.localId);
      await _db.updateSendStatus(item.localId, SendStatus.failed);
      onStatusChanged(item.localId, SendStatus.failed);
      return;
    }

    // Exponential backoff: 1s, 2s, 4s, 8s, 16s
    if (currentRetry > 0) {
      final delayMs = (1000 * (1 << (currentRetry - 1))).clamp(0, 16000);
      await Future.delayed(Duration(milliseconds: delayMs));
    }

    try {
      await signalR.sendMessage(
        receiverId:             partnerId,
        encryptedText:          item.encryptedText,
        encryptedTextForSender: item.encryptedTextForSender,
        mediaId:                item.mediaId,
        type:                   item.type,
      );

      // Başarılı → outbox'tan sil, mesaj durumunu güncelle
      await _db.markOutboxSent(item.localId);
      await _db.updateSendStatus(item.localId, SendStatus.sent);
      onStatusChanged(item.localId, SendStatus.sent);
    } catch (_) {
      // Başarısız → retry sayısını artır, bir sonraki flush'ta tekrar dene
      await _db.incrementOutboxRetry(item.localId);

      final newRetry = currentRetry + 1;
      if (newRetry >= _maxRetries) {
        await _db.markOutboxFailed(item.localId);
        await _db.updateSendStatus(item.localId, SendStatus.failed);
        onStatusChanged(item.localId, SendStatus.failed);
      }
      // Henüz max değilse pending kalır, bir sonraki flushta tekrar denenecek
    }
  }

  // ── Gelen mesajı işle ───────────────────────────────────────────────────

  Future<MessageModel?> handleIncoming(Map<String, dynamic> dto) async {
    final encText  = dto['encryptedText'] as String? ?? '';
    final typeIdx  = dto['type'] as int? ?? 0;
    final type     = MsgType.values[typeIdx];
    final mediaId  = dto['mediaId'] as String?;
    final msgId    = dto['messageId'] as String? ?? _uuid.v4();

    String plainText = '';

    if (type == MsgType.text && encText.isNotEmpty) {
      try {
        final payload = EncryptedPayload.fromBase64(encText);
        plainText = crypto.decryptText(payload);
      } catch (_) {
        plainText = '[şifre çözülemedi]';
      }
    } else if (type == MsgType.image && mediaId != null) {
      plainText = '';
    }

    final msg = MessageModel(
      id:            msgId,
      senderId:      dto['senderId'] as String? ?? partnerId,
      receiverId:    myId,
      plainText:     plainText,
      type:          type,
      sentAt:        DateTime.now(),
      isMine:        false,
      localMediaPath: null,
      remoteMediaId: mediaId,
      sendStatus:    SendStatus.sent,
    );

    await _db.insertMessage(msg);
    return msg;
  }

  // ── Medya görüntülendi → self-destruct ─────────────────────────────────

  Future<void> notifyMediaViewed(String messageId, String mediaId) async {
    try {
      await mediaApi.selfDestruct(mediaId);
      await _db.markMediaDeleted(messageId);
    } catch (_) {
      // Sessizce geç — idemptotent
    }
  }

  // ── Gelen medyayı indir + yerel .aes olarak kaydet ─────────────────────

  Future<String?> downloadAndSaveMedia({
    required String messageId,
    required String mediaId,
  }) async {
    try {
      final encBytes = await mediaApi.downloadEncryptedMedia(mediaId);
      final file = await mediaStorage.saveRawEncryptedBytes(
        bytes:  encBytes,
        fileId: messageId,
      );
      await _db.updateLocalMediaPath(messageId, file);
      return file;
    } catch (_) {
      return null;
    }
  }
}
