import Foundation

public enum RecentSignalKind: String, Codable, Sendable {
    case agentNeedsYou
    case reviewSurfaced
    case ciFailed
    case snoozed
    case hiddenUntilChange
    case integrationsInstalled
}

public struct RecentSignal: Codable, Equatable, Identifiable, Sendable {
    public var id: UUID
    public var kind: RecentSignalKind
    public var title: String
    public var detail: String
    public var date: Date

    public init(
        id: UUID = UUID(),
        kind: RecentSignalKind,
        title: String,
        detail: String,
        date: Date = Date()
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.date = date
    }
}

public final class RecentSignalStore: @unchecked Sendable {
    private let defaults: UserDefaults
    private let key: String
    private let limit: Int
    private let lock = NSLock()
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    public init(
        defaults: UserDefaults = .standard,
        key: String = "Meanwhile.recentSignals",
        limit: Int = 8
    ) {
        self.defaults = defaults
        self.key = key
        self.limit = max(1, limit)
    }

    public var signals: [RecentSignal] {
        lock.lock()
        defer { lock.unlock() }
        return load()
    }

    public func record(_ signal: RecentSignal) {
        lock.lock()
        defer { lock.unlock() }
        var current = load()
        if let latest = current.first,
           latest.kind == signal.kind,
           latest.title == signal.title,
           latest.detail == signal.detail,
           signal.date.timeIntervalSince(latest.date) < 60 {
            return
        }
        current.insert(signal, at: 0)
        if current.count > limit {
            current.removeLast(current.count - limit)
        }
        guard let data = try? encoder.encode(current) else { return }
        defaults.set(data, forKey: key)
    }

    private func load() -> [RecentSignal] {
        guard let data = defaults.data(forKey: key),
              let values = try? decoder.decode([RecentSignal].self, from: data) else {
            return []
        }
        return values.sorted { $0.date > $1.date }
    }
}
