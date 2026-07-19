import Foundation

public struct ReviewItem: Equatable, Sendable {
    public var repository: String
    public var number: Int
    public var title: String
    public var url: URL
    public var createdAt: Date

    public init(
        repository: String,
        number: Int,
        title: String,
        url: URL,
        createdAt: Date
    ) {
        self.repository = repository
        self.number = number
        self.title = title
        self.url = url
        self.createdAt = createdAt
    }
}

public enum GitHubReviewSourceError: Error {
    case commandFailed(exitCode: Int32, stderr: String)
}

public final class GitHubReviewSource {
    public static let command = "gh search prs --review-requested=@me --state=open --sort=created --order=asc --limit=30 --json=repository,number,title,url,createdAt"

    private let runner: any CommandRunning
    private let cacheInterval: TimeInterval
    private let repositoryIsAllowed: @Sendable (String) -> Bool
    public private(set) var lastAttemptDate: Date?
    private var allCachedReviews: [ReviewItem] = []

    public var cachedReviews: [ReviewItem] {
        allCachedReviews.filter { repositoryIsAllowed($0.repository) }
    }

    public init(
        runner: any CommandRunning = PeripheralCommandRunner(),
        cacheInterval: TimeInterval = 60,
        repositoryIsAllowed: @escaping @Sendable (String) -> Bool = { _ in true }
    ) {
        self.runner = runner
        self.cacheInterval = cacheInterval
        self.repositoryIsAllowed = repositoryIsAllowed
    }

    public func isDue(now: Date = Date()) -> Bool {
        guard let lastAttemptDate else { return true }
        return now.timeIntervalSince(lastAttemptDate) >= cacheInterval
    }

    /// Returns cached data unless polling is allowed and the 60-second cache is due.
    @discardableResult
    public func reviewsIfDue(
        pollingAllowed: Bool,
        force: Bool = false,
        now: Date = Date()
    ) throws -> [ReviewItem] {
        guard pollingAllowed else { return cachedReviews }
        if !force, !isDue(now: now) {
            return cachedReviews
        }

        lastAttemptDate = now
        let result = try runner.run(Self.command, timeoutSeconds: 20)
        guard result.exitCode == 0 else {
            throw GitHubReviewSourceError.commandFailed(
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }

        allCachedReviews = try Self.decode(result.stdout)
            .sorted { $0.createdAt < $1.createdAt }
        return cachedReviews
    }

    static func decode(_ json: String) throws -> [ReviewItem] {
        struct SearchResult: Decodable {
            struct Repository: Decodable {
                var nameWithOwner: String
            }

            var repository: Repository
            var number: Int
            var title: String
            var url: URL
            var createdAt: Date
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode([SearchResult].self, from: Data(json.utf8)).map {
            ReviewItem(
                repository: $0.repository.nameWithOwner,
                number: $0.number,
                title: $0.title,
                url: $0.url,
                createdAt: $0.createdAt
            )
        }
    }
}
