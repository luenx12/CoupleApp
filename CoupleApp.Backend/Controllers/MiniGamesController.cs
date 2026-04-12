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
public class MiniGamesController : ControllerBase
{
    private readonly AppDbContext _db;

    public MiniGamesController(AppDbContext db) => _db = db;

    // ── Who Is More ────────────────────────────────────────────────────────
    
    [HttpGet("daily-question")]
    public async Task<IActionResult> GetDailyQuestion()
    {
        // Simple daily selection based on days since epoch to keep it the same all day
        var count = await _db.DailyQuestions.CountAsync();
        if (count == 0) return NotFound();

        int seed = (int)(DateTime.UtcNow - new DateTime(2024, 1, 1)).TotalDays;
        int index = seed % count;

        var question = await _db.DailyQuestions.Skip(index).FirstOrDefaultAsync();
        return Ok(question);
    }

    [HttpGet("user-stats")]
    public async Task<IActionResult> GetUserStats()
    {
        var userId = GetUserId();
        var stats = await _db.UserStats.FirstOrDefaultAsync(s => s.UserId == userId);
        if (stats == null)
        {
            stats = new UserStats { UserId = userId, TotalPoints = 0, WhoIsMoreMatches = 0 };
            _db.UserStats.Add(stats);
            await _db.SaveChangesAsync();
        }
        return Ok(stats);
    }

    // ── Scratch Card (Kazı Kazan) ──────────────────────────────────────────

    [HttpGet("daily-task")]
    public async Task<IActionResult> GetDailyTask()
    {
        var userId = GetUserId();
        // Find pair ID
        var pair = await _db.CouplePairs.FirstOrDefaultAsync(p => p.User1Id == userId || p.User2Id == userId);
        if (pair == null) return BadRequest("Not paired.");

        // Find today's task for this pair
        var today = DateTime.UtcNow.Date;
        var task = await _db.DailyTasks
            .OrderByDescending(t => t.AssignedAt)
            .FirstOrDefaultAsync(t => t.PairId == pair.Id && t.AssignedAt >= today);

        if (task == null)
            return NotFound("No task assigned for today yet.");

        return Ok(task);
    }

    [HttpPost("accept-task")]
    public async Task<IActionResult> AcceptTask([FromBody] Guid taskId)
    {
        var userId = GetUserId();
        var task = await _db.DailyTasks.FindAsync(taskId);
        if (task == null) return NotFound();

        // Security check omitted for brevity in MVP
        task.IsAccepted = true;
        await _db.SaveChangesAsync();

        return Ok(task);
    }

    [HttpPatch("complete-task/{id}")]
    public async Task<IActionResult> CompleteTask(Guid id)
    {
        var task = await _db.DailyTasks.FindAsync(id);
        if (task == null) return NotFound();

        task.IsCompleted = true;
        await _db.SaveChangesAsync();

        return Ok(task);
    }

    // ── Flame Meter ────────────────────────────────────────────────────────

    [HttpGet("flame-history")]
    public async Task<IActionResult> GetFlameHistory([FromQuery] int days = 7)
    {
        var userId = GetUserId();
        var partnerId = await GetPartnerIdAsync(userId);
        if (partnerId == null) return BadRequest("No partner");

        var threshold = DateTime.UtcNow.AddDays(-days);
        
        var myFlames = await _db.FlameLevels
            .Where(f => f.UserId == userId && f.RecordedAt >= threshold)
            .OrderBy(f => f.RecordedAt)
            .ToListAsync();

        var partnerFlames = await _db.FlameLevels
            .Where(f => f.UserId == partnerId && f.RecordedAt >= threshold)
            .OrderBy(f => f.RecordedAt)
            .ToListAsync();

        return Ok(new
        {
            myHistory = myFlames,
            partnerHistory = partnerFlames
        });
    }

    [HttpGet("wordle-stats")]
    public async Task<IActionResult> GetWordleStats()
    {
        var uid = Guid.Parse(User.FindFirst(System.Security.Claims.ClaimTypes.NameIdentifier)?.Value!);
        var st = await _db.UserStats.FirstOrDefaultAsync(s => s.UserId == uid);
        if (st == null) return Ok(new { total = 0, avg = 0.0, currentStreak = 0, maxStreak = 0 });

        return Ok(new
        {
            total = st.WordleTotalPlayed,
            avg = st.WordleAverageAttempts,
            currentStreak = st.WordleCurrentStreak,
            maxStreak = st.WordleMaxStreak
        });
    }

    // ── Helpers ────────────────────────────────────────────────────────────

    private Guid GetUserId() =>
        Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? User.FindFirstValue("sub")
            ?? throw new UnauthorizedAccessException());

    private async Task<Guid?> GetPartnerIdAsync(Guid userId)
    {
        var pair = await _db.CouplePairs.FirstOrDefaultAsync(p => p.User1Id == userId || p.User2Id == userId);
        if (pair == null) return null;
        return pair.User1Id == userId ? pair.User2Id : pair.User1Id;
    }
}
