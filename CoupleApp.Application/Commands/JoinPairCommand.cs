using MediatR;

namespace CoupleApp.Application.Commands;

/// <summary>
/// Command to join a pair using a 6-digit code.
/// Returns true on success.
/// </summary>
public record JoinPairCommand(Guid UserId, string InviteCode) : IRequest<bool>;
