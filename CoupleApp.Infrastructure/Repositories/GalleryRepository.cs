using CoupleApp.Core.Entities;
using CoupleApp.Core.Interfaces.Repositories;
using CoupleApp.Infrastructure.Persistence;
using Microsoft.EntityFrameworkCore;

namespace CoupleApp.Infrastructure.Repositories;

/// <summary>
/// EF Core implementation of IGalleryRepository.
/// </summary>
public sealed class GalleryRepository : Repository<GalleryItem>, IGalleryRepository
{
    public GalleryRepository(AppDbContext context) : base(context) { }

    public async Task<IEnumerable<GalleryItem>> GetForUserAsync(Guid userId)
        => await _dbSet
            .Where(g => g.UploaderId == userId || g.ReceiverId == userId)
            .OrderByDescending(g => g.CreatedAt)
            .ToListAsync();

    public async Task<GalleryItem?> GetByMediaIdAsync(string mediaId)
        => await _dbSet.FirstOrDefaultAsync(g =>
            g.MediaIdForSender == mediaId ||
            g.MediaIdForReceiver == mediaId);
}
