import Foundation

public final class AgentEventStore: @unchecked Sendable {
    public let directory: URL
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

    private func decode(url: URL) -> AgentSessionState? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? decoder.decode(AgentSessionState.self, from: data)
    }

    private func url(for session: AgentSessionState) -> URL {
        let raw = Data(session.sessionID.utf8).base64EncodedString()
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "=", with: "")
        return directory.appendingPathComponent("\(session.provider.rawValue)-\(raw).json")
    }
}
