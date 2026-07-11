import Foundation

public struct StatuslineSnapshot: Equatable, Codable, Sendable {
    public var text: String
    public var updatedAt: Date

    public init(text: String, updatedAt: Date = Date()) {
        self.text = text
        self.updatedAt = updatedAt
    }
}

public final class StatuslineSnapshotStore: @unchecked Sendable {
    public let fileURL: URL
    private let fileManager: FileManager
    private let lock = NSLock()
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    public init(fileURL: URL? = nil, fileManager: FileManager = .default) {
        self.fileManager = fileManager
        self.fileURL = fileURL ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Meanwhile/statusline.json")
        encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
    }

    public func write(_ snapshot: StatuslineSnapshot?) throws {
        lock.lock()
        defer { lock.unlock() }
        guard let snapshot else {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
            return
        }
        try fileManager.createDirectory(
            at: fileURL.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try encoder.encode(snapshot).write(to: fileURL, options: .atomic)
    }

    public func read() -> StatuslineSnapshot? {
        lock.lock()
        defer { lock.unlock() }
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? decoder.decode(StatuslineSnapshot.self, from: data)
    }
}
