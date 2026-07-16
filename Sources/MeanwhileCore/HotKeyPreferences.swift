import Foundation

public final class HotKeyPreferences: @unchecked Sendable {
    private enum Key {
        static let configured = "Meanwhile.hotKey.configured"
        static let key = "Meanwhile.hotKey.key"
        static let modifiers = "Meanwhile.hotKey.modifiers"
    }

    private let lock = NSLock()
    private let defaults: UserDefaults
    private let defaultHotKey: HotKeyConfiguration?

    public init(
        defaults: UserDefaults = .standard,
        defaultHotKey: HotKeyConfiguration? = nil
    ) {
        self.defaults = defaults
        self.defaultHotKey = defaultHotKey
    }

    public var hotKey: HotKeyConfiguration? {
        lock.lock()
        defer { lock.unlock() }

        guard defaults.object(forKey: Key.configured) != nil else {
            return defaultHotKey
        }

        guard defaults.bool(forKey: Key.configured),
              let key = defaults.string(forKey: Key.key) else {
            return nil
        }

        let modifiers = (defaults.stringArray(forKey: Key.modifiers) ?? [])
            .compactMap(HotKeyModifier.init(rawValue:))
        return HotKeyConfiguration(key: key, modifiers: modifiers).normalized
    }

    public func setHotKey(_ hotKey: HotKeyConfiguration?) {
        lock.lock()
        defer { lock.unlock() }

        guard let hotKey = hotKey?.normalized else {
            defaults.set(false, forKey: Key.configured)
            defaults.removeObject(forKey: Key.key)
            defaults.removeObject(forKey: Key.modifiers)
            return
        }

        defaults.set(true, forKey: Key.configured)
        defaults.set(hotKey.key, forKey: Key.key)
        defaults.set(hotKey.modifiers.map(\.rawValue), forKey: Key.modifiers)
    }
}
