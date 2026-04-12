using CoupleApp.Application.Commands;
using CoupleApp.Core.Interfaces.Repositories;
using MediatR;

namespace CoupleApp.Application.Handlers;

/// <summary>
/// Handles DeleteMessageCommand: soft-deletes and wipes ciphertext.
/// Only the original sender is authorized.
/// </summary>
public sealed class DeleteMessageCommandHandler
    : IRequestHandler<DeleteMessageCommand, bool>
{
    private readonly IMessageRepository _messages;

    public DeleteMessageCommandHandler(IMessageRepository messages)
        => _messages = messages;

    public async Task<bool> Handle(
        DeleteMessageCommand request,
        CancellationToken cancellationToken)
        => await _messages.SoftDeleteAsync(request.MessageId, request.RequestingUserId);
}
