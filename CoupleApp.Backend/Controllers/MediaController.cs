using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace CoupleApp.Backend.Controllers;

/// <summary>
/// Encrypted media upload + self-destruct DELETE.
/// Server stores ONLY the already-encrypted blob — Zero-Leak.
/// </summary>
[ApiController]
[Route("api/[controller]")]
[Authorize]
public class MediaController : ControllerBase
{
    private readonly IWebHostEnvironment _env;
    private readonly ILogger<MediaController> _logger;

    private string MediaRoot => Path.Combine(_env.ContentRootPath, "media_store");

    public MediaController(IWebHostEnvironment env, ILogger<MediaController> logger)
    {
        _env    = env;
        _logger = logger;
        Directory.CreateDirectory(MediaRoot);
    }

    // ──────────────────────────────────────────────────────────────────────
    // POST /api/Media/upload
    // Body: multipart/form-data  →  file (encrypted blob) + messageId
    // Returns: { mediaId }
    // ──────────────────────────────────────────────────────────────────────
    [HttpPost("upload")]
    [RequestSizeLimit(50_000_000)] // 50 MB
    public async Task<IActionResult> Upload(IFormFile file, [FromForm] string? messageId)
    {
        if (file == null || file.Length == 0)
            return BadRequest("No file provided.");

        var mediaId  = Guid.NewGuid().ToString("N");
        var extension = ".aes"; // always encrypted
        var filePath  = Path.Combine(MediaRoot, mediaId + extension);

        await using var stream = System.IO.File.Create(filePath);
        await file.CopyToAsync(stream);

        _logger.LogInformation("Media uploaded: {MediaId} ({Size} bytes) for message {MessageId}",
            mediaId, file.Length, messageId);

        return Ok(new { mediaId });
    }

    // ──────────────────────────────────────────────────────────────────────
    // GET /api/Media/{mediaId}
    // Download the encrypted blob (receiver fetches and decrypts in RAM)
    // ──────────────────────────────────────────────────────────────────────
    [HttpGet("{mediaId}")]
    public IActionResult Download(string mediaId)
    {
        // Prevent path traversal
        if (mediaId.Contains('/') || mediaId.Contains('\\') || mediaId.Contains('.'))
            return BadRequest("Invalid mediaId.");

        var filePath = Path.Combine(MediaRoot, mediaId + ".aes");
        if (!System.IO.File.Exists(filePath))
            return NotFound("Media not found or already deleted.");

        var stream = System.IO.File.OpenRead(filePath);
        return File(stream, "application/octet-stream", mediaId + ".aes");
    }

    // ──────────────────────────────────────────────────────────────────────
    // DELETE /api/Media/{mediaId}   ← Self-Destruct
    // Called by receiver immediately after RAM-decryption.
    // Permanently removes the encrypted blob from server.
    // ──────────────────────────────────────────────────────────────────────
    [HttpDelete("{mediaId}")]
    public IActionResult SelfDestruct(string mediaId)
    {
        if (mediaId.Contains('/') || mediaId.Contains('\\') || mediaId.Contains('.'))
            return BadRequest("Invalid mediaId.");

        var filePath = Path.Combine(MediaRoot, mediaId + ".aes");
        if (!System.IO.File.Exists(filePath))
            return NoContent(); // Already deleted — idempotent

        try
        {
            // Secure wipe: overwrite with 0xFF then delete
            var size = new FileInfo(filePath).Length;
            using (var fs = System.IO.File.OpenWrite(filePath))
            {
                var wipe = new byte[Math.Min(size, 65536)];
                Array.Fill(wipe, (byte)0xFF);
                long written = 0;
                while (written < size)
                {
                    var chunk = (int)Math.Min(wipe.Length, size - written);
                    fs.Write(wipe, 0, chunk);
                    written += chunk;
                }
                fs.Flush();
            }
            System.IO.File.Delete(filePath);

            _logger.LogInformation("🔥 Self-destruct: Media {MediaId} permanently deleted.", mediaId);
            return NoContent();
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to delete media {MediaId}.", mediaId);
            return StatusCode(500, "Failed to delete media.");
        }
    }

    private Guid GetUserId() =>
        Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? User.FindFirstValue("sub")
            ?? throw new UnauthorizedAccessException());
}
