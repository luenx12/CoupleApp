using CoupleApp.Core.Entities;
using CoupleApp.Core.Interfaces.Repositories;
using CoupleApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace CoupleApp.Infrastructure.Repositories;

/// <summary>
/// EF Core implementation of IMessageRepository.
/// All queries filter out soft-deleted messages.
/// </summary>
public sealed class MessageRepository : Repository<Message>, IMessageRepository
{
    public MessageRepository(AppDbContext context) : base(context) { }

    public async Task<(IEnumerable<Message> Items, int TotalCount)> GetHistoryAsync(
        Guid userId,
        Guid partnerId,
        int page,
        int pageSize)
    {
        var query = _dbSet
            .Where(m =>
                !m.IsDeleted &&
                ((m.SenderId == userId   && m.ReceiverId == partnerId) ||
                 (m.SenderId == partnerId && m.ReceiverId == userId)))
            .OrderByDescending(m => m.SentAt);

        var totalCount = await query.CountAsync();

        var items = await query
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .ToListAsync();

        return (items, totalCount);
    }

    public async Task<bool> MarkAsReadAsync(Guid messageId, Guid receiverUserId)
    {
        var message = await _dbSet.FindAsync(messageId);
        if (message is null || message.ReceiverId != receiverUserId) return false;
        if (message.IsRead) return true; // already read — idempotent

        message.IsRead = true;
        message.ReadAt = DateTime.UtcNow;
        await _context.SaveChangesAsync();
        return true;
    }

    public async Task<bool> SoftDeleteAsync(Guid messageId, Guid senderUserId)
    {
        var message = await _dbSet.FindAsync(messageId);
        if (message is null || message.SenderId != senderUserId) return false;

        message.IsDeleted             = true;
        message.EncryptedText         = string.Empty; // Wipe ciphertext — Zero-Leak
        message.EncryptedTextForSender = null;
        await _context.SaveChangesAsync();
        return true;
    }
}
