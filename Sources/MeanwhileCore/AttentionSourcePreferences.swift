import Foundation

public struct AttentionSourceSelection: Equatable, Sendable {
    public var reviewsEnabled: Bool
    public var failingCIEnabled: Bool

    public init(reviewsEnabled: Bool = true, failingCIEnabled: Bool = true) {
        self.reviewsEnabled = reviewsEnabled
        self.failingCIEnabled = failingCIEnabled
    }

    public func isEnabled(_ source: GitHubSourceKind) -> Bool {
        switch source {
        case .reviews: return reviewsEnabled
        case .failingCI: return failingCIEnabled
        }
    }
}

public final class AttentionSourcePreferences: @unchecked Sendable {
    private enum Key {
        static let reviews = "Meanwhile.sources.reviews.enabled"
        static let failingCI = "Meanwhile.sources.failingCI.enabled"
    }

    private let lock = NSLock()
    private let defaults: UserDefaults
    private var state: AttentionSourceSelection

    public init(
        defaults: UserDefaults = .standard,
        defaultSelection: AttentionSourceSelection = AttentionSourceSelection()
    ) {
        self.defaults = defaults
        state = AttentionSourceSelection(
            reviewsEnabled: defaults.object(forKey: Key.reviews) == nil
                ? defaultSelection.reviewsEnabled
                : defaults.bool(forKey: Key.reviews),
            failingCIEnabled: defaults.object(forKey: Key.failingCI) == nil
                ? defaultSelection.failingCIEnabled
                : defaults.bool(forKey: Key.failingCI)
        )
    }

    public var selection: AttentionSourceSelection {
        lock.lock()
        defer { lock.unlock() }
        return state
    }

    public func setReviewsEnabled(_ enabled: Bool) {
        update { $0.reviewsEnabled = enabled }
    }

    public func setFailingCIEnabled(_ enabled: Bool) {
        update { $0.failingCIEnabled = enabled }
    }

    private func update(_ body: (inout AttentionSourceSelection) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        body(&state)
        defaults.set(state.reviewsEnabled, forKey: Key.reviews)
        defaults.set(state.failingCIEnabled, forKey: Key.failingCI)
    }
}
