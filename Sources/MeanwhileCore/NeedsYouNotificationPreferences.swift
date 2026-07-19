import Foundation

public enum NeedsYouNotificationDelay: Int, CaseIterable, Codable, Sendable {
    case oneMinute = 60
    case fiveMinutes = 300
    case fifteenMinutes = 900
    case thirtyMinutes = 1_800

    public var timeInterval: TimeInterval { TimeInterval(rawValue) }
}

public enum NeedsYouNotificationPermission: Equatable, Sendable {
    case unknown
    case notDetermined
    case authorized
    case denied
    case limited
    case unavailable
}

public struct NeedsYouNotificationSettings: Equatable, Sendable {
    public var isEnabled: Bool
    public var delay: NeedsYouNotificationDelay

    public init(
        isEnabled: Bool = false,
        delay: NeedsYouNotificationDelay = .oneMinute
    ) {
        self.isEnabled = isEnabled
        self.delay = delay
    }
}

public final class NeedsYouNotificationPreferences: @unchecked Sendable {
    private enum Key {
        static let enabled = "Meanwhile.notifications.needsYou.enabled"
        static let delay = "Meanwhile.notifications.needsYou.delaySeconds"
        static let receipts = "Meanwhile.notifications.needsYou.receipts"
    }

    private static let receiptLimit = 32

    private let defaults: UserDefaults
    private let lock = NSLock()
    private var state: NeedsYouNotificationSettings
    private var receiptIdentifiers: [String]

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let rawDelay = defaults.integer(forKey: Key.delay)
        state = NeedsYouNotificationSettings(
            isEnabled: defaults.bool(forKey: Key.enabled),
            delay: NeedsYouNotificationDelay(rawValue: rawDelay) ?? .oneMinute
        )
        receiptIdentifiers = Array(
            (defaults.stringArray(forKey: Key.receipts) ?? [])
                .suffix(Self.receiptLimit)
        )
    }

    public var settings: NeedsYouNotificationSettings {
        lock.lock()
        defer { lock.unlock() }
        return state
    }

    public func setEnabled(_ enabled: Bool) {
        update {
            $0.isEnabled = enabled
        }
    }

    public func setDelay(_ delay: NeedsYouNotificationDelay) {
        update {
            $0.delay = delay
        }
    }

    public func containsReceipt(identifier: String) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        return receiptIdentifiers.contains(identifier)
    }

    public func recordReceipt(identifier: String) {
        lock.lock()
        defer { lock.unlock() }
        receiptIdentifiers.removeAll { $0 == identifier }
        receiptIdentifiers.append(identifier)
        if receiptIdentifiers.count > Self.receiptLimit {
            receiptIdentifiers.removeFirst(receiptIdentifiers.count - Self.receiptLimit)
        }
        defaults.set(receiptIdentifiers, forKey: Key.receipts)
    }

    private func update(_ body: (inout NeedsYouNotificationSettings) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        body(&state)
        defaults.set(state.isEnabled, forKey: Key.enabled)
        defaults.set(state.delay.rawValue, forKey: Key.delay)
    }
}
