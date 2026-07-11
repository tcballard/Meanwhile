import Foundation

public final class ItemDispositionStore: @unchecked Sendable {
    private enum Key {
        static let snoozed = "Meanwhile.items.snoozedUntil"
        static let dismissed = "Meanwhile.items.dismissed"
    }

    private let defaults: UserDefaults
    private let lock = NSLock()
    private var snoozedUntil: [String: TimeInterval]
    private var dismissed: Set<String>

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        snoozedUntil = defaults.dictionary(forKey: Key.snoozed) as? [String: TimeInterval] ?? [:]
        dismissed = Set(defaults.stringArray(forKey: Key.dismissed) ?? [])
    }

    public func snooze(itemID: String, until: Date, now: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }
        dismissed.remove(itemID)
        if until > now {
            snoozedUntil[itemID] = until.timeIntervalSince1970
        } else {
            snoozedUntil.removeValue(forKey: itemID)
        }
        persist()
    }

    public func dismiss(itemID: String) {
        lock.lock()
        defer { lock.unlock() }
        snoozedUntil.removeValue(forKey: itemID)
        dismissed.insert(itemID)
        persist()
    }

    public func isAvailable(itemID: String, now: Date = Date()) -> Bool {
        lock.lock()
        defer { lock.unlock() }
        pruneExpired(now: now)
        return !dismissed.contains(itemID) && snoozedUntil[itemID] == nil
    }

    public func reconcile(activeItemIDs: Set<String>, now: Date = Date()) {
        lock.lock()
        defer { lock.unlock() }
        dismissed.formIntersection(activeItemIDs)
        pruneExpired(now: now)
        persist()
    }

    private func pruneExpired(now: Date) {
        let timestamp = now.timeIntervalSince1970
        snoozedUntil = snoozedUntil.filter { $0.value > timestamp }
    }

    private func persist() {
        defaults.set(snoozedUntil, forKey: Key.snoozed)
        defaults.set(dismissed.sorted(), forKey: Key.dismissed)
    }
}
