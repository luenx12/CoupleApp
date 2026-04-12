using CoupleApp.Core.Entities;

namespace CoupleApp.Core.Interfaces.Repositories;

/// <summary>
/// Message-specific repository — handles E2EE conversation queries.
/// </summary>
public interface IMessageRepository : IRepository<Message>
{
    /// <summary>
    /// Returns paginated conversation history between two users.
    /// The correct ciphertext (sender vs receiver copy) is resolved by the caller.
    /// </summary>
    Task<(IEnumerable<Message> Items, int TotalCount)> GetHistoryAsync(
        Guid userId,
        Guid partnerId,
        int page,
        int pageSize);

    /// <summary>
    /// Marks a message as read and sets ReadAt timestamp.
    /// </summary>
    Task<bool> MarkAsReadAsync(Guid messageId, Guid receiverUserId);

    /// <summary>
    /// Soft-deletes a message: wipes ciphertext, sets IsDeleted = true.
    /// Only the original sender is allowed to delete.
    /// </summary>
    Task<bool> SoftDeleteAsync(Guid messageId, Guid senderUserId);
}
