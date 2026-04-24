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
    private readonly IConnectionManager _connectionManager;
    private readonly IMessageRepository _messages;
    private readonly IUserRepository _users;
    private readonly IFirebaseService _firebase;
    private readonly ILogger<CoupleHub> _logger;
    private readonly IServiceScopeFactory _scopeFactory;

    // In-memory cache for WhoIsMore answers to determine matches quickly
    private static readonly System.Collections.Concurrent.ConcurrentDictionary<string, string> _whoIsMoreAnswers = new();

    public CoupleHub(
        IConnectionManager connectionManager,
        IMessageRepository messages,
        IUserRepository users,
        IFirebaseService firebase,
        ILogger<CoupleHub> logger,
        IServiceScopeFactory scopeFactory)
    {
        _connectionManager = connectionManager;
        _messages = messages;
        _users = users;
        _firebase = firebase;
        _logger = logger;
        _scopeFactory = scopeFactory;
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
            Id = dto.Id ?? Guid.NewGuid(),
            SenderId = senderId,
            ReceiverId = dto.ReceiverId,
            EncryptedText = dto.EncryptedText,
            EncryptedTextForSender = dto.EncryptedTextForSender,
            IV = dto.IV,
            Type = dto.Type,
            MediaId = dto.MediaId,
            IsDelivered = false,
            SentAt = DateTime.UtcNow
        };

        await _messages.AddAsync(message);
        await _messages.SaveChangesAsync();

        // 4. Build the delivery payload (still ciphertext)
        var payload = new MessageDeliveryDto
        {
            MessageId = message.Id,
            SenderId = senderId,
            EncryptedText = message.EncryptedText,
            IV = message.IV,
            Type = message.Type,
            MediaId = message.MediaId,
            SentAt = message.SentAt
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
        var sharerId = GetUserId();
        var connections = _connectionManager.GetConnections(requesterId);
        if (connections.Count > 0)
            await Clients.Clients(connections)
                         .SendAsync("LocationShared", new
                         {
                             SharerId = sharerId,
                             EncryptedPayload = encryptedPayload
                         });

        _logger.LogInformation("User {SharerId} shared location with {RequesterId}", sharerId, requesterId);
    }

    public async Task DenyLocationAsync(Guid requesterId)
    {
        var deniedById = GetUserId();
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
        var userId = GetUserId();
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
                                     ReadAt = message.ReadAt
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
        {
            await Clients.Clients(connections)
                         .SendAsync("VibeReceived", new { SenderId = senderId, VibeType = vibeType });
        }
        else
        {
            // Offline - Trigger FCM Push Notification
            var deviceTokens = await _users.GetDeviceTokensAsync(partnerId);
            if (deviceTokens.Count > 0)
            {
                var (title, body) = vibeType switch
                {
                    "vibe_miss_you" => ("Seni Özledi! ❤️", "Partnerin şu an seni düşünüyor."),
                    "vibe_kiss" => ("Bir Öpücük Geldi! 😘", "Sana kocaman bir öpücük gönderdi."),
                    "vibe_date" => ("Randevu Teklifi! ☕", "Bugünü beraber geçirmeye ne dersin?"),
                    "vibe_call" => ("Sesini Duymak İstiyor 📞", "Müsait olduğunda onu aramanı bekliyor."),
                    "vibe_thinking" => ("Aklındasın... ✨", "Şu an tam da seni düşünüyor."),
                    "vibe_surprise" => ("Sürpriz! 🎁", "Sana küçük bir sürprizi var, uygulamaya bak!"),
                    _ => ("Yeni Bir Vibe! ✨", "Sana bir etkileşim gönderdi.")
                };

                await _firebase.SendPushNotificationAsync(deviceTokens, title, body);
            }
        }
    }

    // ──────────────────────────────────────────────────────────────────────
    // Games & Red Room
    // ──────────────────────────────────────────────────────────────────────

    public async Task SendWhoIsMoreAnswerAsync(Guid partnerId, string questionId, string answer)
    {
        var senderId = GetUserId();

        // Save the answer in-memory
        var myKey = $"{senderId}_{questionId}";
        _whoIsMoreAnswers[myKey] = answer;

        // Check if partner has answered
        var partnerKey = $"{partnerId}_{questionId}";
        if (_whoIsMoreAnswers.TryGetValue(partnerKey, out var partnerAnswer))
        {
            // Both answered. Check if they picked the same person.
            bool isMatch = (answer == partnerAnswer);

            if (isMatch)
            {
                // Give points
                using var scope = _scopeFactory.CreateScope();
                var db = scope.ServiceProvider.GetRequiredService<CoupleApp.Infrastructure.Persistence.AppDbContext>();

                await AddStatsAsync(db, senderId, 5, 1);
                await AddStatsAsync(db, partnerId, 5, 1);
                await db.SaveChangesAsync();

                // Clear cache for this question to free memory
                _whoIsMoreAnswers.TryRemove(myKey, out _);
                _whoIsMoreAnswers.TryRemove(partnerKey, out _);
            }

            // Notify both of the match result 
            // For MVP simplicity, we just notify the current caller and let the partner know via their own incoming socket if needed, 
            // but the prompt says: "eşleşince konfeti + puan ver". 
            // We can send a specialized MatchResult event, or just broadcast the incoming answer so clients can compare locally.
        }

        var connections = _connectionManager.GetConnections(partnerId);
        if (connections.Count > 0)
            await Clients.Clients(connections)
                         .SendAsync("WhoIsMoreAnswered", new
                         {
                             SenderId = senderId,
                             QuestionId = questionId,
                             Answer = answer
                         });
    }

    private static async Task AddStatsAsync(CoupleApp.Infrastructure.Persistence.AppDbContext db, Guid uid, int points, int matches)
    {
        var st = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.FirstOrDefaultAsync(db.UserStats, s => s.UserId == uid);
        if (st == null)
            db.UserStats.Add(new UserStats { UserId = uid, TotalPoints = points, WhoIsMoreMatches = matches });
        else
        {
            st.TotalPoints += points;
            st.WhoIsMoreMatches += matches;
        }
    }

    public async Task SendFlameLevelAsync(Guid partnerId, double level)
    {
        var senderId = GetUserId();

        // Real-time broadcast
        var connections = _connectionManager.GetConnections(partnerId);
        if (connections.Count > 0)
            await Clients.Clients(connections)
                         .SendAsync("FlameLevelChanged", new { SenderId = senderId, Level = level });

        // Debounce: Only save to DB if 5 minutes have passed since last record
        using var scope = _scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<CoupleApp.Infrastructure.Persistence.AppDbContext>();

        var threshold = DateTime.UtcNow.AddMinutes(-5);
        var recent = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.FirstOrDefaultAsync(
            System.Linq.Queryable.OrderByDescending(
                System.Linq.Queryable.Where(db.FlameLevels, f => f.UserId == senderId),
                f => f.RecordedAt)
        );

        if (recent == null || recent.RecordedAt < threshold)
        {
            db.FlameLevels.Add(new FlameLevel { UserId = senderId, Level = level });
            await db.SaveChangesAsync();
        }
    }

    public async Task SendRedRoomMediaAsync(Guid partnerId, string mediaId, int timeoutSeconds)
    {
        var senderId = GetUserId();
        var connections = _connectionManager.GetConnections(partnerId);
        if (connections.Count > 0)
            await Clients.Clients(connections)
                         .SendAsync("RedRoomMediaReceived", new
                         {
                             SenderId = senderId,
                             MediaId = mediaId,
                             TimeoutSeconds = timeoutSeconds
                         });
    }

    // ──────────────────────────────────────────────────────────────────────
    // Wordle (Zero-Leak)
    // ──────────────────────────────────────────────────────────────────────

    public async Task SendWordleChallengeAsync(Guid partnerId, string encryptedWord)
    {
        var senderId = GetUserId();
        var connections = _connectionManager.GetConnections(partnerId);
        if (connections.Count > 0)
            await Clients.Clients(connections)
                         .SendAsync("WordleChallengeReceived", new { SenderId = senderId, EncryptedWord = encryptedWord });
        else
        {
            var deviceTokens = await _users.GetDeviceTokensAsync(partnerId);
            if (deviceTokens.Count > 0)
                await _firebase.SendPushNotificationAsync(deviceTokens, "Sana Bir Kelime Tuttu! 🤫", "Partnerin Wordle'da senin için bir meydan okuma hazırladı.");
        }
    }

    public async Task SendWordleResultAsync(Guid partnerId, int attempts, bool isDaily)
    {
        var senderId = GetUserId();

        // Update stats
        using var scope = _scopeFactory.CreateScope();
        var db = scope.ServiceProvider.GetRequiredService<CoupleApp.Infrastructure.Persistence.AppDbContext>();
        var st = await Microsoft.EntityFrameworkCore.EntityFrameworkQueryableExtensions.FirstOrDefaultAsync(db.UserStats, s => s.UserId == senderId);

        if (st == null)
        {
            st = new UserStats { UserId = senderId };
            db.UserStats.Add(st);
        }

        st.WordleTotalPlayed++;
        if (st.WordleAverageAttempts == 0)
            st.WordleAverageAttempts = attempts;
        else
            st.WordleAverageAttempts = (st.WordleAverageAttempts * (st.WordleTotalPlayed - 1) + attempts) / st.WordleTotalPlayed;

        // Simplified streak logic (assume consecutive days for simplicity if playing)
        st.WordleCurrentStreak++;
        if (st.WordleCurrentStreak > st.WordleMaxStreak)
            st.WordleMaxStreak = st.WordleCurrentStreak;

        await db.SaveChangesAsync();

        var connections = _connectionManager.GetConnections(partnerId);
        if (connections.Count > 0)
            await Clients.Clients(connections)
                         .SendAsync("WordleResultReceived", new { SenderId = senderId, Attempts = attempts, IsDaily = isDaily });
    }

    // ──────────────────────────────────────────────────────────────────────
    // DrawGuess — Real-time canvas streaming
    // ──────────────────────────────────────────────────────────────────────

    /// <summary>
    /// Drawer streams stroke batches every ~100ms to the guesser.
    /// Payload: { points:[{x,y}], color, strokeWidth, sessionId }
    /// </summary>
    public async Task DrawStrokeAsync(Guid partnerId, DrawStrokeDto dto)
    {
        var senderId = GetUserId();
        var connections = _connectionManager.GetConnections(partnerId);
        if (connections.Count > 0)
            await Clients.Clients(connections)
                         .SendAsync("DrawStrokeReceived", new
                         {
                             SenderId = senderId,
                             dto.SessionId,
                             dto.Points,
                             dto.Color,
                             dto.StrokeWidth,
                             dto.IsEraser,
                         });
    }

    /// <summary>
    /// Drawer cleared the canvas — guesser also clears.
    /// </summary>
    public async Task DrawClearAsync(Guid partnerId, Guid sessionId)
    {
        var connections = _connectionManager.GetConnections(partnerId);
        if (connections.Count > 0)
            await Clients.Clients(connections)
                         .SendAsync("DrawCleared", new { SessionId = sessionId });
    }

    /// <summary>
    /// Server pushes this to the drawer when the guesser guessed correctly
    /// (called from REST POST /guess after DB is updated).
    /// Used to notify drawer of win result in real-time.
    /// </summary>
    public async Task NotifyGuessResultAsync(Guid drawerId, Guid sessionId, bool correct, int score)
    {
        var connections = _connectionManager.GetConnections(drawerId);
        if (connections.Count > 0)
            await Clients.Clients(connections)
                         .SendAsync("DrawGuessResult", new
                         {
                             SessionId = sessionId,
                             Correct = correct,
                             Score = score,
                         });
    }

    // ══════════════════════════════════════════════════════════════════════
    // 🔥 RED ROOM — Modül 1: Spicy Dice (İkimizin Zarları)
    // ══════════════════════════════════════════════════════════════════════

    /// <summary>
    /// Mekan + Pozisyon zarını atar, sonucu hem arayıcıya hem partnere iletir.
    /// Pozisyon nesnesi; ImageKey alanıyla Flutter tarafında SVG/asset eşleşmesi sağlar.
    /// </summary>
    public async Task RollDiceAsync(Guid partnerId)
    {
        var senderId = GetUserId();
        var seed = (int)(DateTime.UtcNow.Ticks % int.MaxValue);
        var rng = new Random(seed);

        var locations = new[]
        {
            "Yatak Odası", "Duşakabin", "Mutfak Tezgahı", "Koltuk",
            "Arka Koltuk", "Boy Aynası Karşısı", "Çamaşır Makinesi Üzeri",
            "Balkon (Dikkatli Olun!)", "Yemek Masası"
        };

        // Her pozisyon için ImageKey, Flutter assets/red_room/positions/ klasörüyle eşleşir.
        var positions = new[]
        {
            new RedRoomPosition("Misyoner",           "pos_missionary"),
            new RedRoomPosition("Doggy Style",        "pos_doggy"),
            new RedRoomPosition("Cowgirl (Üstte)",    "pos_cowgirl"),
            new RedRoomPosition("Reverse Cowgirl",    "pos_rev_cowgirl"),
            new RedRoomPosition("Ayakta",             "pos_standing"),
            new RedRoomPosition("Kaşık Pozisyonu",    "pos_spooning"),
            new RedRoomPosition("Ters Kaşık",         "pos_rev_spooning"),
            new RedRoomPosition("Lotus Pozisyonu",    "pos_lotus"),
            new RedRoomPosition("69 Pozisyonu",       "pos_69"),
            new RedRoomPosition("Masa Kenarı",        "pos_edge"),
            new RedRoomPosition("Kucakta (Yüz Yüze)","pos_lap_face"),
            new RedRoomPosition("Amazon",             "pos_amazon"),
            new RedRoomPosition("Makas Pozisyonu",    "pos_scissors"),
            new RedRoomPosition("Omuzlarda",          "pos_shoulders"),
            new RedRoomPosition("Köprü",              "pos_bridge"),
        };

        var durations = new[]
        {
            "10 Dakika", "15 Dakika", "Yarım Saat",
            "Saatlerce", "Hızlıca (Quickie)", "Sen Yorulana Kadar"
        };

        var picked = positions[rng.Next(positions.Length)];
        var result = new DiceResultDto(
            Location: locations[rng.Next(locations.Length)],
            Position: picked.Name,
            ImageKey: picked.ImageKey,
            Duration: durations[rng.Next(durations.Length)],
            Seed: seed
        );

        await Clients.Caller.SendAsync("DiceResult", result);

        var partnerConns = _connectionManager.GetConnections(partnerId);
        if (partnerConns.Count > 0)
            await Clients.Clients(partnerConns).SendAsync("DiceResult", result);

        _logger.LogInformation("[RedRoom] Dice rolled: {Sender}→{Partner} | Position={Position} ImageKey={Key}",
            senderId, partnerId, result.Position, result.ImageKey);
    }

    // ══════════════════════════════════════════════════════════════════════
    // 🔥 RED ROOM — Modül 2: Red Match (Swipe To Passion)
    // ══════════════════════════════════════════════════════════════════════

    // In-memory swipe store — key: "userId_itemId", value: direction
    private static readonly System.Collections.Concurrent.ConcurrentDictionary<string, string>
        _swipeStore = new();

    /// <summary>
    /// Kullanıcı bir fantezi kartını kaydırdığında partnere bildirir.
    /// itemId = kardaki benzersiz kimlik (ör: "pos_doggy", "fantasy_bdsm").
    /// Her itemId; Flutter tarafında ImageKey olarak kullanılır.
    /// </summary>
    public async Task SwipeFantasyAsync(Guid partnerId, string itemId, string direction)
    {
        var senderId = GetUserId();
        var key = $"{senderId}_{itemId}";
        _swipeStore[key] = direction;

        // Eşleşme kontrolü — partner de aynı kartı sağa kaydırdı mı?
        var partnerKey = $"{partnerId}_{itemId}";
        if (direction == "right" && _swipeStore.TryGetValue(partnerKey, out var partnerDir) && partnerDir == "right")
        {
            // MATCH!
            _swipeStore.TryRemove(key, out _);
            _swipeStore.TryRemove(partnerKey, out _);

            var matchPayload = new RedMatchDto(ItemId: itemId, MatchedAt: DateTime.UtcNow);
            await Clients.Caller.SendAsync("RedMatch", matchPayload);

            var partnerConns = _connectionManager.GetConnections(partnerId);
            if (partnerConns.Count > 0)
                await Clients.Clients(partnerConns).SendAsync("RedMatch", matchPayload);

            _logger.LogInformation("[RedRoom] Match! {A} ↔ {B} on item={Item}", senderId, partnerId, itemId);
            return;
        }

        // Henüz eşleşme yok — sadece partnere swipe haberini gönder
        var partnerConnections = _connectionManager.GetConnections(partnerId);
        if (partnerConnections.Count > 0)
            await Clients.Clients(partnerConnections)
                         .SendAsync("PartnerSwiped", new { SenderId = senderId, ItemId = itemId, Direction = direction });
    }

    // ══════════════════════════════════════════════════════════════════════
    // 🔥 RED ROOM — Modül 3: Roleplay Jeneratörü
    // ══════════════════════════════════════════════════════════════════════

    public async Task GenerateRoleplayAsync(Guid partnerId)
    {
        var rng = new Random();
        var roles = new[]
        {
            new { Role1 = "Patron",       Role2 = "Asistan",   Atmosphere = "Gece Geç Saat, Boş Ofis" },
            new { Role1 = "Yabancı",      Role2 = "Yabancı",   Atmosphere = "Otel Barında İlk Tanışma" },
            new { Role1 = "Öğretmen",     Role2 = "Öğrenci",   Atmosphere = "Cezaya Kalınan Sınıf" },
            new { Role1 = "Polis Memuru", Role2 = "Suçlu",     Atmosphere = "Sorgu Odası" },
            new { Role1 = "Sahip/Sahibe", Role2 = "İtaatkar",  Atmosphere = "Kırmızı Oda (BDSM)" },
            new { Role1 = "Doktor",       Role2 = "Hasta",     Atmosphere = "Özel Muayenehane" },
            new { Role1 = "Masör/Masöz",  Role2 = "Müşteri",   Atmosphere = "VIP Spa Odası" },
            new { Role1 = "Gardiyan",     Role2 = "Mahkum",    Atmosphere = "Hapishane Koridoru" },
            new { Role1 = "Dedektif",     Role2 = "Tanık",     Atmosphere = "Karanlık Ofis" },
            new { Role1 = "Prens",        Role2 = "Prenses",   Atmosphere = "Ortaçağ Sarayı" },
        };

        var pick = roles[rng.Next(roles.Length)];
        var instructions = $"Senaryo: {pick.Atmosphere}. Kural: Karakterden çıkmak yok. Güvenli kelime: 'KIRMIZI'.";

        // Sender'a kendi rolü, Partner'a karşı rolü gönderilir
        await Clients.Caller.SendAsync("RoleplayGenerated", new RoleplayDto(
            MyRole: pick.Role1, PartnerRole: pick.Role2,
            Atmosphere: pick.Atmosphere, Instructions: instructions));

        var partnerConns = _connectionManager.GetConnections(partnerId);
        if (partnerConns.Count > 0)
            await Clients.Clients(partnerConns).SendAsync("RoleplayGenerated", new RoleplayDto(
                MyRole: pick.Role2, PartnerRole: pick.Role1,
                Atmosphere: pick.Atmosphere, Instructions: instructions));
    }

    // ══════════════════════════════════════════════════════════════════════
    // 🔥 RED ROOM — Modül 4: Vücut Haritası
    // ══════════════════════════════════════════════════════════════════════

    /// <summary>
    /// pointsJson: [{"x":0.35,"y":0.42,"label":"Boyun"}, ...] formatında JSON.
    /// Sunucu içeriğe bakmaz — Zero-Leak prensibi korunur.
    /// </summary>
    public async Task SendBodyMapAsync(Guid partnerId, string pointsJson)
    {
        var senderId = GetUserId();
        var partnerConns = _connectionManager.GetConnections(partnerId);
        if (partnerConns.Count > 0)
            await Clients.Clients(partnerConns).SendAsync("BodyMapUpdated", new
            {
                SenderId = senderId,
                PointsJson = pointsJson,
                UpdatedAt = DateTime.UtcNow
            });
    }

    // ══════════════════════════════════════════════════════════════════════
    // 🔥 RED ROOM — Modül 5: Snapshot Roulette
    // ══════════════════════════════════════════════════════════════════════

    public async Task SpinRouletteAsync(Guid partnerId)
    {
        var rng = new Random();
        var zones = new[]
        {
            new { Zone = "Dudaklar",          ImageKey = "zone_lips"         },
            new { Zone = "Boyun",             ImageKey = "zone_neck"         },
            new { Zone = "Göğüs Dekoltesi",   ImageKey = "zone_decolletage"  },
            new { Zone = "Bacaklar",          ImageKey = "zone_legs"         },
            new { Zone = "Bel Kavisi",        ImageKey = "zone_waist"        },
            new { Zone = "Gözler",            ImageKey = "zone_eyes"         },
            new { Zone = "İstediğin Bir Yer", ImageKey = "zone_free"         },
            new { Zone = "Omuzlar",           ImageKey = "zone_shoulders"    },
            new { Zone = "El & Parmaklar",    ImageKey = "zone_hands"        },
            new { Zone = "Kalçalar",          ImageKey = "zone_butt"         },
            new { Zone = "Minnnak",           ImageKey = "zone_tiny"         },
            new { Zone = "Ağzının İçi",       ImageKey = "zone_mouth"        },
            new { Zone = "İç Çamaşırın",      ImageKey = "zone_underwear"    },
            new { Zone = "Sırt",              ImageKey = "zone_back"         },
            new { Zone = "Ayaklar",           ImageKey = "zone_feet"         },
            new { Zone = "Bacak Arası",       ImageKey = "zone_crotch"       },
            new { Zone = "Çıplak Vücudun",    ImageKey = "zone_naked"        },
        };

        var pick = zones[rng.Next(zones.Length)];
        var payload = new RouletteResultDto(Zone: pick.Zone, ImageKey: pick.ImageKey, SpunAt: DateTime.UtcNow);

        await Clients.Caller.SendAsync("RouletteResult", payload);

        var partnerConns = _connectionManager.GetConnections(partnerId);
        if (partnerConns.Count > 0)
            await Clients.Clients(partnerConns).SendAsync("RouletteResult", payload);
    }

    /// <summary>
    /// Roulette'den çıkan bölge fotoğrafını (3 sn sonra imha emriyle) partnere iletir.
    /// </summary>
    public async Task SendRouletteMediaAsync(Guid partnerId, string mediaId, string zone)
    {
        var senderId = GetUserId();
        var partnerConns = _connectionManager.GetConnections(partnerId);
        if (partnerConns.Count > 0)
            await Clients.Clients(partnerConns).SendAsync("RouletteMediaReceived", new
            {
                SenderId = senderId,
                MediaId = mediaId,
                Zone = zone,
                DestructAfterMs = 3000
            });
    }

    // ══════════════════════════════════════════════════════════════════════
    // 🔥 RED ROOM — Modül 7: Karanlık Oda (Spotlight & Heatmap)
    // ══════════════════════════════════════════════════════════════════════

    /// <summary>Parmak koordinatını (normalize 0-1) partnere ultra-low latency aktarır.</summary>
    public async Task SendSpotlightMoveAsync(Guid partnerId, double x, double y)
    {
        var partnerConns = _connectionManager.GetConnections(partnerId);
        if (partnerConns.Count > 0)
            await Clients.Clients(partnerConns).SendAsync("SpotlightMoved", new
            {
                X = x,
                Y = y,
                Ts = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()
            });
    }

    /// <summary>Karanlık Oda oturumunu başlatır — şifreli medya ID'si partnere iletilir.</summary>
    public async Task StartDarkRoomAsync(Guid partnerId, string encryptedMediaId)
    {
        var senderId = GetUserId();
        var partnerConns = _connectionManager.GetConnections(partnerId);
        if (partnerConns.Count > 0)
            await Clients.Clients(partnerConns).SendAsync("DarkRoomStarted", new
            {
                SenderId = senderId,
                EncryptedMediaId = encryptedMediaId,
                StartedAt = DateTime.UtcNow
            });

        _logger.LogInformation("[RedRoom] DarkRoom started: {Sender}→{Partner}", senderId, partnerId);
    }

    /// <summary>Isı haritası güncellemesi — hangi bölgeye en çok bakıldığı hesaplanır.</summary>
    public async Task SendHeatmapUpdateAsync(Guid partnerId, string heatmapJson)
    {
        var partnerConns = _connectionManager.GetConnections(partnerId);
        if (partnerConns.Count > 0)
            await Clients.Clients(partnerConns).SendAsync("HeatmapUpdated", new
            {
                HeatmapJson = heatmapJson,
                UpdatedAt = DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()
            });
    }

    // ══════════════════════════════════════════════════════════════════════
    // 🛑 RED ROOM — Safe Word & Emergency Stop
    // ══════════════════════════════════════════════════════════════════════

    /// <summary>
    /// Güvenli kelime tetiklendiğinde her iki tarafı da anlık olarak durdurur.
    /// Her aktif Red Room oturumu bu sinyali izler ve kendini kapatır.
    /// </summary>
    public async Task TriggerSafeWordAsync(Guid partnerId)
    {
        var senderId = GetUserId();
        var partnerConns = _connectionManager.GetConnections(partnerId);
        var payload = new { SenderId = senderId, TriggeredAt = DateTime.UtcNow };

        await Clients.Caller.SendAsync("SafeWordTriggered", payload);
        if (partnerConns.Count > 0)
            await Clients.Clients(partnerConns).SendAsync("SafeWordTriggered", payload);

        _logger.LogWarning("[RedRoom] ⚠️ SAFE WORD triggered by {UserId}!", senderId);
    }

    // ══════════════════════════════════════════════════════════════════════
    // 🔥 FANTASY BOARD — Fantezi Masası
    // ══════════════════════════════════════════════════════════════════════

    // In-memory vote store — key: "boardId_userId", value: "cardId"
    private static readonly System.Collections.Concurrent.ConcurrentDictionary<string, string>
        _fantasyVotes = new();

    /// <summary>
    /// Her iki cihaza 3'lü görev zarflarını düşürür.
    /// Payload içeriği tamamen client tarafından oluşturulur (Zero-Leak: sunucu bakmaz).
    /// </summary>
    public async Task TriggerFantasyBoardAsync(Guid partnerId, string boardId, string boardPayloadJson)
    {
        var senderId = GetUserId();

        var payload = new FantasyBoardTriggeredDto(
            BoardId: boardId,
            BoardPayloadJson: boardPayloadJson,
            TriggeredAt: DateTime.UtcNow);

        // Caller (tetikleyen kişi) de alır
        await Clients.Caller.SendAsync("FantasyBoardReceived", payload);

        var partnerConns = _connectionManager.GetConnections(partnerId);
        if (partnerConns.Count > 0)
            await Clients.Clients(partnerConns).SendAsync("FantasyBoardReceived", payload);
        else
        {
            var deviceTokens = await _users.GetDeviceTokensAsync(partnerId);
            if (deviceTokens.Count > 0)
                await _firebase.SendPushNotificationAsync(deviceTokens,
                    "Fantezi Masası Geldi! 🔥",
                    "Partnerin sana özel bir görev zarfı gönderdi.");
        }

        _logger.LogInformation("[FantasyBoard] Triggered: {Sender}→{Partner} BoardId={BoardId}",
            senderId, partnerId, boardId);
    }

    /// <summary>
    /// Bir kişi karta oy verdiğinde diğerine bildirir.
    /// Sunucu tarafında match kontrolü yapar; eşleşirse FantasyCardMatched tetikler.
    /// </summary>
    public async Task VoteFantasyCardAsync(Guid partnerId, string boardId, string cardId)
    {
        var senderId = GetUserId();

        // Oyu kaydet
        var myKey = $"{boardId}_{senderId}";
        _fantasyVotes[myKey] = cardId;

        // Partner oyu var mı kontrol et
        var partnerKey = $"{boardId}_{partnerId}";
        bool isMatch = _fantasyVotes.TryGetValue(partnerKey, out var partnerCardId)
                       && partnerCardId == cardId;

        // Partnere "biri oy verdi" bildir
        var partnerConns = _connectionManager.GetConnections(partnerId);
        if (partnerConns.Count > 0)
            await Clients.Clients(partnerConns).SendAsync("PartnerVotedFantasyCard", new FantasyVoteDto(
                SenderId: senderId.ToString(),
                BoardId: boardId,
                CardId: cardId));

        if (isMatch)
        {
            // Oylama tamamlandı — her iki tarafı da bildir
            _fantasyVotes.TryRemove(myKey, out _);
            _fantasyVotes.TryRemove(partnerKey, out _);

            var matchPayload = new FantasyMatchDto(BoardId: boardId, CardId: cardId, MatchedAt: DateTime.UtcNow);

            await Clients.Caller.SendAsync("FantasyCardMatched", matchPayload);
            if (partnerConns.Count > 0)
                await Clients.Clients(partnerConns).SendAsync("FantasyCardMatched", matchPayload);

            _logger.LogInformation("[FantasyBoard] MATCH! {A}↔{B} | Board={BoardId} Card={CardId}",
                senderId, partnerId, boardId, cardId);
        }
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
    Guid? Id,
    Guid ReceiverId,
    string EncryptedText,
    string? EncryptedTextForSender,
    string? IV,
    string? MediaId,
    MessageType Type = MessageType.Text
);

public record MessageDeliveryDto
{
    public Guid MessageId { get; init; }
    public Guid SenderId { get; init; }
    public string EncryptedText { get; init; } = string.Empty;
    public string? IV { get; init; }
    public string? MediaId { get; init; }
    public MessageType Type { get; init; }
    public DateTime SentAt { get; init; }
}

public record DrawPointDto(double X, double Y);

public record DrawStrokeDto(
    Guid SessionId,
    List<DrawPointDto> Points,
    string Color,
    double StrokeWidth,
    bool IsEraser = false
);

// ── Red Room DTOs ──────────────────────────────────────────────────────────

/// <summary>Zar atma sonucu — ImageKey Flutter asset yolu için kullanılır.</summary>
public record DiceResultDto(
    string Location,
    string Position,
    string ImageKey,
    string Duration,
    int Seed
);

/// <summary>Pozisyon listesi için iç yardımcı kayıt.</summary>
public record RedRoomPosition(string Name, string ImageKey);

/// <summary>Roleplay senaryosu.</summary>
public record RoleplayDto(
    string MyRole,
    string PartnerRole,
    string Atmosphere,
    string Instructions
);

/// <summary>Red Match eşleşme bildirimi.</summary>
public record RedMatchDto(
    string ItemId,
    DateTime MatchedAt
);

/// <summary>Snapshot Roulette zone sonucu.</summary>
public record RouletteResultDto(
    string Zone,
    string ImageKey,
    DateTime SpunAt
);

// ── Fantasy Board DTOs ──────────────────────────────────────────────────────

/// <summary>Her iki cihaza gönderilen Fantasy Board tetikleme payload'ı.</summary>
public record FantasyBoardTriggeredDto(
    string BoardId,
    string BoardPayloadJson,
    DateTime TriggeredAt
);

/// <summary>Bir kullanıcı karta oy verdiğinde partnere giden bildirim.</summary>
public record FantasyVoteDto(
    string SenderId,
    string BoardId,
    string CardId
);

/// <summary>İki oy aynı kartta buluşunca her iki tarafa giden eşleşme bildirimi.</summary>
public record FantasyMatchDto(
    string BoardId,
    string CardId,
    DateTime MatchedAt
);

