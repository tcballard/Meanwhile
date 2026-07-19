import Foundation
import XCTest
@testable import MeanwhileCore

final class GitHubReviewSourceTests: XCTestCase {
    func testDoesNotInvokeGitHubUntilPollingIsAllowed() throws {
        let runner = RecordingCommandRunner(results: [successfulResult])
        let source = GitHubReviewSource(runner: runner)

        XCTAssertEqual(
            try source.reviewsIfDue(
                pollingAllowed: false,
                now: Date(timeIntervalSince1970: 1_000)
            ),
            []
        )
        XCTAssertEqual(runner.commands, [])
    }

    func testFetchesOldestReviewAndCachesForSixtySeconds() throws {
        let runner = RecordingCommandRunner(results: [successfulResult, successfulResult])
        let source = GitHubReviewSource(runner: runner)
        let start = Date(timeIntervalSince1970: 1_000)

        let first = try source.reviewsIfDue(pollingAllowed: true, now: start)
        let cached = try source.reviewsIfDue(
            pollingAllowed: true,
            now: start.addingTimeInterval(59)
        )

        XCTAssertEqual(first.first?.repository, "acme/older")
        XCTAssertEqual(first.first?.number, 7)
        XCTAssertEqual(cached, first)
        XCTAssertEqual(runner.commands, [GitHubReviewSource.command])

        _ = try source.reviewsIfDue(
            pollingAllowed: true,
            now: start.addingTimeInterval(60)
        )
        XCTAssertEqual(runner.commands.count, 2)
    }

    func testCommandMatchesVerifiedGitHubCLIFlagsAndFields() {
        XCTAssertEqual(
            GitHubReviewSource.command,
            "gh search prs --review-requested=@me --state=open --sort=created --order=asc --limit=30 --json=repository,number,title,url,createdAt"
        )
    }

    func testForceBypassesCacheWithoutBypassingPollingGate() throws {
        let runner = RecordingCommandRunner(results: [successfulResult, successfulResult])
        let source = GitHubReviewSource(runner: runner)
        let start = Date(timeIntervalSince1970: 1_000)

        _ = try source.reviewsIfDue(pollingAllowed: true, now: start)
        _ = try source.reviewsIfDue(
            pollingAllowed: true,
            force: true,
            now: start.addingTimeInterval(1)
        )
        _ = try source.reviewsIfDue(
            pollingAllowed: false,
            force: true,
            now: start.addingTimeInterval(2)
        )
        XCTAssertEqual(runner.commands.count, 2)
    }

    func testFiltersCachedReviewsUsingRepositoryPreferences() throws {
        let preferences = RepositoryPreferences(
            defaults: UserDefaults(suiteName: UUID().uuidString)!
        )
        preferences.setIncludesAllRepositories(false)
        preferences.setRepository("acme/newer", isSelected: true)
        let runner = RecordingCommandRunner(results: [successfulResult])
        let source = GitHubReviewSource(
            runner: runner,
            repositoryIsAllowed: { repository in
                preferences.allows(repository: repository)
            }
        )

        let filtered = try source.reviewsIfDue(pollingAllowed: true)
        XCTAssertEqual(filtered.map(\.repository), ["acme/newer"])

        preferences.setRepository("acme/newer", isSelected: false)
        preferences.setRepository("acme/older", isSelected: true)
        XCTAssertEqual(source.cachedReviews.map(\.repository), ["acme/older"])
    }

    private var successfulResult: ShellCommandResult {
        ShellCommandResult(
            exitCode: 0,
            stdout: """
            [
              {
                "repository": {"nameWithOwner": "acme/newer"},
                "number": 9,
                "title": "Newer item",
                "url": "https://github.com/acme/newer/pull/9",
                "createdAt": "2026-07-02T12:00:00Z"
              },
              {
                "repository": {"nameWithOwner": "acme/older"},
                "number": 7,
                "title": "Older item",
                "url": "https://github.com/acme/older/pull/7",
                "createdAt": "2026-07-01T12:00:00Z"
              }
            ]
            """,
            stderr: ""
        )
    }
}

private final class RecordingCommandRunner: CommandRunning, @unchecked Sendable {
    private let lock = NSLock()
    private var results: [ShellCommandResult]
    private var recordedCommands: [String] = []

    var commands: [String] {
        lock.lock()
        defer { lock.unlock() }
        return recordedCommands
    }

    init(results: [ShellCommandResult]) {
        self.results = results
    }

    func run(_ command: String, timeoutSeconds: TimeInterval) throws -> ShellCommandResult {
        lock.lock()
        defer { lock.unlock() }
        recordedCommands.append(command)
        return results.removeFirst()
    }
}
