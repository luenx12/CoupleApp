namespace CoupleApp.Application.DTOs;

public sealed record GalleryItemDto(
    Guid Id,
    Guid UploaderId,
    string MediaId,       // resolved for the requesting user
    DateTime CreatedAt,
    DateTime? LockedUntil,
    bool IsLocked);
