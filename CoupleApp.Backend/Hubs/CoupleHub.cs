using CoupleApp.Backend.Services;
using CoupleApp.Core.Entities;
using CoupleApp.Core.Interfaces.Repositories;
using Microsoft.AspNetCore.Authorization;
using Microsoft.AspNetCore.SignalR;
using System.Security.Claims;

namespace CoupleApp.Backend.Hubs;

/// <summary>
/// SignalR Hub — main real-time channel between two partners.
/// All messages arrive already encrypted (E2EE); server persists ciphertext only.
/// Refactored to use IMessageRepository and IUserRepository instead of AppDbContext directly.
/// </summary>
[Authorize]
public class CoupleHub : Hub
{
    private readonly IConnectionManager  _connectionManager;
    private readonly IMessageRepository  _messages;
    private readonly IUserRepository     _users;
    private readonly IFirebaseService    _firebase;
    private readonly ILogger<CoupleHub>  _logger;

    public CoupleHub(
        IConnectionManager  connectionManager,
        IMessageRepository  messages,
        IUserRepository     users,
        IFirebaseService    firebase,
        ILogger<CoupleHub>  logger)
    {
        _connectionManager = connectionManager;
        _messages          = messages;
        _users             = users;
        _firebase          = firebase;
        _logger            = logger;
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
        var receiver = await _users.GetByIdAsync(dto.ReceiverId);
        if (receiver is null)
        {
            await Clients.Caller.SendAsync("Error", $"Receiver {dto.ReceiverId} not found.");
            return;
        }

        // 3. Persist (ciphertext only — Zero-Leak principle)
        var message = new Message
        {
            SenderId               = senderId,
            ReceiverId             = dto.ReceiverId,
            EncryptedText          = dto.EncryptedText,
            EncryptedTextForSender = dto.EncryptedTextForSender,
            IV                     = dto.IV,
            Type                   = dto.Type,
            MediaId                = dto.MediaId,
            IsDelivered            = false,
            SentAt                 = DateTime.UtcNow
        };

        await _messages.AddAsync(message);
        await _messages.SaveChangesAsync();

        // 4. Build the delivery payload (still ciphertext)
        var payload = new MessageDeliveryDto
        {
            MessageId     = message.Id,
            SenderId      = senderId,
            EncryptedText = message.EncryptedText,
            IV            = message.IV,
            Type          = message.Type,
            MediaId       = message.MediaId,
            SentAt        = message.SentAt
        };

        // 5. Deliver to receiver if online, else push notification
        var receiverConnections = _connectionManager.GetConnections(dto.ReceiverId);
        if (receiverConnections.Count > 0)
        {
            await Clients.Clients(receiverConnections).SendAsync("ReceiveMessage", payload);

            // Mark as delivered
            message.IsDelivered = true;
            message.DeliveredAt = DateTime.UtcNow;
            await _messages.SaveChangesAsync();
        }
        else
        {
            // Offline - Trigger FCM Push Notification
            var deviceTokens = await _users.GetDeviceTokensAsync(dto.ReceiverId);
            if (deviceTokens.Count > 0)
            {
                // Zero-Leak safe generic text mapping
                string pushBody = dto.Type switch 
                {
                    MessageType.Image => "Sana bir fotoğraf gönderdi 📸",
                    MessageType.Voice => "Sana bir ses kaydı gönderdi 🎤",
                    MessageType.Sticker => "Sana bir çıkartma gönderdi ✨",
                    _ => "Yeni mesajın var 💌"
                };

                await _firebase.SendPushNotificationAsync(deviceTokens, "CoupleApp", pushBody);
            }
        }

        // 6. Acknowledge to sender
        await Clients.Caller.SendAsync("MessageSent", new
        {
            message.Id,
            message.SentAt,
            message.IsDelivered
        });

        _logger.LogInformation(
            "Message {MessageId} sent: {SenderId} → {ReceiverId}, delivered={Delivered}",
            message.Id, senderId, dto.ReceiverId, message.IsDelivered);
    }

    // ──────────────────────────────────────────────────────────────────────
    // Location sharing (all payloads are E2EE-encrypted by client)
    // ──────────────────────────────────────────────────────────────────────

    public async Task RequestLocationAsync(Guid partnerId)
    {
        var requesterId = GetUserId();
        var connections = _connectionManager.GetConnections(partnerId);
        if (connections.Count > 0)
            await Clients.Clients(connections)
                         .SendAsync("LocationRequested", new { RequesterId = requesterId });

        _logger.LogInformation("User {RequesterId} requested location from {PartnerId}", requesterId, partnerId);
    }

    public async Task ShareLocationAsync(Guid requesterId, string encryptedPayload)
    {
        var sharerId    = GetUserId();
        var connections = _connectionManager.GetConnections(requesterId);
        if (connections.Count > 0)
            await Clients.Clients(connections)
                         .SendAsync("LocationShared", new
                         {
                             SharerId         = sharerId,
                             EncryptedPayload = encryptedPayload
                         });

        _logger.LogInformation("User {SharerId} shared location with {RequesterId}", sharerId, requesterId);
    }

    public async Task DenyLocationAsync(Guid requesterId)
    {
        var deniedById  = GetUserId();
        var connections = _connectionManager.GetConnections(requesterId);
        if (connections.Count > 0)
            await Clients.Clients(connections)
                         .SendAsync("LocationDenied", new { DeniedById = deniedById });
    }

    // ──────────────────────────────────────────────────────────────────────
    // MarkAsRead (real-time path via Hub)
    // ──────────────────────────────────────────────────────────────────────

    public async Task MarkAsReadAsync(Guid messageId)
    {
        var userId  = GetUserId();
        var success = await _messages.MarkAsReadAsync(messageId, userId);

        if (success)
        {
            var message = await _messages.GetByIdAsync(messageId);
            if (message is not null)
            {
                var senderConnections = _connectionManager.GetConnections(message.SenderId);
                if (senderConnections.Count > 0)
                    await Clients.Clients(senderConnections)
                                 .SendAsync("MessageRead", new
                                 {
                                     MessageId = messageId,
                                     ReadAt    = message.ReadAt
                                 });
            }
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
    // Daily Vibe & Sync
    // ──────────────────────────────────────────────────────────────────────

    public async Task SyncWaterAsync(Guid partnerId, int waterCount)
    {
        var senderId = GetUserId();
        var connections = _connectionManager.GetConnections(partnerId);
        if (connections.Count > 0)
            await Clients.Clients(connections)
                         .SendAsync("WaterSynced", new { SenderId = senderId, WaterCount = waterCount });
    }

    public async Task SendVibeAsync(Guid partnerId, string vibeType)
    {
        var senderId = GetUserId();
        var connections = _connectionManager.GetConnections(partnerId);
        if (connections.Count > 0)
            await Clients.Clients(connections)
                         .SendAsync("VibeReceived", new { SenderId = senderId, VibeType = vibeType });
    }

    // ──────────────────────────────────────────────────────────────────────
    // Games & Red Room
    // ──────────────────────────────────────────────────────────────────────

    public async Task SendWhoIsMoreAnswerAsync(Guid partnerId, string questionId, string answer)
    {
        var senderId = GetUserId();
        var connections = _connectionManager.GetConnections(partnerId);
        if (connections.Count > 0)
            await Clients.Clients(connections)
                         .SendAsync("WhoIsMoreAnswered", new
                         {
                             SenderId   = senderId,
                             QuestionId = questionId,
                             Answer     = answer
                         });
    }

    public async Task SendFlameLevelAsync(Guid partnerId, double level)
    {
        var senderId = GetUserId();
        var connections = _connectionManager.GetConnections(partnerId);
        if (connections.Count > 0)
            await Clients.Clients(connections)
                         .SendAsync("FlameLevelChanged", new { SenderId = senderId, Level = level });
    }

    public async Task SendRedRoomMediaAsync(Guid partnerId, string mediaId, int timeoutSeconds)
    {
        var senderId = GetUserId();
        var connections = _connectionManager.GetConnections(partnerId);
        if (connections.Count > 0)
            await Clients.Clients(connections)
                         .SendAsync("RedRoomMediaReceived", new
                         {
                             SenderId       = senderId,
                             MediaId        = mediaId,
                             TimeoutSeconds = timeoutSeconds
                         });
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
    string? MediaId,
    MessageType Type = MessageType.Text
);

public record MessageDeliveryDto
{
    public Guid MessageId       { get; init; }
    public Guid SenderId        { get; init; }
    public string EncryptedText { get; init; } = string.Empty;
    public string? IV           { get; init; }
    public string? MediaId      { get; init; }
    public MessageType Type     { get; init; }
    public DateTime SentAt      { get; init; }
}
