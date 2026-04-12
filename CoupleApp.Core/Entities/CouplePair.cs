using System.ComponentModel.DataAnnotations;

namespace CoupleApp.Core.Entities;

public class CouplePair
{
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    public Guid User1Id { get; set; }

    [Required]
    public Guid User2Id { get; set; }

    public User User1 { get; set; } = null!;
    public User User2 { get; set; } = null!;

    public DateTime PairedAt { get; set; } = DateTime.UtcNow;
}
