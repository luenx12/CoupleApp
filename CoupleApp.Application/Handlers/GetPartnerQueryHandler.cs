using CoupleApp.Application.DTOs;
using CoupleApp.Core.Interfaces.Repositories;
using CoupleApp.Application.Queries;
using MediatR;
using MediatR;

namespace CoupleApp.Application.Handlers;

public class GetPartnerQueryHandler : IRequestHandler<GetPartnerQuery, UserDto?>
{
    private readonly IUserRepository _users;

    public GetPartnerQueryHandler(IUserRepository users)
        => _users = users;

    public async Task<UserDto?> Handle(GetPartnerQuery request, CancellationToken cancellationToken)
    {
        var pair = await _users.GetPairByUserIdAsync(request.UserId);
        
        if (pair is null) return null;

        // Partner is whichever user is NOT the requesting user
        var partner = pair.User1Id == request.UserId ? pair.User2 : pair.User1;

        if (partner is null) return null;

        return new UserDto(
            partner.Id,
            partner.Username,
            partner.PublicKey);
    }
}
