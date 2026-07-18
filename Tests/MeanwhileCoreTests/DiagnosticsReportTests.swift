import Foundation
import XCTest
@testable import MeanwhileCore

final class DiagnosticsReportTests: XCTestCase {
    func testReportIsUsefulButOmitsPrivateContext() {
        let generatedAt = Date(timeIntervalSince1970: 1_700_000_000)
        let eventDate = generatedAt.addingTimeInterval(-120)
        let signalDate = generatedAt.addingTimeInterval(-60)
        let privateRepository = "private-owner/secret-repository"
        let privatePath = "/Users/tom/Clients/Secret"
        let privateSessionID = "session-super-secret"
        let snapshot = DiagnosticsSnapshot(
            appVersion: "0.1.2",
            buildVersion: "3",
            operatingSystemVersion: "macOS 15.5 (24F74)",
            launchAtLoginStatus: .requiresApproval,
            updateState: .updateAvailable(
                version: "v0.1.3",
                releaseURL: URL(string: "https://example.com/private-release-url")!
            ),
            integrationHealth: AgentIntegrationHealth(
                state: .needsReview,
                claudeHooksInstalled: true,
                codexHooksInstalled: false,
                claudeStatuslineConflict: true
            ),
            githubAuthenticationStatus: .authenticated,
            repositoryScopeIncludesAll: false,
            accessibleRepositoryCount: 68,
            selectedRepositoryCount: 3,
            hotKeyConfigured: true,
            sessionInspection: AgentSessionInspection(
                activeCount: 2,
                stuckCount: 1,
                oldestStuckUpdate: eventDate
            ),
            lastAgentEvent: AgentSessionState(
                provider: .codex,
                sessionID: privateSessionID,
                cwd: privatePath,
                phase: .needsYou,
                enteredAt: eventDate,
                updatedAt: eventDate,
                terminal: TerminalContext(
                    program: "SecretTerminal",
                    sessionID: "private-terminal-id",
                    tty: "/dev/private-tty"
                )
            ),
            recentSignals: [
                RecentSignal(
                    kind: .ciFailed,
                    title: "Secret CI title",
                    detail: privateRepository,
                    date: signalDate
                )
            ]
        )

        let report = MeanwhileDiagnosticsReport.make(
            snapshot: snapshot,
            generatedAt: generatedAt
        )

        XCTAssertTrue(report.contains("App: 0.1.2 (3)"))
        XCTAssertTrue(report.contains("Schema: 1"))
        XCTAssertTrue(report.contains("Launch at login: needs approval"))
        XCTAssertTrue(report.contains("Update: available (v0.1.3)"))
        XCTAssertTrue(report.contains("Repository scope: selected only (3)"))
        XCTAssertTrue(report.contains("Sessions that may be stuck: 1"))
        XCTAssertTrue(report.contains("Last agent event: codex, needs-you"))
        XCTAssertTrue(report.contains("Recent ciFailed: 1"))

        for privateValue in [
            privateRepository,
            privatePath,
            privateSessionID,
            "SecretTerminal",
            "private-terminal-id",
            "/dev/private-tty",
            "Secret CI title",
            "private-release-url"
        ] {
            XCTAssertFalse(report.contains(privateValue))
        }
    }
}
