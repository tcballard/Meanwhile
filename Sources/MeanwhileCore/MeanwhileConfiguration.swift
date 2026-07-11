import Foundation
import Peripheral

public struct MeanwhileConfiguration: Codable, Equatable, Sendable {
    public var snoozeSeconds: TimeInterval
    public var sessionStaleSeconds: TimeInterval
    public var activeSessionStaleSeconds: TimeInterval
    public var enableReviews: Bool
    public var enableFailingCI: Bool

    public init(
        snoozeSeconds: TimeInterval = 900,
        sessionStaleSeconds: TimeInterval = 3_600,
        activeSessionStaleSeconds: TimeInterval = 86_400,
        enableReviews: Bool = true,
        enableFailingCI: Bool = true
    ) {
        self.snoozeSeconds = Self.valid(snoozeSeconds, fallback: 900)
        self.sessionStaleSeconds = Self.valid(sessionStaleSeconds, fallback: 3_600)
        self.activeSessionStaleSeconds = Self.valid(activeSessionStaleSeconds, fallback: 86_400)
        self.enableReviews = enableReviews
        self.enableFailingCI = enableFailingCI
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.init(
            snoozeSeconds: try values.decodeIfPresent(TimeInterval.self, forKey: .snoozeSeconds) ?? 900,
            sessionStaleSeconds: try values.decodeIfPresent(TimeInterval.self, forKey: .sessionStaleSeconds) ?? 3_600,
            activeSessionStaleSeconds: try values.decodeIfPresent(TimeInterval.self, forKey: .activeSessionStaleSeconds) ?? 86_400,
            enableReviews: try values.decodeIfPresent(Bool.self, forKey: .enableReviews) ?? true,
            enableFailingCI: try values.decodeIfPresent(Bool.self, forKey: .enableFailingCI) ?? true
        )
    }

    public static func load(directory: URL? = nil) -> MeanwhileConfiguration {
        Config.load(app: "meanwhile", defaults: MeanwhileConfiguration(), directory: directory)
    }

    private static func valid(_ value: TimeInterval, fallback: TimeInterval) -> TimeInterval {
        value.isFinite && value > 0 ? value : fallback
    }
}
