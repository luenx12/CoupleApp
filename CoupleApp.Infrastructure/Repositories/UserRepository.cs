using CoupleApp.Core.Entities;
using CoupleApp.Core.Interfaces.Repositories;
using CoupleApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace CoupleApp.Infrastructure.Repositories;

/// <summary>
/// EF Core implementation of IUserRepository.
/// </summary>
public sealed class UserRepository : Repository<User>, IUserRepository
{
    public UserRepository(AppDbContext context) : base(context) { }

    public async Task<User?> GetByUsernameAsync(string username)
        => await _dbSet.FirstOrDefaultAsync(u => u.Username == username);

    /// <summary>
    /// Returns the only other user in the DB — this is a 2-person app.
    /// </summary>
    public async Task<User?> GetPartnerAsync(Guid myUserId)
        => await _dbSet
            .Where(u => u.Id != myUserId)
            .OrderBy(u => u.CreatedAt)
            .FirstOrDefaultAsync();

    public async Task<bool> UsernameExistsAsync(string username)
        => await _dbSet.AnyAsync(u => u.Username == username);

    // ── Pairing System ────────────────────────────────────────────────

    public async Task<CoupleInvitation?> GetInvitationByCodeAsync(string code)
        => await ((AppDbContext)_context).CoupleInvitations
            .Include(i => i.Inviter)
            .FirstOrDefaultAsync(i => i.InviteCode == code);

    public async Task AddInvitationAsync(CoupleInvitation invitation)
        => await ((AppDbContext)_context).CoupleInvitations.AddAsync(invitation);

    public async Task<CoupleInvitation?> GetActiveInvitationAsync(Guid userId)
        => await ((AppDbContext)_context).CoupleInvitations
            .Where(i => i.InviterUserId == userId && i.Status == InvitationStatus.Pending && i.ExpiresAt > DateTime.UtcNow)
            .OrderByDescending(i => i.CreatedAt)
            .FirstOrDefaultAsync();

    public async Task<CouplePair?> GetPairByUserIdAsync(Guid userId)
        => await ((AppDbContext)_context).CouplePairs
            .Include(p => p.User1)
            .Include(p => p.User2)
            .FirstOrDefaultAsync(p => p.User1Id == userId || p.User2Id == userId);

    public async Task AddPairAsync(CouplePair pair)
        => await ((AppDbContext)_context).CouplePairs.AddAsync(pair);

    // ── Auth & Refresh Tokens ─────────────────────────────────────────

    public async Task<RefreshToken?> GetRefreshTokenAsync(string tokenHash)
        => await ((AppDbContext)_context).RefreshTokens
            .FirstOrDefaultAsync(rt => rt.TokenHash == tokenHash);

    public async Task AddRefreshTokenAsync(RefreshToken token)
        => await ((AppDbContext)_context).RefreshTokens.AddAsync(token);

    public async Task UpdateRefreshTokenAsync(RefreshToken token)
    {
        ((AppDbContext)_context).RefreshTokens.Update(token);
        await Task.CompletedTask;
    }

    public async Task RevokeUserRefreshTokensFamilyAsync(Guid userId, string sourceIp)
    {
        var tokens = await ((AppDbContext)_context).RefreshTokens
            .Where(rt => rt.UserId == userId && rt.RevokedAt == null)
            .ToListAsync();

        foreach (var t in tokens)
        {
            t.RevokedAt = DateTime.UtcNow;
            t.ReplacedByToken = "REVOKED_DUE_TO_FAMILY_REUSE";
        }
    }

    public async Task RevokeAllUserRefreshTokensAsync(Guid userId)
    {
        var tokens = await ((AppDbContext)_context).RefreshTokens
            .Where(rt => rt.UserId == userId && rt.RevokedAt == null)
            .ToListAsync();

        foreach (var t in tokens)
        {
            t.RevokedAt = DateTime.UtcNow;
            t.ReplacedByToken = "REVOKED_MANUAL";
        }
    }

    // ── FCM Push Notifications ─────────────────────────────────────────

    public async Task UpsertDeviceTokenAsync(Guid userId, string token, string platform)
    {
        var db = (AppDbContext)_context;
        // Check if token already exists
        var existing = await db.DeviceTokens.FirstOrDefaultAsync(dt => dt.Token == token);
        if (existing is not null)
        {
            // If it belongs to someone else, reassign
            existing.UserId = userId;
            existing.Platform = platform;
            existing.UpdatedAt = DateTime.UtcNow;
        }
        else
        {
            await db.DeviceTokens.AddAsync(new DeviceToken
            {
                UserId = userId,
                Token = token,
                Platform = platform
            });
        }
    }

    public async Task<List<string>> GetDeviceTokensAsync(Guid userId)
    {
        return await ((AppDbContext)_context).DeviceTokens
            .Where(dt => dt.UserId == userId)
            .Select(dt => dt.Token)
            .ToListAsync();
    }

    public async Task RemoveDeviceTokensAsync(List<string> tokens)
    {
        var db = (AppDbContext)_context;
        var toRemove = await db.DeviceTokens.Where(dt => tokens.Contains(dt.Token)).ToListAsync();
        if (toRemove.Count > 0)
        {
            db.DeviceTokens.RemoveRange(toRemove);
        }
    }
}
