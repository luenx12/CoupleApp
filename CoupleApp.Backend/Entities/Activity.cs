using System.ComponentModel.DataAnnotations;

namespace CoupleApp.Backend.Entities;

public class Activity
{
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    public Guid CreatedByUserId { get; set; }

    [Required, MaxLength(200)]
    public string Title { get; set; } = string.Empty;

    [MaxLength(1000)]
    public string? Description { get; set; }

    public ActivityCategory Category { get; set; } = ActivityCategory.General;

    public DateTime? ScheduledAt { get; set; }
    public bool IsCompleted { get; set; } = false;
    public DateTime? CompletedAt { get; set; }

    public DateTime CreatedAt { get; set; } = DateTime.UtcNow;

    // Navigation properties
    public User CreatedBy { get; set; } = null!;
}

public enum ActivityCategory
{
    General = 0,
    Date = 1,
    Travel = 2,
    Movie = 3,
    Food = 4,
    Sport = 5,
    Anniversary = 6
}
