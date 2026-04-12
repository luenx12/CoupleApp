using System.ComponentModel.DataAnnotations;

namespace CoupleApp.Core.Entities;

public class GameTask
{
    public Guid Id { get; set; } = Guid.NewGuid();

    /// <summary>The user who assigned this task to their partner</summary>
    [Required]
    public Guid AssignedByUserId { get; set; }

    /// <summary>The user who needs to complete this task</summary>
    [Required]
    public Guid AssignedToUserId { get; set; }

    [Required, MaxLength(200)]
    public string Title { get; set; } = string.Empty;

    [MaxLength(1000)]
    public string? Description { get; set; }

    public int Points { get; set; } = 10;

    public TaskDifficulty Difficulty { get; set; } = TaskDifficulty.Easy;

    public DateTime? DueDate { get; set; }
    public bool IsCompleted { get; set; } = false;
    public DateTime? CompletedAt { get; set; }
    public bool IsVerified { get; set; } = false;

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    // Navigation properties
    public User AssignedBy { get; set; } = null!;
    public User AssignedTo { get; set; } = null!;
}

public enum TaskDifficulty
{
    Easy = 0,
    Medium = 1,
    Hard = 2,
    Epic = 3
}
