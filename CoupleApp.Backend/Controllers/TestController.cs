using CoupleApp.Backend.Services;
using CoupleApp.Core.Interfaces.Repositories;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace CoupleApp.Backend.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class TestController : ControllerBase
{
    private readonly IFirebaseService _firebaseService;
    private readonly IUserRepository _users;
    private readonly ILogger<TestController> _logger;

    public TestController(IFirebaseService firebaseService, IUserRepository users, ILogger<TestController> logger)
    {
        _firebaseService = firebaseService;
        _users = users;
        _logger = logger;
    }

    [HttpPost("push")]
    public async Task<IActionResult> TestPush()
    {
        var idClaim = User.FindFirst(ClaimTypes.NameIdentifier)?.Value;
        if (!Guid.TryParse(idClaim, out var userId)) return Unauthorized();

        try
        {
            var tokens = await _users.GetDeviceTokensAsync(userId);
            if (tokens == null || tokens.Count == 0)
                return BadRequest("No device tokens found for user.");

            await _firebaseService.SendPushNotificationAsync(
                tokens,
                "🛠️ Geliştirici Testi",
                "Bu bir test push bildirimidir. Sistemin çalıştığını gösterir."
            );

            return Ok(new { message = "Test bildirimi gönderildi." });
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Push test failed.");
            return StatusCode(500, "Bildirim gönderilemedi.");
        }
    }
}
