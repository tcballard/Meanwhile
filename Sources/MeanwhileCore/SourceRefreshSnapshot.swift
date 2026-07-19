import Foundation

public enum GitHubSourceKind: String, CaseIterable, Sendable {
    case reviews
    case failingCI
}

public struct SourceRefreshRecord: Equatable, Sendable {
    public var isEnabled: Bool
    public var isRefreshing: Bool
    public var lastAttemptAt: Date?
    public var lastSuccessAt: Date?
    public var lastFailureAt: Date?

    public init(
        isEnabled: Bool,
        isRefreshing: Bool = false,
        lastAttemptAt: Date? = nil,
        lastSuccessAt: Date? = nil,
        lastFailureAt: Date? = nil
    ) {
        self.isEnabled = isEnabled
        self.isRefreshing = isRefreshing
        self.lastAttemptAt = lastAttemptAt
        self.lastSuccessAt = lastSuccessAt
        self.lastFailureAt = lastFailureAt
    }

    public mutating func begin(at date: Date) {
        guard isEnabled else { return }
        isRefreshing = true
        lastAttemptAt = date
    }

    public mutating func succeed(at date: Date) {
        guard isEnabled else { return }
        isRefreshing = false
        lastSuccessAt = date
        lastFailureAt = nil
    }

    public mutating func fail(at date: Date) {
        guard isEnabled else { return }
        isRefreshing = false
        lastFailureAt = date
    }
}

public struct SourceRefreshSnapshot: Equatable, Sendable {
    public var reviews: SourceRefreshRecord
    public var failingCI: SourceRefreshRecord

    public init(reviewsEnabled: Bool, failingCIEnabled: Bool) {
        reviews = SourceRefreshRecord(isEnabled: reviewsEnabled)
        failingCI = SourceRefreshRecord(isEnabled: failingCIEnabled)
    }

    public subscript(_ source: GitHubSourceKind) -> SourceRefreshRecord {
        get {
            switch source {
            case .reviews: return reviews
            case .failingCI: return failingCI
            }
        }
        set {
            switch source {
            case .reviews: reviews = newValue
            case .failingCI: failingCI = newValue
            }
        }
    }

    public var isRefreshing: Bool {
        reviews.isRefreshing || failingCI.isRefreshing
    }
}
