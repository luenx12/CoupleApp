namespace CoupleApp.Core.Entities;

public class UserStats
{
    public Guid Id { get; set; } = Guid.NewGuid();
    public Guid UserId { get; set; }
    public int TotalPoints { get; set; }
    public int WhoIsMoreMatches { get; set; }
    
    // Wordle Stats
    public int WordleTotalPlayed { get; set; }
    public double WordleAverageAttempts { get; set; }
    public int WordleCurrentStreak { get; set; }
    public int WordleMaxStreak { get; set; }
    
    // Navigation
    public User User { get; set; } = null!;
}
