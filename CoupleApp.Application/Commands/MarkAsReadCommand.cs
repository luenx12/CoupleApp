using MediatR;

namespace CoupleApp.Application.Commands;

/// <summary>
/// Marks a message as read. Only the receiver may mark.
/// Returns true on success.
/// </summary>
public sealed record MarkAsReadCommand(
    Guid MessageId,
    Guid ReceiverUserId
) : IRequest<bool>;
