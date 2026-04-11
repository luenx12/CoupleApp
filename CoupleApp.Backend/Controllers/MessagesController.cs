using CoupleApp.Backend.Data;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace CoupleApp.Backend.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class MessagesController : ControllerBase
{
    private readonly AppDbContext _db;

    public MessagesController(AppDbContext db) => _db = db;

    /// <summary>
    /// Returns conversation history between the authenticated user and their partner.
    /// Only returns encrypted blobs — Zero-Leak.
    /// </summary>
    [HttpGet("history/{partnerId:guid}")]
    public async Task<IActionResult> GetHistory(Guid partnerId, [FromQuery] int page = 1, [FromQuery] int pageSize = 50)
    {
        var userId = GetUserId();

        var messages = await _db.Messages
            .Where(m =>
                (m.SenderId == userId && m.ReceiverId == partnerId) ||
                (m.SenderId == partnerId && m.ReceiverId == userId))
            .OrderByDescending(m => m.SentAt)
            .Skip((page - 1) * pageSize)
            .Take(pageSize)
            .Select(m => new
            {
                m.Id,
                m.SenderId,
                m.ReceiverId,
                // Return correct ciphertext depending on who is reading
                EncryptedText = m.SenderId == userId ? m.EncryptedTextForSender ?? m.EncryptedText : m.EncryptedText,
                m.IV,
                m.Type,
                m.IsDelivered,
                m.IsRead,
                m.SentAt,
                m.DeliveredAt,
                m.ReadAt
            })
            .ToListAsync();

        return Ok(messages);
    }

    /// <summary>
    /// Soft-delete a sent message.
    /// </summary>
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id)
    {
        var userId = GetUserId();
        var msg = await _db.Messages.FindAsync(id);

        if (msg is null || msg.SenderId != userId)
            return NotFound();

        msg.IsDeleted = true;
        msg.EncryptedText = string.Empty;          // Wipe ciphertext
        msg.EncryptedTextForSender = null;
        await _db.SaveChangesAsync();

        return NoContent();
    }

    private Guid GetUserId() =>
        Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? User.FindFirstValue("sub")
            ?? throw new UnauthorizedAccessException());
}
