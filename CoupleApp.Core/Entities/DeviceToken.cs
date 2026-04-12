using System.ComponentModel.DataAnnotations;

namespace CoupleApp.Core.Entities;

public class DeviceToken
{
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    public Guid UserId { get; set; }
    public User User { get; set; } = null!;

    [Required, MaxLength(500)]
    public string Token { get; set; } = string.Empty;

    [Required, MaxLength(20)]
    public string Platform { get; set; } = string.Empty; // "android" or "ios"

    public DateTime UpdatedAt { get; set; } = DateTime.UtcNow;
}
