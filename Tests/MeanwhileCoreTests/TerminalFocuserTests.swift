import Foundation
import XCTest
@testable import MeanwhileCore

final class TerminalFocuserTests: XCTestCase {
    @MainActor
    func testUsesOnlyRecordedAppleTerminalRoute() {
        var scripts: [String] = []
        let focuser = TerminalFocuser { script in
            scripts.append(script)
            return true
        }

        XCTAssertTrue(focuser.focus(session(program: "Apple_Terminal", tty: "/dev/ttys001")))
        XCTAssertEqual(scripts.count, 1)
        XCTAssertTrue(scripts[0].contains("tell application \"Terminal\""))
        XCTAssertFalse(scripts[0].contains("tell application \"iTerm2\""))
    }

    @MainActor
    func testUsesOnlyRecordedITermRoute() {
        var scripts: [String] = []
        let focuser = TerminalFocuser { script in
            scripts.append(script)
            return true
        }

        XCTAssertTrue(focuser.focus(session(program: "iTerm.app", tty: "/dev/ttys001")))
        XCTAssertEqual(scripts.count, 1)
        XCTAssertTrue(scripts[0].contains("tell application \"iTerm2\""))
        XCTAssertFalse(scripts[0].contains("tell application \"Terminal\""))
    }

    @MainActor
    func testUnknownMissingAndUnsupportedProgramsFailClosed() {
        var scriptCount = 0
        let focuser = TerminalFocuser { _ in
            scriptCount += 1
            return true
        }

        XCTAssertFalse(focuser.focus(session(program: nil, tty: "/dev/ttys001")))
        XCTAssertFalse(focuser.focus(session(program: "SecretTerminal", tty: "/dev/ttys001")))
        XCTAssertFalse(focuser.focus(session(program: "WarpTerminal", tty: "/dev/ttys001")))
        XCTAssertFalse(focuser.focus(session(program: "Apple_Terminal", tty: nil)))
        XCTAssertEqual(scriptCount, 0)
    }

    @MainActor
    func testStaleExactTTYReportsFailureWithoutAppOnlyActivation() {
        var scriptCount = 0
        let focuser = TerminalFocuser { _ in
            scriptCount += 1
            return false
        }

        XCTAssertFalse(focuser.focus(session(program: "Apple_Terminal", tty: "/dev/ttys999")))
        XCTAssertEqual(scriptCount, 1)
    }

    private func session(program: String?, tty: String?) -> AgentSessionState {
        AgentSessionState(
            provider: .claude,
            sessionID: "session-1",
            cwd: "/Users/example/Developer/Meanwhile",
            phase: .needsYou,
            enteredAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1),
            terminal: TerminalContext(program: program, tty: tty)
        )
    }
}
