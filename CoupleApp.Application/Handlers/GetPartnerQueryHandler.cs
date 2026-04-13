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
        
        CoupleApp.Core.Entities.User? partner = null;

        if (pair is not null)
        {
            partner = pair.User1Id == request.UserId ? pair.User2 : pair.User1;
        }
        else
        {
            // OTO EŞLEŞTİRME (FALLBACK): Henüz mobil uygulamada davet kodu vs. ekranı
            // olmadığı için (sadece 2 kişi kullanacak mantığıyla) eğer kişi pair olmamışsa
            // veritabanındaki "kendisi dışındaki diğer kaydı" partner olarak kabul et.
            partner = await _users.GetPartnerAsync(request.UserId);
        }

        if (partner is null) return null;

        return new UserDto(
            partner.Id,
            partner.Username,
            partner.PublicKey);
    }
}
