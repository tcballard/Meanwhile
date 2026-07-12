import Foundation

public struct FailingCIItem: Equatable, Sendable {
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

public enum GitHubCISourceError: Error {
    case commandFailed(exitCode: Int32, stderr: String)
}

public final class GitHubCISource {
    public static let command = "gh api graphql -f query='query { viewer { pullRequests(first: 50, states: OPEN, orderBy: {field: CREATED_AT, direction: ASC}) { nodes { repository { nameWithOwner } number title url createdAt commits(last: 1) { nodes { commit { statusCheckRollup { state } } } } } } } }'"

    private let runner: any CommandRunning
    private let cacheInterval: TimeInterval
    private let repositoryIsAllowed: @Sendable (String) -> Bool
    private var lastAttemptDate: Date?
    private var allCachedItems: [FailingCIItem] = []

    public var cachedItems: [FailingCIItem] {
        allCachedItems.filter { repositoryIsAllowed($0.repository) }
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

    @discardableResult
    public func itemsIfDue(
        pollingAllowed: Bool,
        now: Date = Date()
    ) throws -> [FailingCIItem] {
        guard pollingAllowed else { return cachedItems }
        if let lastAttemptDate,
           now.timeIntervalSince(lastAttemptDate) < cacheInterval {
            return cachedItems
        }

        lastAttemptDate = now
        let result = try runner.run(Self.command, timeoutSeconds: 20)
        guard result.exitCode == 0 else {
            throw GitHubCISourceError.commandFailed(
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }

        allCachedItems = try Self.decode(result.stdout)
            .sorted { $0.createdAt < $1.createdAt }
        return cachedItems
    }

    static func decode(_ json: String) throws -> [FailingCIItem] {
        struct Response: Decodable {
            struct DataPayload: Decodable {
                struct Viewer: Decodable {
                    struct PullRequests: Decodable {
                        struct PullRequest: Decodable {
                            struct Repository: Decodable { var nameWithOwner: String }
                            struct Commits: Decodable {
                                struct Node: Decodable {
                                    struct Commit: Decodable {
                                        struct Rollup: Decodable { var state: String }
                                        var statusCheckRollup: Rollup?
                                    }
                                    var commit: Commit
                                }
                                var nodes: [Node]
                            }

                            var repository: Repository
                            var number: Int
                            var title: String
                            var url: URL
                            var createdAt: Date
                            var commits: Commits
                        }
                        var nodes: [PullRequest]
                    }
                    var pullRequests: PullRequests
                }
                var viewer: Viewer
            }
            var data: DataPayload
        }

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let response = try decoder.decode(Response.self, from: Data(json.utf8))
        return response.data.viewer.pullRequests.nodes.compactMap { pullRequest in
            let state = pullRequest.commits.nodes.last?
                .commit.statusCheckRollup?.state.uppercased()
            guard state == "FAILURE" || state == "ERROR" else { return nil }
            return FailingCIItem(
                repository: pullRequest.repository.nameWithOwner,
                number: pullRequest.number,
                title: pullRequest.title,
                url: pullRequest.url,
                createdAt: pullRequest.createdAt
            )
        }
    }
}
