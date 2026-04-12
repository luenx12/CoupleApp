namespace CoupleApp.Core.Entities;

public class DailyTask
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid PairId { get; set; } 
    public string TaskText { get; set; } = string.Empty;
    public int Points { get; set; }
    public string Category { get; set; } = "Genel";
    public DateTime AssignedAt { get; set; } = DateTime.UtcNow;
    
    // Status
    public bool IsAccepted { get; set; }
    public bool IsCompleted { get; set; }
}
