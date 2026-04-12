using System.ComponentModel.DataAnnotations;

namespace CoupleApp.Core.Entities;

/// <summary>
/// A word that can be drawn in the DrawGuess game.
/// </summary>
public class DrawWord
{
    public Guid Id { get; set; } = Guid.NewGuid();

    [Required, MaxLength(100)]
    public string Word { get; set; } = string.Empty;

    [MaxLength(50)]
    public string Category { get; set; } = "Genel";

    public DrawDifficulty Difficulty { get; set; } = DrawDifficulty.Easy;
}

public enum DrawDifficulty
{
    Easy   = 0,
    Medium = 1,
    Hard   = 2,
}
