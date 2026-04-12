using CoupleApp.Core.Entities;

namespace CoupleApp.Core.Interfaces.Repositories;

/// <summary>
/// User-specific repository.
/// </summary>
public interface IUserRepository : IRepository<User>
{
    Task<User?> GetByUsernameAsync(string username);

    /// <summary>
    /// Returns the partner: the only other user in the DB (2-person app).
    /// </summary>
    Task<User?> GetPartnerAsync(Guid myUserId);

    Task<bool> UsernameExistsAsync(string username);

    // ── Pairing System ────────────────────────────────────────────────
    Task<CoupleInvitation?> GetInvitationByCodeAsync(string code);
    Task AddInvitationAsync(CoupleInvitation invitation);
    Task<CoupleInvitation?> GetActiveInvitationAsync(Guid userId);
    
    Task<CouplePair?> GetPairByUserIdAsync(Guid userId);
    Task AddPairAsync(CouplePair pair);

    // ── Auth & Refresh Tokens ─────────────────────────────────────────
    Task<RefreshToken?> GetRefreshTokenAsync(string tokenHash);
    Task AddRefreshTokenAsync(RefreshToken token);
    Task UpdateRefreshTokenAsync(RefreshToken token);
    Task RevokeUserRefreshTokensFamilyAsync(Guid userId, string familyTrackingIp);
    Task RevokeAllUserRefreshTokensAsync(Guid userId);

    // ── FCM Push Notifications ─────────────────────────────────────────
    Task UpsertDeviceTokenAsync(Guid userId, string token, string platform);
    Task<List<string>> GetDeviceTokensAsync(Guid userId);
    Task RemoveDeviceTokensAsync(List<string> tokens);
}
