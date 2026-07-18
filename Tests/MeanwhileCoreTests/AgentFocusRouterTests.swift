import Foundation
import XCTest
@testable import MeanwhileCore

final class AgentFocusRouterTests: XCTestCase {
    func testBuildsExactCodexThreadURLForUUIDSession() {
        let session = makeSession(
            provider: .codex,
            sessionID: "019f5ee8-576e-74b3-8e9a-2b6e2404970b"
        )

        XCTAssertEqual(
            AgentFocusRouter.codexThreadURL(for: session)?.absoluteString,
            "codex://threads/019f5ee8-576e-74b3-8e9a-2b6e2404970b"
        )
    }

    func testRejectsUnvalidatedFocusURLs() {
        XCTAssertNil(
            AgentFocusRouter.codexThreadURL(
                for: makeSession(provider: .codex, sessionID: "not-a-uuid")
            )
        )
        XCTAssertNil(
            AgentFocusRouter.codexThreadURL(
                for: makeSession(
                    provider: .claude,
                    sessionID: "019f5ee8-576e-74b3-8e9a-2b6e2404970b"
                )
            )
        )
    }

    @MainActor
    func testAcceptedCodexURLDoesNotInvokeTerminalFallback() {
        var openedURL: URL?
        var terminalFocusCount = 0
        let router = AgentFocusRouter(
            openURL: { url in
                openedURL = url
                return true
            },
            focusTerminal: { _ in
                terminalFocusCount += 1
                return true
            }
        )

        XCTAssertEqual(
            router.focus(makeSession(provider: .codex, sessionID: validSessionID)),
            .codexTask
        )
        XCTAssertEqual(
            openedURL?.absoluteString,
            "codex://threads/\(validSessionID)"
        )
        XCTAssertEqual(terminalFocusCount, 0)
    }

    @MainActor
    func testRejectedCodexURLFallsBackToTerminalOnce() {
        var terminalFocusCount = 0
        let router = AgentFocusRouter(
            openURL: { _ in false },
            focusTerminal: { _ in
                terminalFocusCount += 1
                return true
            }
        )

        XCTAssertEqual(
            router.focus(makeSession(provider: .codex, sessionID: validSessionID)),
            .terminalFallback
        )
        XCTAssertEqual(terminalFocusCount, 1)
    }

    @MainActor
    func testInvalidCodexIDSkipsURLAndFallsBackToTerminal() {
        var openURLCount = 0
        let router = AgentFocusRouter(
            openURL: { _ in
                openURLCount += 1
                return true
            },
            focusTerminal: { _ in true }
        )

        XCTAssertEqual(
            router.focus(makeSession(provider: .codex, sessionID: "not-a-uuid")),
            .terminalFallback
        )
        XCTAssertEqual(openURLCount, 0)
    }

    @MainActor
    func testClaudeNeverAttemptsCodexURL() {
        var openURLCount = 0
        let router = AgentFocusRouter(
            openURL: { _ in
                openURLCount += 1
                return true
            },
            focusTerminal: { _ in true }
        )

        XCTAssertEqual(
            router.focus(makeSession(provider: .claude, sessionID: validSessionID)),
            .terminalFallback
        )
        XCTAssertEqual(openURLCount, 0)
    }

    @MainActor
    func testReportsUnavailableWhenEveryRouteFails() {
        let router = AgentFocusRouter(
            openURL: { _ in false },
            focusTerminal: { _ in false }
        )

        XCTAssertEqual(
            router.focus(makeSession(provider: .codex, sessionID: validSessionID)),
            .unavailable
        )
    }

    private let validSessionID = "019f5ee8-576e-74b3-8e9a-2b6e2404970b"

    private func makeSession(
        provider: AgentProvider,
        sessionID: String
    ) -> AgentSessionState {
        AgentSessionState(
            provider: provider,
            sessionID: sessionID,
            cwd: "/Users/example/Developer/Meanwhile",
            phase: .needsYou,
            enteredAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1)
        )
    }
}
