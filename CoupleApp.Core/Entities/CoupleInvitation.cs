using System.ComponentModel.DataAnnotations;

namespace CoupleApp.Core.Entities;

public enum InvitationStatus
{
    Pending,
    Accepted,
    Expired
}

public class CoupleInvitation
{
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    public Guid InviterUserId { get; set; }
    
    // Navigation
    public User Inviter { get; set; } = null!;

    [Required, StringLength(6, MinimumLength = 6)]
    public string InviteCode { get; set; } = string.Empty;

    public DateTime ExpiresAt { get; set; }
    public InvitationStatus Status { get; set; } = InvitationStatus.Pending;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
