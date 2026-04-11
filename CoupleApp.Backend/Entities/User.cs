using System.ComponentModel.DataAnnotations;

namespace CoupleApp.Backend.Entities;

public class User
{
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required, MaxLength(50)]
    public string Username { get; set; } = string.Empty;

    [Required, MaxLength(255)]
    public string PasswordHash { get; set; } = string.Empty;

    /// <summary>
    /// Public key used for E2EE key exchange (stored as Base64)
    /// </summary>
    [MaxLength(2048)]
    public string? PublicKey { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
    public DateTime? LastSeenAt { get; set; }

    // Navigation properties
    public ICollection<Message> SentMessages { get; set; } = [];
    public ICollection<Message> ReceivedMessages { get; set; } = [];
    public ICollection<Activity> Activities { get; set; } = [];
    public ICollection<GameTask> GameTasks { get; set; } = [];
}
