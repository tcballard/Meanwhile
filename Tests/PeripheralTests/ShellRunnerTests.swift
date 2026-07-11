import XCTest
@testable import Peripheral

final class ShellRunnerTests: XCTestCase {
    func testCapturesExitCodeAndBothStreams() throws {
        let result = try ShellRunner.run(
            "echo out; echo err >&2; exit 7",
            timeoutSeconds: 2
        )

        XCTAssertEqual(result.exitCode, 7)
        XCTAssertEqual(result.stdout, "out\n")
        XCTAssertEqual(result.stderr, "err\n")
    }

    func testTimeoutReturns124WithoutWaitingForCommand() throws {
        let started = Date()
        let result = try ShellRunner.run("sleep 2", timeoutSeconds: 0.05)

        XCTAssertEqual(result.exitCode, 124)
        XCTAssertLessThan(Date().timeIntervalSince(started), 1.5)
    }

    func testPrependsCommonPackageManagerPaths() throws {
        let result = try ShellRunner.run("printf %s \"$PATH\"", timeoutSeconds: 2)

        XCTAssertTrue(result.stdout.hasPrefix("/opt/homebrew/bin:/usr/local/bin:"))
    }
}
