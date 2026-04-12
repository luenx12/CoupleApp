namespace CoupleApp.Core.Entities;

public class DailyQuestion
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public string QuestionText { get; set; } = string.Empty;
    public string Category { get; set; } = "Genel";
    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;
}
