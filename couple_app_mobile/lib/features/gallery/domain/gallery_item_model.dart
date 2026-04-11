class GalleryItemModel {
  const GalleryItemModel({
    required this.id,
    required this.createdAt,
    this.lockedUntil,
    required this.isLocked,
    required this.mediaId,
    required this.uploaderId,
  });

  final String id;
  final DateTime createdAt;
  final DateTime? lockedUntil;
  final bool isLocked;
  final String mediaId;
  final String uploaderId;

  factory GalleryItemModel.fromMap(Map<String, dynamic> map) {
    return GalleryItemModel(
      id: map['id'] ?? '',
      createdAt: DateTime.parse(map['createdAt']).toLocal(),
      lockedUntil: map['lockedUntil'] != null
          ? DateTime.parse(map['lockedUntil']).toLocal()
          : null,
      isLocked: map['isLocked'] == true,
      mediaId: map['mediaId'] ?? '',
      uploaderId: map['uploaderId'] ?? '',
    );
  }
}
