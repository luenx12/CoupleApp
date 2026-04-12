using CoupleApp.Core.Entities;
using CoupleApp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace CoupleApp.Backend.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class ActivitiesController : ControllerBase
{
    private readonly AppDbContext _db;

    public ActivitiesController(AppDbContext db) => _db = db;

    [HttpGet]
    public async Task<IActionResult> GetAll()
    {
        var userId = GetUserId();
        var list = await _db.Activities
            .Where(a => a.CreatedByUserId == userId)
            .OrderByDescending(a => a.CreatedAt)
            .ToListAsync();
        return Ok(list);
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateActivityDto dto)
    {
        var userId = GetUserId();
        var activity = new Activity
        {
            CreatedByUserId = userId,
            Title           = dto.Title,
            Description     = dto.Description,
            Category        = dto.Category,
            ScheduledAt     = dto.ScheduledAt
        };
        _db.Activities.Add(activity);
        await _db.SaveChangesAsync();
        return CreatedAtAction(nameof(GetAll), new { id = activity.Id }, activity);
    }

    [HttpPatch("{id:guid}/complete")]
    public async Task<IActionResult> Complete(Guid id)
    {
        var userId = GetUserId();
        var activity = await _db.Activities.FindAsync(id);
        if (activity is null || activity.CreatedByUserId != userId) return NotFound();

        activity.IsCompleted = true;
        activity.CompletedAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();
        return Ok(activity);
    }

    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id)
    {
        var userId = GetUserId();
        var activity = await _db.Activities.FindAsync(id);
        if (activity is null || activity.CreatedByUserId != userId) return NotFound();

        _db.Activities.Remove(activity);
        await _db.SaveChangesAsync();
        return NoContent();
    }

    private Guid GetUserId() =>
        Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? User.FindFirstValue("sub")
            ?? throw new UnauthorizedAccessException());
}

public record CreateActivityDto(
    string Title,
    string? Description,
    ActivityCategory Category,
    DateTime? ScheduledAt
);
