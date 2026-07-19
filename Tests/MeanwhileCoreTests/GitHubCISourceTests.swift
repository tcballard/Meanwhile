import Foundation
import XCTest
@testable import MeanwhileCore

final class GitHubCISourceTests: XCTestCase {
    func testUsesSingleReadOnlyViewerPullRequestQuery() {
        XCTAssertTrue(GitHubCISource.command.hasPrefix("gh api graphql"))
        XCTAssertTrue(GitHubCISource.command.contains("viewer"))
        XCTAssertTrue(GitHubCISource.command.contains("pullRequests"))
        XCTAssertTrue(GitHubCISource.command.contains("statusCheckRollup"))
        XCTAssertFalse(GitHubCISource.command.contains("mutation"))
    }

    func testDecodesOnlyFailingAndErrorRollupsOldestFirst() throws {
        let runner = CICommandRunner(result: ShellCommandResult(
            exitCode: 0,
            stdout: Self.fixture,
            stderr: ""
        ))
        let source = GitHubCISource(runner: runner)
        let items = try source.itemsIfDue(
            pollingAllowed: true,
            now: Date(timeIntervalSince1970: 1_000)
        )

        XCTAssertEqual(items.map(\.number), [1, 3])
        XCTAssertEqual(items.map(\.repository), ["acme/old", "acme/error"])
        XCTAssertEqual(runner.commands, [GitHubCISource.command])
    }

    func testDoesNotQueryUntilPollingIsAllowedAndCaches() throws {
        let runner = CICommandRunner(result: ShellCommandResult(
            exitCode: 0,
            stdout: Self.fixture,
            stderr: ""
        ))
        let source = GitHubCISource(runner: runner, cacheInterval: 60)
        let start = Date(timeIntervalSince1970: 2_000)

        XCTAssertEqual(try source.itemsIfDue(pollingAllowed: false, now: start), [])
        _ = try source.itemsIfDue(pollingAllowed: true, now: start)
        _ = try source.itemsIfDue(pollingAllowed: true, now: start.addingTimeInterval(59))
        XCTAssertEqual(runner.commands.count, 1)
        _ = try source.itemsIfDue(pollingAllowed: true, now: start.addingTimeInterval(60))
        XCTAssertEqual(runner.commands.count, 2)
    }

    func testForceBypassesCache() throws {
        let runner = CICommandRunner(result: ShellCommandResult(
            exitCode: 0,
            stdout: Self.fixture,
            stderr: ""
        ))
        let source = GitHubCISource(runner: runner, cacheInterval: 60)
        let start = Date(timeIntervalSince1970: 2_000)

        _ = try source.itemsIfDue(pollingAllowed: true, now: start)
        _ = try source.itemsIfDue(
            pollingAllowed: true,
            force: true,
            now: start.addingTimeInterval(1)
        )
        XCTAssertEqual(runner.commands.count, 2)
    }

    private static let fixture = """
    {
      "data": {"viewer": {"pullRequests": {"nodes": [
        {"repository":{"nameWithOwner":"acme/new"},"number":2,"title":"Green","url":"https://github.com/acme/new/pull/2","createdAt":"2026-01-02T00:00:00Z","commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"SUCCESS"}}}]}},
        {"repository":{"nameWithOwner":"acme/error"},"number":3,"title":"Error","url":"https://github.com/acme/error/pull/3","createdAt":"2026-01-03T00:00:00Z","commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"ERROR"}}}]}},
        {"repository":{"nameWithOwner":"acme/old"},"number":1,"title":"Red","url":"https://github.com/acme/old/pull/1","createdAt":"2026-01-01T00:00:00Z","commits":{"nodes":[{"commit":{"statusCheckRollup":{"state":"FAILURE"}}}]}}
      ]}}}
    }
    """
}

private final class CICommandRunner: CommandRunning, @unchecked Sendable {
    var commands: [String] = []
    let result: ShellCommandResult

    init(result: ShellCommandResult) { self.result = result }

    func run(_ command: String, timeoutSeconds: TimeInterval) throws -> ShellCommandResult {
        commands.append(command)
        return result
    }
}
