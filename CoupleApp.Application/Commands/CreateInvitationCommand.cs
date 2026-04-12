using MediatR;

namespace CoupleApp.Application.Commands;

/// <summary>
/// Command to generate a new pair invitation code.
/// Returns the generated 6-digit code.
/// </summary>
public record CreateInvitationCommand(Guid UserId) : IRequest<string>;
