using CoupleApp.Core.Entities;
using CoupleApp.Infrastructure.Persistence;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace CoupleApp.Backend.Controllers;

/// <summary>
/// DrawGuess game REST endpoints.
/// SignalR (DrawStroke / DrawGuessed events) are handled via CoupleHub.
/// </summary>
[Authorize]
[ApiController]
[Route("api/games/draw")]
public class DrawGamesController : ControllerBase
{
    private readonly AppDbContext _db;

    public DrawGamesController(AppDbContext db) => _db = db;

    // ──────────────────────────────────────────────────────────────────────────
    // GET /api/games/draw/words  — 3 random word options for the drawer
    // ──────────────────────────────────────────────────────────────────────────

    [HttpGet("words")]
    public async Task<IActionResult> GetWordOptions([FromQuery] DrawDifficulty? difficulty)
    {
        var query = _db.DrawWords.AsQueryable();
        if (difficulty.HasValue)
            query = query.Where(w => w.Difficulty == difficulty.Value);

        // Pick 3 random words
        var total = await query.CountAsync();
        if (total == 0) return NotFound("No words available.");

        var words = await query
            .OrderBy(_ => Guid.NewGuid()) // random sort — works on PostgreSQL
            .Take(3)
            .Select(w => new { w.Id, w.Word, w.Category, w.Difficulty })
            .ToListAsync();

        return Ok(words);
    }

    // ──────────────────────────────────────────────────────────────────────────
    // POST /api/games/draw/start — Drawer picks a word, session is created
    // ──────────────────────────────────────────────────────────────────────────

    [HttpPost("start")]
    public async Task<IActionResult> StartSession([FromBody] StartDrawSessionDto dto)
    {
        var drawerId  = GetUserId();
        var guesserId = dto.GuesserId;

        var word = await _db.DrawWords.FindAsync(dto.WordId);
        if (word is null) return BadRequest("Word not found.");

        // Abandon any active session for this pair
        var existing = await _db.DrawSessions
            .Where(s => (s.DrawerId == drawerId || s.GuesserId == drawerId) &&
                        s.Status == DrawSessionStatus.Drawing)
            .FirstOrDefaultAsync();

        if (existing is not null)
        {
            existing.Status = DrawSessionStatus.Abandoned;
        }

        var session = new DrawSession
        {
            DrawerId  = drawerId,
            GuesserId = guesserId,
            Word      = word.Word,
            Status    = DrawSessionStatus.Drawing,
            StartedAt = DateTime.UtcNow,
        };

        _db.DrawSessions.Add(session);
        await _db.SaveChangesAsync();

        return Ok(new
        {
            session.Id,
            session.StartedAt,
            // Return word ONLY to the drawer — guesser never gets it
            Word = session.Word,
        });
    }

    // ──────────────────────────────────────────────────────────────────────────
    // POST /api/games/draw/guess — Guesser submits a guess
    // ──────────────────────────────────────────────────────────────────────────

    [HttpPost("guess")]
    public async Task<IActionResult> SubmitGuess([FromBody] SubmitGuessDto dto)
    {
        var guesserId = GetUserId();

        var session = await _db.DrawSessions.FindAsync(dto.SessionId);
        if (session is null)       return NotFound("Session not found.");
        if (session.GuesserId != guesserId) return Forbid();
        if (session.Status != DrawSessionStatus.Drawing)
            return BadRequest("Session is not active.");

        var isCorrect = string.Equals(
            dto.Guess.Trim(),
            session.Word,
            StringComparison.OrdinalIgnoreCase
        );

        if (!isCorrect)
            return Ok(new { Correct = false });

        // ── Correct guess: calculate time-based score ──────────────────────
        var elapsed       = (DateTime.UtcNow - session.StartedAt).TotalSeconds;
        var remaining     = Math.Max(0, 60 - elapsed);
        var score         = (int)Math.Ceiling(remaining / 60.0 * 99) + 1; // 1–100
        // elapsed=0 → 100pts, elapsed=59 → ~2pts, elapsed>=60 → 1pt

        session.Status        = DrawSessionStatus.Guessed;
        session.GuessedAt     = DateTime.UtcNow;
        session.WinnerUserId  = guesserId;
        session.ScoreAwarded  = score;
        await _db.SaveChangesAsync();

        return Ok(new
        {
            Correct       = true,
            Score         = score,
            ElapsedSeconds = (int)elapsed,
            session.Word,
        });
    }

    // ──────────────────────────────────────────────────────────────────────────
    // GET /api/games/draw/stats — Pair statistics
    // ──────────────────────────────────────────────────────────────────────────

    [HttpGet("stats")]
    public async Task<IActionResult> GetStats()
    {
        var userId = GetUserId();

        var sessions = await _db.DrawSessions
            .Where(s => s.DrawerId == userId || s.GuesserId == userId)
            .Where(s => s.Status == DrawSessionStatus.Guessed)
            .ToListAsync();

        return Ok(new
        {
            TotalGames    = sessions.Count,
            AsDrawer      = sessions.Count(s => s.DrawerId  == userId),
            AsGuesser     = sessions.Count(s => s.GuesserId == userId),
            TotalScore    = sessions.Where(s => s.WinnerUserId == userId).Sum(s => s.ScoreAwarded),
            BestScore     = sessions.Where(s => s.WinnerUserId == userId)
                                    .Select(s => s.ScoreAwarded)
                                    .DefaultIfEmpty(0).Max(),
        });
    }

    // ──────────────────────────────────────────────────────────────────────────
    // POST /api/games/draw/timeout — Drawer reports time ran out
    // ──────────────────────────────────────────────────────────────────────────

    [HttpPost("timeout")]
    public async Task<IActionResult> ReportTimeout([FromBody] TimeoutDto dto)
    {
        var session = await _db.DrawSessions.FindAsync(dto.SessionId);
        if (session is null) return NotFound();
        if (session.DrawerId != GetUserId()) return Forbid();

        session.Status = DrawSessionStatus.TimeUp;
        await _db.SaveChangesAsync();
        return NoContent();
    }

    // ── Helpers ───────────────────────────────────────────────────────────────

    private Guid GetUserId()
    {
        var claim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value
                 ?? User.FindFirst("sub")?.Value;
        return Guid.TryParse(claim, out var id) ? id
            : throw new UnauthorizedAccessException();
    }
}

// ── Request DTOs ──────────────────────────────────────────────────────────────

public record StartDrawSessionDto(Guid GuesserId, Guid WordId);
public record SubmitGuessDto(Guid SessionId, string Guess);
public record TimeoutDto(Guid SessionId);
