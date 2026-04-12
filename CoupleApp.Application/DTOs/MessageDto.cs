using CoupleApp.Core.Entities;

namespace CoupleApp.Application.DTOs;

/// <summary>
/// Outbound DTO for message history — exposes the correct ciphertext per viewer.
/// </summary>
public sealed record MessageHistoryDto(
    Guid Id,
    Guid SenderId,
    Guid ReceiverId,
    string EncryptedText,   // resolved for the requesting user
    string? IV,
    MessageType Type,
    string? MediaId,
    bool IsDelivered,
    bool IsRead,
    DateTime SentAt,
    DateTime? DeliveredAt,
    DateTime? ReadAt);

/// <summary>Request DTO used by SendMessageCommand.</summary>
public sealed record SendMessageRequest(
    Guid SenderId,
    Guid ReceiverId,
    string EncryptedText,
    string? EncryptedTextForSender,
    string? IV,
    MessageType Type = MessageType.Text,
    string? MediaId = null);

/// <summary>Response DTO returned after a message is persisted.</summary>
public sealed record SendMessageResponse(
    Guid MessageId,
    DateTime SentAt,
    bool IsDelivered);
