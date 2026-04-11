using CoupleApp.Backend.Data;
using CoupleApp.Backend.Entities;
using Microsoft.AspNetCore.Mvc;
using Microsoft.EntityFrameworkCore;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Text;

namespace CoupleApp.Backend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly AppDbContext _db;
    private readonly IConfiguration _config;
    private readonly ILogger<AuthController> _logger;

    public AuthController(AppDbContext db, IConfiguration config, ILogger<AuthController> logger)
    {
        _db     = db;
        _config = config;
        _logger = logger;
    }

    /// <summary>
    /// Register a new user. Stores BCrypt hash — never plaintext.
    /// </summary>
    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterDto dto)
    {
        if (await _db.Users.AnyAsync(u => u.Username == dto.Username))
            return Conflict("Username already taken.");

        var user = new User
        {
            Username     = dto.Username,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(dto.Password),
            PublicKey    = dto.PublicKey
        };

        _db.Users.Add(user);
        await _db.SaveChangesAsync();

        _logger.LogInformation("New user registered: {Username}", dto.Username);
        return Ok(new { user.Id, user.Username });
    }

    /// <summary>
    /// Login — returns a JWT access token.
    /// </summary>
    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginDto dto)
    {
        var user = await _db.Users
            .FirstOrDefaultAsync(u => u.Username == dto.Username);

        if (user is null || !BCrypt.Net.BCrypt.Verify(dto.Password, user.PasswordHash))
            return Unauthorized("Invalid credentials.");

        user.LastSeenAt = DateTime.UtcNow;
        await _db.SaveChangesAsync();

        var token = GenerateJwt(user);
        return Ok(new { AccessToken = token, user.Id, user.Username, user.PublicKey });
    }

    // ──────────────────────────────────────────────────────────────────────

    private string GenerateJwt(User user)
    {
        var key    = new SymmetricSecurityKey(Encoding.UTF8.GetBytes(_config["Jwt:Secret"]!));
        var creds  = new SigningCredentials(key, SecurityAlgorithms.HmacSha256);
        var claims = new[]
        {
            new Claim(ClaimTypes.NameIdentifier, user.Id.ToString()),
            new Claim(ClaimTypes.Name,            user.Username),
            new Claim("sub",                      user.Id.ToString())
        };

        var token = new JwtSecurityToken(
            issuer:             _config["Jwt:Issuer"],
            audience:           _config["Jwt:Audience"],
            claims:             claims,
            expires:            DateTime.UtcNow.AddDays(30),
            signingCredentials: creds);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    // ── GET /api/Auth/me ────────────────────────────────────────────────
    [HttpGet("me")]
    [Microsoft.AspNetCore.Authorization.Authorize]
    public async Task<IActionResult> Me()
    {
        var userId = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? User.FindFirstValue("sub")
            ?? throw new UnauthorizedAccessException());
        var user = await _db.Users.FindAsync(userId);
        if (user is null) return NotFound();
        return Ok(new { user.Id, user.Username, user.PublicKey });
    }

    // ── GET /api/Auth/partner ────────────────────────────────────────────
    /// <summary>
    /// Returns the partner (the only other user in the DB for this 2-person app).
    /// In production, a proper pairing table should be used.
    /// </summary>
    [HttpGet("partner")]
    [Microsoft.AspNetCore.Authorization.Authorize]
    public async Task<IActionResult> GetPartner()
    {
        var myId = Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? User.FindFirstValue("sub")
            ?? throw new UnauthorizedAccessException());

        var partner = await _db.Users
            .Where(u => u.Id != myId)
            .OrderBy(u => u.CreatedAt)
            .FirstOrDefaultAsync();

        if (partner is null)
            return NotFound("No partner found. Register the second user first.");

        return Ok(new { partner.Id, partner.Username, partner.PublicKey });
    }
}

public record RegisterDto(string Username, string Password, string? PublicKey);
public record LoginDto(string Username, string Password);
