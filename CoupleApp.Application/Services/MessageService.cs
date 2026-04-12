using CoupleApp.Core.Entities;
using CoupleApp.Core.Interfaces.Repositories;
using CoupleApp.Core.Interfaces.Services;

namespace CoupleApp.Application.Services;

/// <summary>
/// Concrete implementation of IMessageService.
/// Orchestrates repository calls for message operations — Zero-Leak: no plaintext handling.
/// </summary>
public sealed class MessageService : IMessageService
{
    private readonly IMessageRepository _messages;
    private readonly IUserRepository _users;

    public MessageService(IMessageRepository messages, IUserRepository users)
    {
        _messages = messages;
        _users    = users;
    }

    /// <inheritdoc/>
    public async Task<Message> SendTextAsync(
        Guid senderId,
        Guid receiverId,
        string encryptedText,
        string? encryptedTextForSender,
        string? iv)
    {
        var receiver = await _users.GetByIdAsync(receiverId)
            ?? throw new InvalidOperationException($"Receiver {receiverId} not found.");

        var message = new Message
        {
            SenderId               = senderId,
            ReceiverId             = receiverId,
            EncryptedText          = encryptedText,
            EncryptedTextForSender = encryptedTextForSender,
            IV                     = iv,
            Type                   = MessageType.Text,
            SentAt                 = DateTime.UtcNow
        };

        await _messages.AddAsync(message);
        await _messages.SaveChangesAsync();
        return message;
    }

    /// <inheritdoc/>
    public async Task<Message> SendMediaAsync(
        Guid senderId,
        Guid receiverId,
        string encryptedText,
        string? encryptedTextForSender,
        string? iv,
        string mediaId,
        MessageType type)
    {
        if (type == MessageType.Text)
            throw new ArgumentException("Type must be a media type (Image, Voice, Sticker).", nameof(type));

        var receiver = await _users.GetByIdAsync(receiverId)
            ?? throw new InvalidOperationException($"Receiver {receiverId} not found.");

        var message = new Message
        {
            SenderId               = senderId,
            ReceiverId             = receiverId,
            EncryptedText          = encryptedText,
            EncryptedTextForSender = encryptedTextForSender,
            IV                     = iv,
            Type                   = type,
            MediaId                = mediaId,
            SentAt                 = DateTime.UtcNow
        };

        await _messages.AddAsync(message);
        await _messages.SaveChangesAsync();
        return message;
    }

    /// <inheritdoc/>
    public async Task<(IEnumerable<Message> Items, int TotalCount)> GetHistoryAsync(
        Guid userId,
        Guid partnerId,
        int page,
        int pageSize)
        => await _messages.GetHistoryAsync(userId, partnerId, page, pageSize);

    /// <inheritdoc/>
    public async Task<bool> DeleteMessageAsync(Guid messageId, Guid senderUserId)
        => await _messages.SoftDeleteAsync(messageId, senderUserId);

    /// <inheritdoc/>
    public async Task<bool> MarkAsReadAsync(Guid messageId, Guid receiverUserId)
        => await _messages.MarkAsReadAsync(messageId, receiverUserId);
}
