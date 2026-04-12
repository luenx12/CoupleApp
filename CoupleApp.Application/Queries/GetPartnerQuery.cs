using CoupleApp.Application.DTOs;
using MediatR;

namespace CoupleApp.Application.Queries;

/// <summary>
/// Retrieves the partner from the CouplePair table.
/// Returns null if not paired.
/// </summary>
public record GetPartnerQuery(Guid UserId) : IRequest<UserDto?>;
