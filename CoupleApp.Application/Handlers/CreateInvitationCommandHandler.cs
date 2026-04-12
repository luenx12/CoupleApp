using CoupleApp.Core.Entities;
using CoupleApp.Core.Interfaces.Repositories;
using CoupleApp.Application.Commands;
using MediatR;
using MediatR;

namespace CoupleApp.Application.Handlers;

public class CreateInvitationCommandHandler : IRequestHandler<CreateInvitationCommand, string>
{
    private readonly IUserRepository _users;

    public CreateInvitationCommandHandler(IUserRepository users)
        => _users = users;

    public async Task<string> Handle(CreateInvitationCommand request, CancellationToken cancellationToken)
    {
        // Check if user is already paired
        var existingPair = await _users.GetPairByUserIdAsync(request.UserId);
        if (existingPair is not null)
            throw new InvalidOperationException("You are already paired.");

        // Check if there is an active pending invitation
        var activeInv = await _users.GetActiveInvitationAsync(request.UserId);
        if (activeInv is not null)
            return activeInv.InviteCode;

        // Generate a new 6-digit random code
        var code = GenerateCode();
        
        var invitation = new CoupleInvitation
        {
            InviterUserId = request.UserId,
            InviteCode    = code,
            ExpiresAt     = DateTime.UtcNow.AddHours(24)
        };

        await _users.AddInvitationAsync(invitation);
        await _users.SaveChangesAsync();

        return code;
    }

    private string GenerateCode()
    {
        var random = new Random();
        return random.Next(100000, 999999).ToString();
    }
}
