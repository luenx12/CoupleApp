using CoupleApp.Backend.Data;
using CoupleApp.Backend.Entities;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace CoupleApp.Backend.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class GalleryController : ControllerBase
{
    private readonly AppDbContext _context;
    private readonly IWebHostEnvironment _env;
    private readonly ILogger<GalleryController> _logger;

    private string MediaRoot => Path.Combine(_env.ContentRootPath, "media_store");

    public GalleryController(AppDbContext context, IWebHostEnvironment env, ILogger<GalleryController> logger)
    {
        _context = context;
        _env = env;
        _logger = logger;
    }

    [HttpGet]
    public async Task<IActionResult> GetGallery()
    {
        var userId = GetUserId();

        var items = await _context.GalleryItems
            .Where(g => g.UploaderId == userId || g.ReceiverId == userId)
            .OrderByDescending(g => g.CreatedAt)
            .Select(g => new
            {
                g.Id,
                g.CreatedAt,
                g.LockedUntil,
                IsLocked = g.LockedUntil.HasValue && g.LockedUntil.Value > DateTime.UtcNow,
                // Return the correct MediaId based on who is asking
                MediaId = g.UploaderId == userId ? g.MediaIdForSender : g.MediaIdForReceiver,
                UploaderId = g.UploaderId
            })
            .ToListAsync();

        return Ok(items);
    }

    [HttpPost]
    [RequestSizeLimit(100_000_000)] // 100 MB max for 2 files
    public async Task<IActionResult> UploadGalleryItem(
        List<IFormFile> files, // Should be exactly 2 files: [0] forSender, [1] forReceiver
        [FromForm] DateTime? lockedUntil,
        [FromForm] string partnerId)
    {
        if (files == null || files.Count != 2)
            return BadRequest("Must provide exactly 2 files (fileForSender, fileForReceiver).");

        if (!Guid.TryParse(partnerId, out var receiverId))
            return BadRequest("Invalid partnerId.");

        var uploaderId = GetUserId();

        var mediaIdForSender = Guid.NewGuid().ToString("N");
        var mediaIdForReceiver = Guid.NewGuid().ToString("N");

        // Save sender file
        var pathForSender = Path.Combine(MediaRoot, mediaIdForSender + ".aes");
        await using (var stream1 = System.IO.File.Create(pathForSender))
        {
            await files[0].CopyToAsync(stream1);
        }

        // Save receiver file
        var pathForReceiver = Path.Combine(MediaRoot, mediaIdForReceiver + ".aes");
        await using (var stream2 = System.IO.File.Create(pathForReceiver))
        {
            await files[1].CopyToAsync(stream2);
        }

        var item = new GalleryItem
        {
            UploaderId = uploaderId,
            ReceiverId = receiverId,
            MediaIdForSender = mediaIdForSender,
            MediaIdForReceiver = mediaIdForReceiver,
            LockedUntil = lockedUntil?.ToUniversalTime()
        };

        _context.GalleryItems.Add(item);
        await _context.SaveChangesAsync();

        _logger.LogInformation("Gallery item {Id} uploaded by {UserId}. LockedUntil: {LockedUntil}", item.Id, uploaderId, item.LockedUntil);

        return Ok(new
        {
            item.Id,
            item.CreatedAt,
            item.LockedUntil,
            IsLocked = item.LockedUntil.HasValue && item.LockedUntil.Value > DateTime.UtcNow,
            MediaId = mediaIdForSender,
            UploaderId = item.UploaderId
        });
    }

    [HttpGet("media/{mediaId}")]
    public async Task<IActionResult> DownloadMedia(string mediaId)
    {
        if (mediaId.Contains('/') || mediaId.Contains('\\') || mediaId.Contains('.'))
            return BadRequest("Invalid mediaId.");

        // IMPORTANT: Zero-leak enforcement for Time Capsule
        var item = await _context.GalleryItems.FirstOrDefaultAsync(g => g.MediaIdForSender == mediaId || g.MediaIdForReceiver == mediaId);
        
        if (item == null)
            return NotFound("Gallery media not found.");

        if (item.LockedUntil.HasValue && item.LockedUntil.Value > DateTime.UtcNow)
        {
            _logger.LogWarning("Blocked attempt to download locked media {MediaId}", mediaId);
            return StatusCode(403, "This media is locked in a time capsule.");
        }

        var userId = GetUserId();
        if (item.UploaderId != userId && item.ReceiverId != userId)
            return StatusCode(403);

        var filePath = Path.Combine(MediaRoot, mediaId + ".aes");
        if (!System.IO.File.Exists(filePath))
            return NotFound("File is missing from disk.");

        var stream = System.IO.File.OpenRead(filePath);
        return File(stream, "application/octet-stream", mediaId + ".aes");
    }

    private Guid GetUserId() =>
        Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? User.FindFirstValue("sub")
            ?? throw new UnauthorizedAccessException());
}
