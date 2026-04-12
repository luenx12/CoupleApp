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
public class MessagesController : ControllerBase
{
    private readonly IMediator _mediator;

    public MessagesController(IMediator mediator) => _mediator = mediator;

    /// <summary>
    /// Returns paginated conversation history between the authenticated user and their partner.
    /// Only encrypted blobs are returned — Zero-Leak.
    /// </summary>
    [HttpGet("history/{partnerId:guid}")]
    public async Task<IActionResult> GetHistory(
        Guid partnerId,
        [FromQuery] int page = 1,
        [FromQuery] int pageSize = 50)
    {
        var userId = GetUserId();

        var result = await _mediator.Send(
            new GetMessageHistoryQuery(userId, partnerId, page, pageSize));

        return Ok(result);
    }

    /// <summary>
    /// Soft-delete a sent message (sender only). Wipes ciphertext.
    /// </summary>
    [HttpDelete("{id:guid}")]
    public async Task<IActionResult> Delete(Guid id)
    {
        var userId  = GetUserId();
        var deleted = await _mediator.Send(new DeleteMessageCommand(id, userId));

        return deleted ? NoContent() : NotFound();
    }

    /// <summary>
    /// Mark a received message as read.
    /// </summary>
    [HttpPost("{id:guid}/read")]
    public async Task<IActionResult> MarkAsRead(Guid id)
    {
        var userId  = GetUserId();
        var success = await _mediator.Send(new MarkAsReadCommand(id, userId));

        return success ? NoContent() : NotFound();
    }

    private Guid GetUserId() =>
        Guid.Parse(User.FindFirstValue(ClaimTypes.NameIdentifier)
            ?? User.FindFirstValue("sub")
            ?? throw new UnauthorizedAccessException());
}
