// ═══════════════════════════════════════════════════════════════════════════════
// MessageModel — Domain model for local chat messages
// ═══════════════════════════════════════════════════════════════════════════════

enum MsgType { text, image, voice }

class MessageModel {
  const MessageModel({
    required this.id,
    required this.senderId,
    required this.receiverId,
    required this.plainText,
    required this.type,
    required this.sentAt,
    required this.isMine,
    this.isRead = false,
    this.isDelivered = false,
    this.localMediaPath,
    this.remoteMediaId,
    this.mediaDeleted = false,
  });

  /// Sunucudan gelen UUID (veya local UUID for optimistic messages)
  final String id;
  final String senderId;
  final String receiverId;

  /// Şifresi çözülmüş metin (sadece metin mesajlar için)
  final String plainText;

  final MsgType type;
  final DateTime sentAt;

  /// Bu mesaj benim tarafımdan mı gönderildi?
  final bool isMine;
  final bool isRead;
  final bool isDelivered;

  /// Yerel .aes dosya yolu (medya mesajlar için)
  final String? localMediaPath;

  /// Sunucudaki medya ID — self-destruct DELETE için
  final String? remoteMediaId;

  /// Medya sunucudan silindi mi?
  final bool mediaDeleted;

  MessageModel copyWith({
    bool? isRead,
    bool? isDelivered,
    bool? mediaDeleted,
    String? localMediaPath,
  }) =>
      MessageModel(
        id:             id,
        senderId:       senderId,
        receiverId:     receiverId,
        plainText:      plainText,
        type:           type,
        sentAt:         sentAt,
        isMine:         isMine,
        isRead:         isRead         ?? this.isRead,
        isDelivered:    isDelivered    ?? this.isDelivered,
        localMediaPath: localMediaPath ?? this.localMediaPath,
        remoteMediaId:  remoteMediaId,
        mediaDeleted:   mediaDeleted   ?? this.mediaDeleted,
      );

  // ── sqflite serialization ────────────────────────────────────────────────

  static const _table = 'messages';

  Map<String, dynamic> toMap() => {
    'id':               id,
    'sender_id':        senderId,
    'receiver_id':      receiverId,
    'plain_text':       plainText,
    'type':             type.index,
    'sent_at':          sentAt.millisecondsSinceEpoch,
    'is_mine':          isMine ? 1 : 0,
    'is_read':          isRead ? 1 : 0,
    'is_delivered':     isDelivered ? 1 : 0,
    'local_media_path': localMediaPath,
    'remote_media_id':  remoteMediaId,
    'media_deleted':    mediaDeleted ? 1 : 0,
  };

  factory MessageModel.fromMap(Map<String, dynamic> m) => MessageModel(
    id:             m['id'] as String,
    senderId:       m['sender_id'] as String,
    receiverId:     m['receiver_id'] as String,
    plainText:      m['plain_text'] as String? ?? '',
    type:           MsgType.values[m['type'] as int? ?? 0],
    sentAt:         DateTime.fromMillisecondsSinceEpoch(m['sent_at'] as int),
    isMine:         (m['is_mine'] as int?) == 1,
    isRead:         (m['is_read'] as int?) == 1,
    isDelivered:    (m['is_delivered'] as int?) == 1,
    localMediaPath: m['local_media_path'] as String?,
    remoteMediaId:  m['remote_media_id'] as String?,
    mediaDeleted:   (m['media_deleted'] as int?) == 1,
  );

  static String get tableName => _table;
}
