using CoupleApp.Core.Entities;
using CoupleApp.Core.Interfaces.Repositories;
using CoupleApp.Application.Commands;
using MediatR;
using MediatR;

namespace CoupleApp.Application.Handlers;

public class JoinPairCommandHandler : IRequestHandler<JoinPairCommand, bool>
{
    private readonly IUserRepository _users;

    public JoinPairCommandHandler(IUserRepository users)
        => _users = users;

    public async Task<bool> Handle(JoinPairCommand request, CancellationToken cancellationToken)
    {
        // Is user already paired?
        var existingPair = await _users.GetPairByUserIdAsync(request.UserId);
        if (existingPair is not null)
            throw new InvalidOperationException("You are already paired.");

        // Find the invitation
        var invitation = await _users.GetInvitationByCodeAsync(request.InviteCode);
        
        if (invitation is null || 
            invitation.Status != InvitationStatus.Pending || 
            invitation.ExpiresAt < DateTime.UtcNow)
        {
            return false; // Invalid or expired
        }

        // Cannot pair with yourself
        if (invitation.InviterUserId == request.UserId)
            return false;

        // Ensure inviter isn't paired already (race condition edge case)
        var inviterPair = await _users.GetPairByUserIdAsync(invitation.InviterUserId);
        if (inviterPair is not null)
        {
            invitation.Status = InvitationStatus.Expired;
            await _users.SaveChangesAsync();
            return false;
        }

        // Form the pair
        var pair = new CouplePair
        {
            User1Id = invitation.InviterUserId,
            User2Id = request.UserId
        };

        invitation.Status = InvitationStatus.Accepted;

        await _users.AddPairAsync(pair);
        await _users.SaveChangesAsync();

        return true;
    }
}
