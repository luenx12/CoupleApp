using CoupleApp.Core.Entities;

namespace CoupleApp.Core.Interfaces.Repositories;

/// <summary>
/// Gallery-specific repository.
/// </summary>
public interface IGalleryRepository : IRepository<GalleryItem>
{
    /// <summary>
    /// Returns all gallery items where the user is either uploader or receiver.
    /// </summary>
    Task<IEnumerable<GalleryItem>> GetForUserAsync(Guid userId);

    /// <summary>
    /// Finds a gallery item by its media ID (sender or receiver copy).
    /// </summary>
    Task<GalleryItem?> GetByMediaIdAsync(string mediaId);
}
