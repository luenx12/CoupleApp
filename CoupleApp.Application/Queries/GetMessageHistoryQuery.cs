using CoupleApp.Application.Common;
using CoupleApp.Application.DTOs;
using MediatR;

namespace CoupleApp.Application.Queries;

/// <summary>
/// Retrieves paginated conversation history between two users.
/// The handler resolves the correct ciphertext copy per user.
/// </summary>
public sealed record GetMessageHistoryQuery(
    Guid UserId,
    Guid PartnerId,
    int Page = 1,
    int PageSize = 50
) : IRequest<PagedResult<MessageHistoryDto>>;
