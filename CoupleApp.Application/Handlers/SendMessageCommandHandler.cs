using CoupleApp.Application.Commands;
using CoupleApp.Application.DTOs;
using CoupleApp.Core.Entities;
using CoupleApp.Core.Interfaces.Repositories;
using MediatR;

namespace CoupleApp.Application.Handlers;

/// <summary>
/// Handles SendMessageCommand: persists E2EE ciphertext and returns delivery metadata.
/// Does NOT look at plaintext — Zero-Leak compliant.
/// </summary>
public sealed class SendMessageCommandHandler
    : IRequestHandler<SendMessageCommand, SendMessageResponse>
{
    private readonly IMessageRepository _messages;
    private readonly IUserRepository _users;

    public SendMessageCommandHandler(
        IMessageRepository messages,
        IUserRepository users)
    {
        _messages = messages;
        _users    = users;
    }

    public async Task<SendMessageResponse> Handle(
        SendMessageCommand request,
        CancellationToken cancellationToken)
    {
        // Validate receiver exists
        var receiver = await _users.GetByIdAsync(request.ReceiverId)
            ?? throw new InvalidOperationException($"Receiver {request.ReceiverId} not found.");

        var message = new Message
        {
            SenderId               = request.SenderId,
            ReceiverId             = request.ReceiverId,
            EncryptedText          = request.EncryptedText,
            EncryptedTextForSender = request.EncryptedTextForSender,
            IV                     = request.IV,
            Type                   = request.Type,
            MediaId                = request.MediaId,
            IsDelivered            = false,
            SentAt                 = DateTime.UtcNow
        };

        await _messages.AddAsync(message);
        await _messages.SaveChangesAsync();

        return new SendMessageResponse(message.Id, message.SentAt, message.IsDelivered);
    }
}
