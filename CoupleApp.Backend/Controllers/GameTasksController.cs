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
public class GameTasksController : ControllerBase
{
    private readonly AppDbContext _db;

    public GameTasksController(AppDbContext db) => _db = db;

    [HttpGet]
    public async Task<IActionResult> GetMyTasks()
    {
        var userId = GetUserId();
        var tasks = await _db.GameTasks
            .Where(t => t.AssignedToUserId == userId || t.AssignedByUserId == userId)
            .OrderByDescending(t => t.CreatedAt)
            .ToListAsync();
        return Ok(tasks);
    }

    [HttpPost]
    public async Task<IActionResult> Create([FromBody] CreateGameTaskDto dto)
    {
        var userId = GetUserId();
        var task = new GameTask
        {
            AssignedByUserId  = userId,
            AssignedToUserId  = dto.AssignedToUserId,
            Title             = dto.Title,
            Description       = dto.Description,
            Points            = dto.Points,
            Difficulty        = dto.Difficulty,
            DueDate           = dto.DueDate
        };
        _db.GameTasks.Add(task);
        await _db.SaveChangesAsync();
        return CreatedAtAction(nameof(GetMyTasks), new { id = task.Id }, task);
    }

    [HttpPatch("{id:guid}/complete")]
    public async Task<IActionResult> Complete(Guid id)
    {
        var userId = GetUserId();
        var task = await _db.GameTasks.FindAsync(id);
        if (task is null || task.AssignedToUserId != userId) return NotFound();

        task.IsCompleted  = true;
        task.CompletedAt  = DateTime.UtcNow;
        await _db.SaveChangesAsync();
        return Ok(task);
    }

    [HttpPatch("{id:guid}/verify")]
    public async Task<IActionResult> Verify(Guid id)
    {
        var userId = GetUserId();
        var task = await _db.GameTasks.FindAsync(id);
        if (task is null || task.AssignedByUserId != userId) return NotFound();
        if (!task.IsCompleted) return BadRequest("Task not yet completed.");

        task.IsVerified = true;
        await _db.SaveChangesAsync();
        return Ok(task);
    }

    private Guid GetUserId() =>
        Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? User.FindFirstValue("sub")
            ?? throw new UnauthorizedAccessException());
}

public record CreateGameTaskDto(
    Guid AssignedToUserId,
    string Title,
    string? Description,
    int Points,
    TaskDifficulty Difficulty,
    DateTime? DueDate
);
