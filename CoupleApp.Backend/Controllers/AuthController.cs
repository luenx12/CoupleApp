using CoupleApp.Core.Entities;
using CoupleApp.Core.Interfaces.Repositories;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using Microsoft.AspNetCore.Authentication.JwtBearer;
using Microsoft.IdentityModel.Tokens;
using System.IdentityModel.Tokens.Jwt;
using System.Security.Claims;
using System.Security.Cryptography;
using System.Text;

namespace CoupleApp.Backend.Controllers;

[ApiController]
[Route("api/[controller]")]
public class AuthController : ControllerBase
{
    private readonly IUserRepository          _users;
    private readonly IConfiguration           _config;
    private readonly ILogger<AuthController>  _logger;

    public AuthController(
        IUserRepository         users,
        IConfiguration          config,
        ILogger<AuthController> logger)
    {
        _users  = users;
        _config = config;
        _logger = logger;
    }

    /// <summary>Register a new user. Stores BCrypt hash — never plaintext.</summary>
    [HttpPost("register")]
    public async Task<IActionResult> Register([FromBody] RegisterDto dto)
    {
        if (await _users.UsernameExistsAsync(dto.Username))
            return Conflict("Username already taken.");

        var user = new User
        {
            Username     = dto.Username,
            PasswordHash = BCrypt.Net.BCrypt.HashPassword(dto.Password),
            PublicKey    = dto.PublicKey
        };

        await _users.AddAsync(user);
        await _users.SaveChangesAsync();

        _logger.LogInformation("New user registered: {Username}", dto.Username);
        return Ok(new { user.Id, user.Username });
    }

    /// <summary>Login — returns a JWT access token.</summary>
    [HttpPost("login")]
    public async Task<IActionResult> Login([FromBody] LoginDto dto)
    {
        var user = await _users.GetByUsernameAsync(dto.Username);

        if (user is null || !BCrypt.Net.BCrypt.Verify(dto.Password, user.PasswordHash))
            return Unauthorized("Invalid credentials.");

        user.LastSeenAt = DateTime.UtcNow;
        
        var plainRefreshToken = GenerateRefreshToken();
        var refreshTokenEntity = new RefreshToken
        {
            UserId = user.Id,
            TokenHash = HashToken(plainRefreshToken),
            ExpiresAt = DateTime.UtcNow.AddDays(30),
            CreatedByIp = HttpContext.Connection.RemoteIpAddress?.ToString()
        };
        
        await _users.AddRefreshTokenAsync(refreshTokenEntity);
        await _users.SaveChangesAsync();

        var token = GenerateJwt(user);
        return Ok(new 
        { 
            AccessToken = token, 
            RefreshToken = plainRefreshToken,
            user.Id, 
            user.Username, 
            user.PublicKey 
        });
    }

    /// <summary>Returns the authenticated user's profile.</summary>
    [HttpGet("me")]
    [Authorize]
    public async Task<IActionResult> Me()
    {
        var userId = GetUserId();
        var user   = await _users.GetByIdAsync(userId);
        if (user is null) return NotFound();
        return Ok(new { user.Id, user.Username, user.PublicKey });
    }

    /// <summary>Returns the partner (the only other user in the DB for this 2-person app).</summary>
    [HttpGet("partner")]
    [Authorize]
    [Obsolete("Use /api/couple/partner instead. This endpoint is deprecated and will be removed in future versions.")]
    public async Task<IActionResult> GetPartner()
    {
        var myId    = GetUserId();
        // Since we are moving to pairing, fallback to getting someone else just to avoid crashing legacy apps
        // But optimally, clients should migrate to CoupleController.
        var partner = await _users.GetPartnerAsync(myId);

        if (partner is null)
            return NotFound("No partner found. Register the second user first or use the new pairing system.");

        return Ok(new { partner.Id, partner.Username, partner.PublicKey });
    }

    // ── Token Rotation & Refresh ──────────────────────────────────────────

    [HttpPost("refresh")]
    public async Task<IActionResult> Refresh([FromBody] RefreshDto dto)
    {
        var tokenHash = HashToken(dto.RefreshToken);
        var storedToken = await _users.GetRefreshTokenAsync(tokenHash);

        if (storedToken is null)
        {
            _logger.LogWarning("Invalid refresh token attempted.");
            return Unauthorized("Invalid refresh token.");
        }

        var ip = HttpContext.Connection.RemoteIpAddress?.ToString() ?? "unknown";

        if (storedToken.IsRevoked)
        {
            // Security breach detected: Token Reuse
            _logger.LogWarning("Token family reuse detected for user {UserId}. Revoking all tokens.", storedToken.UserId);
            // We revoke all tokens belonging to the user to cut off the attacker.
            await _users.RevokeUserRefreshTokensFamilyAsync(storedToken.UserId, ip);
            await _users.SaveChangesAsync();
            return Unauthorized("Invalid refresh token.");
        }

        if (storedToken.IsExpired)
        {
            return Unauthorized("Refresh token expired.");
        }

        var user = await _users.GetByIdAsync(storedToken.UserId);
        if (user is null) return Unauthorized("User not found.");

        // Rotate token
        var newPlainToken = GenerateRefreshToken();
        var newHash = HashToken(newPlainToken);

        storedToken.RevokedAt = DateTime.UtcNow;
        storedToken.ReplacedByToken = newHash;
        await _users.UpdateRefreshTokenAsync(storedToken);

        var newTokenEntity = new RefreshToken
        {
            UserId = user.Id,
            TokenHash = newHash,
            ExpiresAt = DateTime.UtcNow.AddDays(30),
            CreatedByIp = ip
        };
        await _users.AddRefreshTokenAsync(newTokenEntity);
        await _users.SaveChangesAsync();

        var newJwt = GenerateJwt(user);
        return Ok(new { AccessToken = newJwt, RefreshToken = newPlainToken });
    }

    [HttpPost("revoke")]
    [Authorize]
    public async Task<IActionResult> Revoke()
    {
        var userId = GetUserId();
        await _users.RevokeAllUserRefreshTokensAsync(userId);
        await _users.SaveChangesAsync();
        return Ok();
    }

    [HttpPost("device-token")]
    [Authorize]
    public async Task<IActionResult> UpdateDeviceToken([FromBody] DeviceTokenDto dto)
    {
        var userId = GetUserId();
        await _users.UpsertDeviceTokenAsync(userId, dto.Token, dto.Platform);
        await _users.SaveChangesAsync();
        return Ok();
    }

    [HttpPost("public-key")]
    [Authorize]
    public async Task<IActionResult> UpdatePublicKey([FromBody] PublicKeyDto dto)
    {
        var userId = GetUserId();
        var user = await _users.GetByIdAsync(userId);
        if (user is null) return NotFound();
        
        user.PublicKey = dto.PublicKey;
        await _users.SaveChangesAsync();
        return Ok();
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
            expires:            DateTime.UtcNow.AddMinutes(15),
            signingCredentials: creds);

        return new JwtSecurityTokenHandler().WriteToken(token);
    }

    private Guid GetUserId() =>
        Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? User.FindFirstValue("sub")
            ?? throw new UnauthorizedAccessException());

    private static string GenerateRefreshToken()
    {
        var randomNumber = new byte[32];
        using var rng = RandomNumberGenerator.Create();
        rng.GetBytes(randomNumber);
        return Convert.ToBase64String(randomNumber);
    }

    private static string HashToken(string token)
    {
        var bytes = SHA256.HashData(Encoding.UTF8.GetBytes(token));
        return Convert.ToBase64String(bytes);
    }
}

public record RegisterDto(string Username, string Password, string? PublicKey);
public record LoginDto(string Username, string Password);
public record RefreshDto(string RefreshToken);
public record DeviceTokenDto(string Token, string Platform);
public record PublicKeyDto(string PublicKey);
