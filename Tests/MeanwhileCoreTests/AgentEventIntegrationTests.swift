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
        XCTAssertEqual(permission.attentionReason, .approvalRequired)
        XCTAssertEqual(permission.enteredAt, start.addingTimeInterval(3))

        let repeatedPermission = try HookEventDecoder.decode(
            payload(event: "PermissionRequest"),
            provider: .claude,
            now: start.addingTimeInterval(3.5),
            previous: permission
        )
        XCTAssertEqual(repeatedPermission.enteredAt, permission.enteredAt)

        let idle = try HookEventDecoder.decode(
            payload(event: "Stop"), provider: .claude,
            now: start.addingTimeInterval(4), previous: repeatedPermission
        )
        XCTAssertEqual(idle.phase, .idle)
        XCTAssertNil(idle.attentionReason)
    }

    func testEventStoreRoundTripsAndRemovesStaleSessions() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AgentEventStore(directory: directory)
        let start = Date(timeIntervalSince1970: 2_000)
        let session = AgentSessionState(
            provider: .codex, sessionID: "unsafe/session+id", cwd: "/tmp",
            phase: .needsYou, attentionReason: .approvalRequired,
            enteredAt: start, updatedAt: start
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
        XCTAssertEqual(store.latestEvent(), session)
    }

    func testInspectsAndExplicitlyClearsOnlyStuckActiveSessions() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AgentEventStore(directory: directory)
        let now = Date(timeIntervalSince1970: 100_000)
        let fresh = AgentSessionState(
            provider: .claude,
            sessionID: "fresh",
            cwd: "/private/fresh",
            phase: .thinking,
            enteredAt: now.addingTimeInterval(-300),
            updatedAt: now.addingTimeInterval(-300)
        )
        let stuck = AgentSessionState(
            provider: .codex,
            sessionID: "stuck",
            cwd: "/private/stuck",
            phase: .needsYou,
            enteredAt: now.addingTimeInterval(-7_200),
            updatedAt: now.addingTimeInterval(-7_200)
        )
        try store.write(fresh)
        try store.write(stuck)

        XCTAssertEqual(
            store.inspectSessions(now: now, staleAfter: 3_600),
            AgentSessionInspection(
                activeCount: 2,
                stuckCount: 1,
                oldestStuckUpdate: stuck.updatedAt
            )
        )
        XCTAssertEqual(
            try store.clearStuckSessions(now: now, staleAfter: 3_600),
            1
        )
        XCTAssertEqual(
            store.inspectSessions(now: now, staleAfter: 3_600),
            AgentSessionInspection(
                activeCount: 1,
                stuckCount: 0,
                oldestStuckUpdate: nil
            )
        )
        XCTAssertEqual(
            store.session(provider: .claude, sessionID: fresh.sessionID),
            fresh
        )
        XCTAssertNil(store.session(provider: .codex, sessionID: stuck.sessionID))
        XCTAssertEqual(store.latestEvent(), stuck)
    }

    func testSupportedNotificationsMapToCoarseAttentionReasons() throws {
        let expectations: [(String, AgentAttentionReason)] = [
            ("permission_prompt", .approvalRequired),
            ("idle_prompt", .answerRequired),
            ("elicitation_dialog", .answerRequired)
        ]

        for (notificationType, reason) in expectations {
            let data = """
            {"session_id":"abc","cwd":"/tmp","hook_event_name":"Notification","notification_type":"\(notificationType)"}
            """.data(using: .utf8)!
            let state = try HookEventDecoder.decode(data, provider: .claude)
            XCTAssertEqual(state.phase, .needsYou)
            XCTAssertEqual(state.attentionReason, reason)
        }
    }

    func testChangedAttentionReasonResetsEntryTime() throws {
        let start = Date(timeIntervalSince1970: 4_000)
        let approval = try HookEventDecoder.decode(
            payload(event: "PermissionRequest"),
            provider: .claude,
            now: start
        )
        let answerData = """
        {"session_id":"abc","cwd":"/tmp/repo","hook_event_name":"Notification","notification_type":"elicitation_dialog"}
        """.data(using: .utf8)!
        let answer = try HookEventDecoder.decode(
            answerData,
            provider: .claude,
            now: start.addingTimeInterval(10),
            previous: approval
        )

        XCTAssertEqual(answer.attentionReason, .answerRequired)
        XCTAssertEqual(answer.enteredAt, start.addingTimeInterval(10))
    }

    func testLegacyAndUnknownStoredReasonsRemainVisible() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = AgentEventStore(directory: directory)
        let session = AgentSessionState(
            provider: .claude,
            sessionID: "legacy",
            cwd: "/tmp/repo",
            phase: .needsYou,
            attentionReason: .approvalRequired,
            enteredAt: Date(timeIntervalSince1970: 5_000),
            updatedAt: Date(timeIntervalSince1970: 5_000)
        )
        try store.write(session)

        try rewriteStoredSessions(in: directory) { object in
            object.removeValue(forKey: "attentionReason")
        }
        XCTAssertEqual(
            store.session(provider: .claude, sessionID: session.sessionID)?
                .effectiveAttentionReason,
            .generic
        )
        XCTAssertEqual(store.latestEvent()?.effectiveAttentionReason, .generic)

        try store.write(session)
        try rewriteStoredSessions(in: directory) { object in
            object["attentionReason"] = "future-reason"
        }
        XCTAssertEqual(
            store.session(provider: .claude, sessionID: session.sessionID)?
                .effectiveAttentionReason,
            .generic
        )
    }

    func testHookPayloadContentIsNeverPersistedInSessionState() throws {
        let sentinel = "DO-NOT-PERSIST-THIS"
        let data = """
        {
          "session_id":"abc",
          "cwd":"/tmp/repo",
          "hook_event_name":"PermissionRequest",
          "message":"\(sentinel)",
          "title":"\(sentinel)",
          "tool_input":{"command":"\(sentinel)"}
        }
        """.data(using: .utf8)!
        let state = try HookEventDecoder.decode(data, provider: .codex)
        let encoded = try JSONEncoder().encode(state)

        XCTAssertEqual(state.attentionReason, .approvalRequired)
        XCTAssertFalse(String(decoding: encoded, as: UTF8.self).contains(sentinel))
    }

    private func payload(event: String) -> Data {
        """
        {"session_id":"abc","cwd":"/tmp/repo","hook_event_name":"\(event)"}
        """.data(using: .utf8)!
    }

    private func rewriteStoredSessions(
        in directory: URL,
        mutate: (inout [String: Any]) -> Void
    ) throws {
        let urls = try FileManager.default.contentsOfDirectory(
            at: directory,
            includingPropertiesForKeys: nil
        ).filter { $0.pathExtension == "json" }
        for url in urls {
            var object = try XCTUnwrap(
                JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
            )
            mutate(&object)
            try JSONSerialization.data(withJSONObject: object).write(to: url, options: .atomic)
        }
    }
}
