using CoupleApp.Application.Commands;
using CoupleApp.Application.Queries;
using MediatR;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.Mvc;
using System.Security.Claims;

namespace CoupleApp.Backend.Controllers;

[ApiController]
[Route("api/[controller]")]
[Authorize]
public class CoupleController : ControllerBase
{
    private readonly IMediator _mediator;

    public CoupleController(IMediator mediator) => _mediator = mediator;

    /// <summary>
    /// Generates and returns a 6-digit pair invitation code.
    /// Fails if the user is already paired.
    /// </summary>
    [HttpPost("invite")]
    public async Task<IActionResult> InvitePartner()
    {
        var userId = GetUserId();

        try
        {
            var code = await _mediator.Send(new CreateInvitationCommand(userId));
            return Ok(new { InviteCode = code });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(ex.Message);
        }
    }

    /// <summary>
    /// Uses a 6-digit code to complete the pairing.
    /// Fails if the code is invalid, expired, or the user is already paired.
    /// </summary>
    [HttpPost("join/{code}")]
    public async Task<IActionResult> JoinPartner(string code)
    {
        var userId = GetUserId();

        if (string.IsNullOrWhiteSpace(code) || code.Length != 6)
            return BadRequest("Invalid invite code format.");

        try
        {
            var success = await _mediator.Send(new JoinPairCommand(userId, code));
            if (!success)
                return BadRequest("Invalid or expired invite code.");

            return Ok(new { Message = "Successfully paired!" });
        }
        catch (InvalidOperationException ex)
        {
            return BadRequest(ex.Message);
        }
    }

    /// <summary>
    /// Retrieves the authenticated user's paired partner.
    /// Returns 404 Not Found if the user is not paired yet.
    /// </summary>
    [HttpGet("partner")]
    public async Task<IActionResult> GetPartner()
    {
        var userId = GetUserId();
        var partner = await _mediator.Send(new GetPartnerQuery(userId));

        if (partner is null)
            return NotFound("No partner found. Invite them or use an invite code to pair.");

        return Ok(partner);
    }

    private Guid GetUserId() =>
        Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? User.FindFirstValue("sub")
            ?? throw new UnauthorizedAccessException());
}
