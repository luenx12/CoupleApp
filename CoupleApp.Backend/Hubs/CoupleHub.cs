using CoupleApp.Backend.Data;
using CoupleApp.Backend.Entities;
using CoupleApp.Backend.Services;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using Microsoft.EntityFrameworkCore;
using System.Security.Claims;

namespace CoupleApp.Backend.Hubs;

/// <summary>
/// SignalR Hub — main real-time channel between two partners.
/// All messages arrive already encrypted (E2EE); server persists ciphertext only.
/// </summary>
[Authorize]
public class CoupleHub : Hub
{
    private readonly IConnectionManager _connectionManager;
    private readonly AppDbContext _db;
    private readonly ILogger<CoupleHub> _logger;

    public CoupleHub(
        IConnectionManager connectionManager,
        AppDbContext db,
        ILogger<CoupleHub> logger)
    {
        _connectionManager = connectionManager;
        _db = db;
        _logger = logger;
    }

    // ──────────────────────────────────────────────────────────────────────
    // Connection lifecycle
    // ──────────────────────────────────────────────────────────────────────

    public override async Task OnConnectedAsync()
    {
        var userId = GetUserId();
        _connectionManager.AddConnection(userId, Context.ConnectionId);
        _logger.LogInformation("User {UserId} connected. ConnectionId={ConnectionId}", userId, Context.ConnectionId);
        await base.OnConnectedAsync();
    }

    public override async Task OnDisconnectedAsync(Exception? exception)
    {
        var userId = GetUserId();
        _connectionManager.RemoveConnection(userId, Context.ConnectionId);
        _logger.LogInformation("User {UserId} disconnected. ConnectionId={ConnectionId}", userId, Context.ConnectionId);
        await base.OnDisconnectedAsync(exception);
    }

    // ──────────────────────────────────────────────────────────────────────
    // Core: SendMessageAsync
    // ──────────────────────────────────────────────────────────────────────

    /// <summary>
    /// Receives an already-encrypted message from the sender, persists it to DB,
    /// and forwards it to the partner if they are online — Zero-Leak: no plaintext ever touches the server.
    /// </summary>
    /// <param name="dto">Send message payload</param>
    public async Task SendMessageAsync(SendMessageDto dto)
    {
        var senderId = GetUserId();

        // 1. Basic validation
        if (string.IsNullOrWhiteSpace(dto.EncryptedText))
        {
            await Clients.Caller.SendAsync("Error", "EncryptedText cannot be empty.");
            return;
        }

        // 2. Verify the receiver exists
        var receiver = await _db.Users.FindAsync(dto.ReceiverId);
        if (receiver is null)
        {
            await Clients.Caller.SendAsync("Error", $"Receiver {dto.ReceiverId} not found.");
            return;
        }

        // 3. Persist (ciphertext only — Zero-Leak principle)
        var message = new Message
        {
            SenderId          = senderId,
            ReceiverId        = dto.ReceiverId,
            EncryptedText     = dto.EncryptedText,
            EncryptedTextForSender = dto.EncryptedTextForSender,
            IV                = dto.IV,
            Type              = dto.Type,
            IsDelivered       = false,
            SentAt            = DateTime.UtcNow
        };

        _db.Messages.Add(message);
        await _db.SaveChangesAsync();

        // 4. Build the delivery payload (still ciphertext)
        var payload = new MessageDeliveryDto
        {
            MessageId     = message.Id,
            SenderId      = senderId,
            EncryptedText = message.EncryptedText,
            IV            = message.IV,
            Type          = message.Type,
            SentAt        = message.SentAt
        };

        // 5. Deliver to receiver if online
        var receiverConnections = _connectionManager.GetConnections(dto.ReceiverId);
        if (receiverConnections.Count > 0)
        {
            await Clients.Clients(receiverConnections)
                         .SendAsync("ReceiveMessage", payload);

            // Mark as delivered
            message.IsDelivered = true;
            message.DeliveredAt = DateTime.UtcNow;
            await _db.SaveChangesAsync();
        }

        // 6. Acknowledge to sender
        await Clients.Caller.SendAsync("MessageSent", new { message.Id, message.SentAt, message.IsDelivered });

        _logger.LogInformation("Message {MessageId} sent: {SenderId} → {ReceiverId}, delivered={Delivered}",
            message.Id, senderId, dto.ReceiverId, message.IsDelivered);
    }

    /// <summary>
    /// Called by receiver to mark a message as read.
    /// </summary>
    public async Task MarkAsReadAsync(Guid messageId)
    {
        var userId = GetUserId();

        var message = await _db.Messages.FindAsync(messageId);
        if (message is null || message.ReceiverId != userId) return;

        if (!message.IsRead)
        {
            message.IsRead  = true;
            message.ReadAt  = DateTime.UtcNow;
            await _db.SaveChangesAsync();

            // Notify sender
            var senderConnections = _connectionManager.GetConnections(message.SenderId);
            if (senderConnections.Count > 0)
                await Clients.Clients(senderConnections)
                             .SendAsync("MessageRead", new { MessageId = messageId, ReadAt = message.ReadAt });
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // Typing indicator
    // ──────────────────────────────────────────────────────────────────────

    public async Task SendTypingAsync(Guid partnerId, bool isTyping)
    {
        var senderId = GetUserId();
        var partnerConnections = _connectionManager.GetConnections(partnerId);
        if (partnerConnections.Count > 0)
            await Clients.Clients(partnerConnections)
                         .SendAsync("PartnerTyping", new { SenderId = senderId, IsTyping = isTyping });
    }

    // ──────────────────────────────────────────────────────────────────────
    // Helpers
    // ──────────────────────────────────────────────────────────────────────

    private Guid GetUserId()
    {
        var claim = Context.User?.FindFirst(ClaimTypes.NameIdentifier)?.Value
                 ?? Context.User?.FindFirst("sub")?.Value;

        return Guid.TryParse(claim, out var id)
            ? id
            : throw new HubException("Unauthorized: missing or invalid user identity.");
    }
}

// ── DTOs (hub-scoped, lightweight) ────────────────────────────────────────

public record SendMessageDto(
    Guid ReceiverId,
    string EncryptedText,
    string? EncryptedTextForSender,
    string? IV,
    MessageType Type = MessageType.Text
);

public record MessageDeliveryDto
{
    public Guid MessageId     { get; init; }
    public Guid SenderId      { get; init; }
    public string EncryptedText { get; init; } = string.Empty;
    public string? IV         { get; init; }
    public MessageType Type   { get; init; }
    public DateTime SentAt    { get; init; }
}
