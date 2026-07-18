import Foundation
import XCTest
@testable import MeanwhileCore

final class ReleaseUpdateCheckerTests: XCTestCase {
    func testReportsNewerRelease() throws {
        let checker = ReleaseUpdateChecker(
            runner: StubRunner(stdout: payload(tag: "v0.1.3"))
        )

        XCTAssertEqual(
            try checker.check(currentVersion: "0.1.2"),
            .updateAvailable(
                version: "v0.1.3",
                releaseURL: URL(string: "https://github.com/tcballard/Meanwhile/releases/tag/v0.1.3")!
            )
        )
    }

    func testReportsCurrentAndDevelopmentBuilds() throws {
        let checker = ReleaseUpdateChecker(
            runner: StubRunner(stdout: payload(tag: "v0.1.2"))
        )
        XCTAssertEqual(
            try checker.check(currentVersion: "0.1.2"),
            .current(
                latestVersion: "v0.1.2",
                releaseURL: URL(string: "https://github.com/tcballard/Meanwhile/releases/tag/v0.1.2")!
            )
        )

        let developmentChecker = ReleaseUpdateChecker(
            runner: StubRunner(stdout: payload(tag: "v0.1.1"))
        )
        XCTAssertEqual(
            try developmentChecker.check(currentVersion: "0.1.2"),
            .developmentBuild(
                latestVersion: "v0.1.1",
                releaseURL: URL(string: "https://github.com/tcballard/Meanwhile/releases/tag/v0.1.1")!
            )
        )
    }

    func testSemanticVersionComparisonIsNumeric() throws {
        XCTAssertLessThan(
            try XCTUnwrap(SemanticVersion("v0.1.9")),
            try XCTUnwrap(SemanticVersion("0.1.10"))
        )
        XCTAssertEqual(
            SemanticVersion("1.2"),
            SemanticVersion("v1.2.0")
        )
        XCTAssertNil(SemanticVersion("release-next"))
    }

    func testReturnsPurposefulErrorsWithoutCommandOutput() {
        let failed = ReleaseUpdateChecker(
            runner: StubRunner(
                exitCode: 1,
                stdout: "",
                stderr: "token secret and private path"
            )
        )
        XCTAssertThrowsError(try failed.check(currentVersion: "0.1.2")) {
            XCTAssertEqual($0 as? ReleaseUpdateCheckerError, .commandFailed)
            XCTAssertFalse($0.localizedDescription.contains("token secret"))
        }

        let malformed = ReleaseUpdateChecker(
            runner: StubRunner(stdout: "not json")
        )
        XCTAssertThrowsError(try malformed.check(currentVersion: "0.1.2")) {
            XCTAssertEqual($0 as? ReleaseUpdateCheckerError, .invalidResponse)
        }

        let untrustedURL = ReleaseUpdateChecker(
            runner: StubRunner(
                stdout: #"{"tagName":"v0.1.3","url":"https://example.com/fake"}"#
            )
        )
        XCTAssertThrowsError(try untrustedURL.check(currentVersion: "0.1.2")) {
            XCTAssertEqual($0 as? ReleaseUpdateCheckerError, .invalidResponse)
        }
    }

    private func payload(tag: String) -> String {
        """
        {"tagName":"\(tag)","url":"https://github.com/tcballard/Meanwhile/releases/tag/\(tag)"}
        """
    }
}

private struct StubRunner: CommandRunning {
    var result: ShellCommandResult

    init(
        exitCode: Int32 = 0,
        stdout: String,
        stderr: String = ""
    ) {
        result = ShellCommandResult(
            exitCode: exitCode,
            stdout: stdout,
            stderr: stderr
        )
    }

    func run(
        _ command: String,
        timeoutSeconds: TimeInterval
    ) throws -> ShellCommandResult {
        XCTAssertEqual(command, ReleaseUpdateChecker.command)
        XCTAssertEqual(timeoutSeconds, 15)
        return result
    }
}
