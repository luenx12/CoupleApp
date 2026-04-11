using System.Collections.Concurrent;

namespace CoupleApp.Backend.Services;

/// <summary>
/// Thread-safe, in-memory UserId → [ConnectionId] map.
/// One user may have multiple connections (e.g., two devices).
/// </summary>
public sealed class ConnectionManager : IConnectionManager
{
    // UserId → set of active connection IDs
    private readonly ConcurrentDictionary<Guid, HashSet<string>> _connections = new();
    private readonly object _lock = new();

    public void AddConnection(Guid userId, string connectionId)
    {
        lock (_lock)
        {
            if (!_connections.TryGetValue(userId, out var set))
            {
                set = [];
                _connections[userId] = set;
            }
            set.Add(connectionId);
        }
    }

    public void RemoveConnection(Guid userId, string connectionId)
    {
        lock (_lock)
        {
            if (_connections.TryGetValue(userId, out var set))
            {
                set.Remove(connectionId);
                if (set.Count == 0)
                    _connections.TryRemove(userId, out _);
            }
        }
    }

    public IReadOnlyList<string> GetConnections(Guid userId)
    {
        lock (_lock)
        {
            return _connections.TryGetValue(userId, out var set)
                ? set.ToList()
                : [];
        }
    }

    public bool IsOnline(Guid userId) =>
        _connections.TryGetValue(userId, out var set) && set.Count > 0;
}
