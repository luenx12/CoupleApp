using System.ComponentModel.DataAnnotations;

namespace CoupleApp.Core.Entities;

/// <summary>
/// Represents one round of the DrawGuess game between two partners.
/// </summary>
public class DrawSession
{
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required]
    public Guid DrawerId { get; set; }

    [Required]
    public Guid GuesserId { get; set; }

    /// <summary>The word being drawn — never sent to the guesser.</summary>
    [Required, MaxLength(100)]
    public string Word { get; set; } = string.Empty;

    public DrawSessionStatus Status { get; set; } = DrawSessionStatus.WordSelection;

    public DateTime StartedAt { get; set; } = DateTime.UtcNow;

    /// <summary>Set when the guesser successfully guesses the word.</summary>
    public DateTime? GuessedAt { get; set; }

    /// <summary>Null until game ends.</summary>
    public Guid? WinnerUserId { get; set; }

    /// <summary>Score awarded to the winner (time-based).</summary>
    public int ScoreAwarded { get; set; } = 0;

    // Navigation
    public User Drawer  { get; set; } = null!;
    public User Guesser { get; set; } = null!;
}

public enum DrawSessionStatus
{
    WordSelection = 0,   // Drawer picking word
    Drawing       = 1,   // Active game
    Guessed       = 2,   // Guesser won
    TimeUp        = 3,   // Nobody won
    Abandoned     = 4,
}
