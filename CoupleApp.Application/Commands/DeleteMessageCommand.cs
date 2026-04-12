using MediatR;

namespace CoupleApp.Application.Commands;

/// <summary>
/// Soft-deletes a message. Only the sender may delete.
/// Returns true if deletion succeeded, false if not found / unauthorized.
/// </summary>
public sealed record DeleteMessageCommand(
    Guid MessageId,
    Guid RequestingUserId
) : IRequest<bool>;
