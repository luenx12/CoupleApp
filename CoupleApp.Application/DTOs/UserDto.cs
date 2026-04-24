namespace CoupleApp.Application.DTOs;

public sealed record RegisterDto(string Username, string Password, string? PublicKey);
public sealed record LoginDto(string Username, string Password);

/// <summary>
/// Partner bilgisi — Gender: 0=Belirtilmemiş, 1=Kadın, 2=Erkek
/// </summary>
public sealed record UserDto(Guid Id, string Username, string? PublicKey, int Gender = 0);
