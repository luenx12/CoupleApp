using FirebaseAdmin;
using FirebaseAdmin.Messaging;
using Google.Apis.Auth.OAuth2;

namespace CoupleApp.Backend.Services;

public interface IFirebaseService
{
    Task SendPushNotificationAsync(List<string> tokens, string title, string body);
}

public class FirebaseService : IFirebaseService
{
    private readonly ILogger<FirebaseService> _logger;

    public FirebaseService(IConfiguration config, ILogger<FirebaseService> logger)
    {
        _logger = logger;
        
        var jsonKey = config["Firebase:ServerKey"]; // Could be absolute path or serialized JSON credentials string.
        // Assuming proper service account JSON string is injected (or path):
        if (FirebaseApp.DefaultInstance == null && !string.IsNullOrEmpty(jsonKey))
        {
            try 
            {
                // In production, you'd mount a JSON credentials file via Docker and point to it,
                // or supply the raw JSON in the environment. Here we assume JSON string.
                FirebaseApp.Create(new AppOptions
                {
                    Credential = GoogleCredential.FromJson(jsonKey)
                });
            }
            catch (Exception ex)
            {
                _logger.LogError(ex, "Failed to initialize FirebaseApp. Push notifications will be disabled.");
            }
        }
    }

    public async Task SendPushNotificationAsync(List<string> tokens, string title, string body)
    {
        if (tokens == null || tokens.Count == 0 || FirebaseApp.DefaultInstance == null) return;

        var message = new MulticastMessage
        {
            Tokens = tokens,
            Notification = new Notification
            {
                Title = title,
                Body = body
            },
            Android = new AndroidConfig
            {
                Priority = Priority.High
            },
            Apns = new ApnsConfig
            {
                Headers = new Dictionary<string, string> { { "apns-priority", "10" } },
                Aps = new Aps
                {
                    Sound = "default"
                }
            }
        };

        try
        {
            var response = await FirebaseMessaging.DefaultInstance.SendEachForMulticastAsync(message);
            if (response.FailureCount > 0)
            {
                _logger.LogWarning("{Count} push notifications failed to send.", response.FailureCount);
                // Advanced: if error is NotRegistered/InvalidRegistration => delete tokens using IUserRepository but
                // we'll keep it simple: logs only. Next launch will update token anyway.
            }
        }
        catch (Exception ex)
        {
            _logger.LogError(ex, "Failed to dispatch Firebase MulticastMessage");
        }
    }
}
