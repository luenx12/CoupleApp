namespace CoupleApp.Backend.Services;

/// <summary>
/// Manages in-memory mapping between UserId ↔ SignalR ConnectionId.
/// Thread-safe with ConcurrentDictionary. Zero-Leak: no data persisted.
/// </summary>
public interface IConnectionManager
{
    void AddConnection(Guid userId, string connectionId);
    void RemoveConnection(Guid userId, string connectionId);
    IReadOnlyList<string> GetConnections(Guid userId);
    bool IsOnline(Guid userId);
}
