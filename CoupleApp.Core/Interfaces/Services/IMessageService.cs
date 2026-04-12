using CoupleApp.Core.Entities;

namespace CoupleApp.Core.Interfaces.Services;

/// <summary>
/// Service contract for message operations.
/// All methods operate on encrypted payloads — Zero-Leak principle.
/// </summary>
public interface IMessageService
{
    /// <summary>Persist and deliver a text message (E2EE ciphertext only).</summary>
    Task<Message> SendTextAsync(
        Guid senderId,
        Guid receiverId,
        string encryptedText,
        string? encryptedTextForSender,
        string? iv);

    /// <summary>Persist and deliver a media message (image / voice / sticker).</summary>
    Task<Message> SendMediaAsync(
        Guid senderId,
        Guid receiverId,
        string encryptedText,
        string? encryptedTextForSender,
        string? iv,
        string mediaId,
        MessageType type);

    /// <summary>Return paginated conversation history between two users.</summary>
    Task<(IEnumerable<Message> Items, int TotalCount)> GetHistoryAsync(
        Guid userId,
        Guid partnerId,
        int page,
        int pageSize);

    /// <summary>Soft-delete a sent message (sender only). Wipes ciphertext.</summary>
    Task<bool> DeleteMessageAsync(Guid messageId, Guid senderUserId);

    /// <summary>Mark a received message as read.</summary>
    Task<bool> MarkAsReadAsync(Guid messageId, Guid receiverUserId);
}
