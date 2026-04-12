namespace CoupleApp.Application.DTOs;

public sealed record RegisterDto(string Username, string Password, string? PublicKey);
public sealed record LoginDto(string Username, string Password);
public sealed record UserDto(Guid Id, string Username, string? PublicKey);
