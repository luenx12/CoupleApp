using CoupleApp.Application.Commands;
using CoupleApp.Core.Interfaces.Repositories;
using MediatR;

namespace CoupleApp.Application.Handlers;

/// <summary>
/// Handles MarkAsReadCommand: marks message as read, sets ReadAt.
/// Only the receiver is authorized.
/// </summary>
public sealed class MarkAsReadCommandHandler
    : IRequestHandler<MarkAsReadCommand, bool>
{
    private readonly IMessageRepository _messages;

    public MarkAsReadCommandHandler(IMessageRepository messages)
        => _messages = messages;

    public async Task<bool> Handle(
        MarkAsReadCommand request,
        CancellationToken cancellationToken)
        => await _messages.MarkAsReadAsync(request.MessageId, request.ReceiverUserId);
}
