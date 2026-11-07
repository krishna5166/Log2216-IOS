import Foundation

/// Least-recently-used bookkeeping for small on-phone caches.
public enum Lru {
    /// Moves `key` to the newest end of `order` and returns the keys that no longer fit in `limit`, oldest first.
    public static func touch(_ order: [String], key: String, limit: Int) -> (order: [String], evicted: [String]) {
        var next = order.filter { $0 != key }
        next.append(key)
        let over = max(0, next.count - max(limit, 1))
        return (Array(next.dropFirst(over)), Array(next.prefix(over)))
    }
}
