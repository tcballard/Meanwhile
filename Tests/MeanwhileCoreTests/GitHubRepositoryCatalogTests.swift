import Foundation
import XCTest
@testable import MeanwhileCore

final class GitHubRepositoryCatalogTests: XCTestCase {
    func testUsesReadOnlyPaginatedGitHubAPIQuery() {
        XCTAssertEqual(
            GitHubRepositoryCatalog.command,
            "gh api --method GET /user/repos --raw-field affiliation=owner,collaborator,organization_member --raw-field per_page=100 --paginate --jq '.[].full_name'"
        )
    }

    func testParsesSortsAndDeduplicatesRepositories() throws {
        let runner = CatalogCommandRunner(
            result: ShellCommandResult(
                exitCode: 0,
                stdout: "zeta/tools\nAcme/widgets\nzeta/tools\n",
                stderr: ""
            )
        )
        let catalog = GitHubRepositoryCatalog(runner: runner)

        XCTAssertEqual(
            try catalog.repositories(),
            ["Acme/widgets", "zeta/tools"]
        )
    }

    func testAuthenticationCheckerReflectsGitHubCLIExitStatus() {
        XCTAssertEqual(
            GitHubAuthenticationChecker(
                runner: CatalogCommandRunner(
                    result: ShellCommandResult(exitCode: 0, stdout: "", stderr: "")
                )
            ).status(),
            .authenticated
        )
        XCTAssertEqual(
            GitHubAuthenticationChecker(
                runner: CatalogCommandRunner(
                    result: ShellCommandResult(exitCode: 1, stdout: "", stderr: "login required")
                )
            ).status(),
            .notAuthenticated
        )
    }
}

private struct CatalogCommandRunner: CommandRunning {
    var result: ShellCommandResult

    func run(_ command: String, timeoutSeconds: TimeInterval) throws -> ShellCommandResult {
        result
    }
}
