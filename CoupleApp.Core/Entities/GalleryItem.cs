using System.ComponentModel.DataAnnotations;
using System.ComponentModel.DataAnnotations.Schema;

namespace CoupleApp.Core.Entities;

public class GalleryItem
{
    [Key]
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    public Guid UploaderId { get; set; }

    [ForeignKey(nameof(UploaderId))]
    public User? Uploader { get; set; }

    [Required]
    public Guid ReceiverId { get; set; }

    [ForeignKey(nameof(ReceiverId))]
    public User? Receiver { get; set; }

    [Required]
    public string MediaIdForSender { get; set; } = string.Empty;

    [Required]
    public string MediaIdForReceiver { get; set; } = string.Empty;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    // Zaman Kapsülü için ileri tarih
    public DateTime? LockedUntil { get; set; }
}
