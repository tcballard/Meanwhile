import Foundation

public struct AgentSessionInspection: Equatable, Sendable {
    public var activeCount: Int
    public var stuckCount: Int
    public var oldestStuckUpdate: Date?

    public init(
        activeCount: Int,
        stuckCount: Int,
        oldestStuckUpdate: Date?
    ) {
        self.activeCount = activeCount
        self.stuckCount = stuckCount
        self.oldestStuckUpdate = oldestStuckUpdate
    }

    public static let empty = AgentSessionInspection(
        activeCount: 0,
        stuckCount: 0,
        oldestStuckUpdate: nil
    )
}

public final class AgentEventStore: @unchecked Sendable {
    public let directory: URL
    public let latestEventURL: URL
    private let fileManager: FileManager
    private let lock = NSLock()
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(
        directory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.fileManager = fileManager
        self.directory = directory ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Meanwhile/Sessions", isDirectory: true)
        latestEventURL = self.directory
            .appendingPathComponent(".latest-agent-event.json")
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public func write(_ session: AgentSessionState) throws {
        lock.lock()
        defer { lock.unlock() }
        try fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        let data = try encoder.encode(session)
        try data.write(to: url(for: session), options: .atomic)
        try data.write(to: latestEventURL, options: .atomic)
    }

    public func session(provider: AgentProvider, sessionID: String) -> AgentSessionState? {
        lock.lock()
        defer { lock.unlock() }
        let prototype = AgentSessionState(
            provider: provider,
            sessionID: sessionID,
            cwd: "/",
            phase: .idle,
            enteredAt: .distantPast,
            updatedAt: .distantPast
        )
        return decode(url: url(for: prototype))
    }

    public func latestEvent() -> AgentSessionState? {
        lock.lock()
        defer { lock.unlock() }
        return decode(url: latestEventURL)
    }

    public func sessions(
        now: Date = Date(),
        staleAfter: TimeInterval = 3_600,
        activeStaleAfter: TimeInterval = 86_400
    ) -> [AgentSessionState] {
        lock.lock()
        defer { lock.unlock() }
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }

        var current: [AgentSessionState] = []
        for url in urls where url.pathExtension == "json" {
            guard let session = decode(url: url) else { continue }
            let expiry = session.phase == .idle ? staleAfter : activeStaleAfter
            if now.timeIntervalSince(session.updatedAt) > expiry {
                try? fileManager.removeItem(at: url)
            } else {
                current.append(session)
            }
        }
        return current.sorted { $0.id < $1.id }
    }

    public func inspectSessions(
        now: Date = Date(),
        staleAfter: TimeInterval = 3_600
    ) -> AgentSessionInspection {
        lock.lock()
        defer { lock.unlock() }
        let active = sessionFiles()
            .compactMap(decode(url:))
            .filter { $0.phase != .idle }
        let stuck = active.filter {
            now.timeIntervalSince($0.updatedAt) > staleAfter
        }
        return AgentSessionInspection(
            activeCount: active.count,
            stuckCount: stuck.count,
            oldestStuckUpdate: stuck.map(\.updatedAt).min()
        )
    }

    @discardableResult
    public func clearStuckSessions(
        now: Date = Date(),
        staleAfter: TimeInterval = 3_600
    ) throws -> Int {
        lock.lock()
        defer { lock.unlock() }
        var removed = 0
        for url in sessionFiles() {
            guard let session = decode(url: url),
                  session.phase != .idle,
                  now.timeIntervalSince(session.updatedAt) > staleAfter else {
                continue
            }
            try fileManager.removeItem(at: url)
            removed += 1
        }
        return removed
    }

    private func decode(url: URL) -> AgentSessionState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(AgentSessionState.self, from: data)
    }

    private func sessionFiles() -> [URL] {
        guard let urls = try? fileManager.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return [] }
        return urls.filter { $0.pathExtension == "json" }
    }

    private func url(for session: AgentSessionState) -> URL {
        let raw = Data(session.sessionID.utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        return directory.appendingPathComponent("\(session.provider.rawValue)-\(raw).json")
    }
}
