using CoupleApp.Application.DTOs;
using CoupleApp.Core.Entities;
using MediatR;

namespace CoupleApp.Application.Commands;

/// <summary>
/// Persists an E2EE message to DB. Business logic sits in the handler.
/// </summary>
public sealed record SendMessageCommand(
    Guid SenderId,
    Guid ReceiverId,
    string EncryptedText,
    string? EncryptedTextForSender,
    string? IV,
    MessageType Type = MessageType.Text,
    string? MediaId = null
) : IRequest<SendMessageResponse>;
