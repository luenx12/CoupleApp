namespace CoupleApp.Core.Entities;

public class FlameLevel
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public double Level { get; set; }
    public DateTime RecordedAt { get; set; } = DateTime.UtcNow;
    
    // Navigation
    public User User { get; set; } = null!;
}
