import Foundation
import OSLog

public enum Config {
    private static let logger = Logger(subsystem: "Peripheral", category: "Config")

    /// Loads `~/.config/peripheral/<app>.json`, returning defaults when absent or invalid.
    public static func load<Value: Decodable>(
        app: String,
        defaults: @autoclosure () -> Value,
        directory: URL? = nil,
        fileManager: FileManager = .default,
        decoder: JSONDecoder = JSONDecoder()
    ) -> Value {
        let fallback = defaults()
        let baseDirectory = directory ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent(".config/peripheral", isDirectory: true)
        let url = baseDirectory.appendingPathComponent("\(app).json")

        guard fileManager.fileExists(atPath: url.path) else {
            return fallback
        }

        do {
            return try decoder.decode(Value.self, from: Data(contentsOf: url))
        } catch {
            logger.error("Could not load config at \(url.path, privacy: .public): \(error.localizedDescription, privacy: .public)")
            return fallback
        }
    }
}
