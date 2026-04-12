using System.ComponentModel.DataAnnotations;

namespace CoupleApp.Core.Entities;

public class Message
{
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    public Guid SenderId { get; set; }

    [Required]
    public Guid ReceiverId { get; set; }

    /// <summary>
    /// End-to-End Encrypted ciphertext (client encrypts with receiver's public key before sending)
    /// Server NEVER stores plaintext.
    /// </summary>
    [Required]
    public string EncryptedText { get; set; } = string.Empty;

    /// <summary>
    /// Encrypted copy for the sender (so sender can read their own messages)
    /// </summary>
    public string? EncryptedTextForSender { get; set; }

    /// <summary>
    /// Optional: IV / nonce used during encryption (algorithm-specific)
    /// </summary>
    [MaxLength(512)]
    public string? IV { get; set; }

    public MessageType Type { get; set; } = MessageType.Text;

    /// <summary>
    /// Server-side media ID (for encrypted image self-destruct).
    /// Client sends DELETE /api/Media/{MediaId} after viewing.
    /// </summary>
    [MaxLength(100)]
    public string? MediaId { get; set; }

    public bool IsDelivered { get; set; } = false;
    public bool IsRead { get; set; } = false;
    public bool IsDeleted { get; set; } = false;

    public DateTime SentAt { get; set; } = DateTime.UtcNow;
    public DateTime? DeliveredAt { get; set; }
    public DateTime? ReadAt { get; set; }

    // Navigation properties
    public User Sender { get; set; } = null!;
    public User Receiver { get; set; } = null!;
}

public enum MessageType
{
    Text = 0,
    Image = 1,
    Voice = 2,
    Sticker = 3
}
