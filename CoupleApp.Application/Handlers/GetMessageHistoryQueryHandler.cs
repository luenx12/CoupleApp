using CoupleApp.Application.Common;
using CoupleApp.Application.DTOs;
using CoupleApp.Application.Queries;
using CoupleApp.Core.Interfaces.Repositories;
using MediatR;

namespace CoupleApp.Application.Handlers;

/// <summary>
/// Handles GetMessageHistoryQuery: returns paginated conversation history.
/// Resolves the correct ciphertext (sender vs receiver copy) per requesting user.
/// </summary>
public sealed class GetMessageHistoryQueryHandler
    : IRequestHandler<GetMessageHistoryQuery, PagedResult<MessageHistoryDto>>
{
    private readonly IMessageRepository _messages;

    public GetMessageHistoryQueryHandler(IMessageRepository messages)
        => _messages = messages;

    public async Task<PagedResult<MessageHistoryDto>> Handle(
        GetMessageHistoryQuery request,
        CancellationToken cancellationToken)
    {
        var (items, totalCount) = await _messages.GetHistoryAsync(
            request.UserId,
            request.PartnerId,
            request.Page,
            request.PageSize);

        var dtos = items.Select(m => new MessageHistoryDto(
            Id:           m.Id,
            SenderId:     m.SenderId,
            ReceiverId:   m.ReceiverId,
            // Zero-Leak: return sender's own encrypted copy when they read history
            EncryptedText: m.SenderId == request.UserId
                           ? (m.EncryptedTextForSender ?? m.EncryptedText)
                           : m.EncryptedText,
            IV:           m.IV,
            Type:         m.Type,
            MediaId:      m.MediaId,
            IsDelivered:  m.IsDelivered,
            IsRead:       m.IsRead,
            SentAt:       m.SentAt,
            DeliveredAt:  m.DeliveredAt,
            ReadAt:       m.ReadAt));

        return PagedResult<MessageHistoryDto>.Create(dtos, totalCount, request.Page, request.PageSize);
    }
}
