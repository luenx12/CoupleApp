// ═══════════════════════════════════════════════════════════════════════════════
// OutboxMessage — Gönderilemeyen mesajlar için kuyruk modeli
// SQLite outbox tablosunda saklanır, bağlantı gelince sırayla flush edilir.
// ═══════════════════════════════════════════════════════════════════════════════

enum OutboxStatus { pending, sent, failed }

class OutboxMessage {
  const OutboxMessage({
    required this.localId,
    required this.encryptedText,
    required this.encryptedTextForSender,
    required this.iv,
    required this.type,
    required this.createdAt,
    this.mediaId,
    this.status = OutboxStatus.pending,
    this.retryCount = 0,
  });

  /// Yerel UUID — MessageModel.id ile eşleşir (optimistic UI)
  final String localId;

  /// Partner için şifreli metin (Base64)
  final String encryptedText;

  /// Gönderici için şifreli metin (Base64)
  final String encryptedTextForSender;

  /// IV / nonce (Base64) — opsiyonel
  final String iv;

  /// Medya mesajı için server media ID
  final String? mediaId;

  /// 0=text, 1=image
  final int type;

  final DateTime createdAt;
  final OutboxStatus status;
  final int retryCount;

  static const tableName = 'outbox_messages';

  Map<String, dynamic> toMap() => {
    'local_id':                   localId,
    'encrypted_text':             encryptedText,
    'encrypted_text_for_sender':  encryptedTextForSender,
    'iv':                         iv,
    'media_id':                   mediaId,
    'type':                       type,
    'created_at':                 createdAt.millisecondsSinceEpoch,
    'status':                     status.index,
    'retry_count':                retryCount,
  };

  factory OutboxMessage.fromMap(Map<String, dynamic> m) => OutboxMessage(
    localId:                  m['local_id'] as String,
    encryptedText:            m['encrypted_text'] as String,
    encryptedTextForSender:   m['encrypted_text_for_sender'] as String,
    iv:                       m['iv'] as String? ?? '',
    mediaId:                  m['media_id'] as String?,
    type:                     m['type'] as int,
    createdAt:                DateTime.fromMillisecondsSinceEpoch(m['created_at'] as int),
    status:                   OutboxStatus.values[m['status'] as int],
    retryCount:               m['retry_count'] as int? ?? 0,
  );

  OutboxMessage copyWith({
    OutboxStatus? status,
    int? retryCount,
  }) =>
      OutboxMessage(
        localId:                 localId,
        encryptedText:           encryptedText,
        encryptedTextForSender:  encryptedTextForSender,
        iv:                      iv,
        mediaId:                 mediaId,
        type:                    type,
        createdAt:               createdAt,
        status:                  status ?? this.status,
        retryCount:              retryCount ?? this.retryCount,
      );
}
