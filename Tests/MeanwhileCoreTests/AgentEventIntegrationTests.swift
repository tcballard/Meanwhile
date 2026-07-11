import Foundation
import XCTest
@testable import MeanwhileCore

final class AgentEventIntegrationTests: XCTestCase {
    func testHookEventsMapToHonestStatesAndPreserveEntryTime() throws {
        let start = Date(timeIntervalSince1970: 1_000)
        let thinking = try HookEventDecoder.decode(
            payload(event: "UserPromptSubmit"),
            provider: .claude,
            now: start,
            environment: ["TERM_PROGRAM": "Apple_Terminal", "TERM_SESSION_ID": "terminal-1"]
        )
        XCTAssertEqual(thinking.phase, .thinking)
        XCTAssertEqual(thinking.terminal.program, "Apple_Terminal")

        let same = try HookEventDecoder.decode(
            payload(event: "PreToolUse"),
            provider: .claude,
            now: start.addingTimeInterval(2),
            previous: thinking
        )
        XCTAssertEqual(same.enteredAt, start)

        let afterTool = try HookEventDecoder.decode(
            payload(event: "PostToolUse"),
            provider: .claude,
            now: start.addingTimeInterval(2.5),
            previous: same
        )
        XCTAssertEqual(afterTool.phase, .thinking)
        XCTAssertEqual(afterTool.enteredAt, start)

        let permission = try HookEventDecoder.decode(
            payload(event: "PermissionRequest"),
            provider: .claude,
            now: start.addingTimeInterval(3),
            previous: afterTool
        )
        XCTAssertEqual(permission.phase, .needsYou)
        XCTAssertEqual(permission.enteredAt, start.addingTimeInterval(3))

        let idle = try HookEventDecoder.decode(
            payload(event: "Stop"), provider: .claude,
            now: start.addingTimeInterval(4), previous: permission
        )
        XCTAssertEqual(idle.phase, .idle)
    }

    func testEventStoreRoundTripsAndRemovesStaleSessions() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AgentEventStore(directory: directory)
        let start = Date(timeIntervalSince1970: 2_000)
        let session = AgentSessionState(
            provider: .codex, sessionID: "unsafe/session+id", cwd: "/tmp",
            phase: .thinking, enteredAt: start, updatedAt: start
        )
        try store.write(session)
        XCTAssertEqual(store.session(provider: .codex, sessionID: session.sessionID), session)
        XCTAssertEqual(
            store.sessions(now: start.addingTimeInterval(3_601), staleAfter: 3_600),
            [session]
        )
        XCTAssertEqual(
            store.sessions(
                now: start.addingTimeInterval(86_401),
                staleAfter: 3_600,
                activeStaleAfter: 86_400
            ),
            []
        )
    }

    func testNotificationPermissionPromptMapsToNeedsYou() throws {
        let data = """
        {"session_id":"abc","cwd":"/tmp","hook_event_name":"Notification","notification_type":"permission_prompt"}
        """.data(using: .utf8)!
        XCTAssertEqual(
            try HookEventDecoder.decode(data, provider: .claude).phase,
            .needsYou
        )
    }

    private func payload(event: String) -> Data {
        """
        {"session_id":"abc","cwd":"/tmp/repo","hook_event_name":"\(event)"}
        """.data(using: .utf8)!
    }
}
