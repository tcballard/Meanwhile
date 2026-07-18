import Foundation
import XCTest
@testable import MeanwhileCore

final class MenuBarPresenterTests: XCTestCase {
    func testUsesDistinctIconsForEachAgentPhase() {
        XCTAssertEqual(MenuBarPresenter.iconName(phase: .idle), "rectangle.stack")
        XCTAssertEqual(MenuBarPresenter.iconName(phase: .thinking), "rectangle.stack.fill")
        XCTAssertEqual(MenuBarPresenter.iconName(phase: .needsYou), "exclamationmark.bubble.fill")
    }

    func testFormatsEachItemKindCompactly() {
        XCTAssertNil(MenuBarPresenter.statusText(item: nil))
        XCTAssertEqual(
            MenuBarPresenter.statusText(item: item(.needsYou, title: "Claude needs you")),
            "Claude needs you"
        )
        XCTAssertEqual(
            MenuBarPresenter.statusText(item: item(.needsYou, title: "Codex needs you")),
            "Codex needs you"
        )
        XCTAssertEqual(MenuBarPresenter.statusText(item: item(.failingCI, title: "CI failed on #4")), "CI!")
        XCTAssertEqual(MenuBarPresenter.statusText(item: item(.review, title: "Review #78")), "#78")
    }

    func testNeedsYouCopyAddsProjectContextOutsideTheStatusTitle() {
        let item = item(
            .needsYou,
            title: "Codex needs you",
            session: session(provider: .codex, cwd: "/Users/example/Developer/Meanwhile")
        )

        XCTAssertEqual(MenuBarPresenter.statusText(item: item), "Codex needs you")
        XCTAssertEqual(MenuBarPresenter.projectName(item: item), "Meanwhile")
        XCTAssertEqual(
            MenuBarPresenter.openActionTitle(item: item),
            "Return to Codex — Meanwhile"
        )
        XCTAssertEqual(
            MenuBarPresenter.tooltip(phase: .needsYou, item: item),
            "Codex needs you in “Meanwhile” — click to return"
        )
        XCTAssertEqual(
            MenuBarPresenter.accessibilityLabel(phase: .needsYou, item: item),
            "Codex needs you in the Meanwhile project"
        )
        XCTAssertEqual(
            MenuBarPresenter.accessibilityHelp(phase: .needsYou, item: item),
            "Returns to the waiting Codex task."
        )
    }

    func testNeedsYouCopyFallsBackCleanlyWithoutAProject() {
        let item = item(
            .needsYou,
            title: "Claude needs you",
            session: session(provider: .claude, cwd: "/")
        )

        XCTAssertNil(MenuBarPresenter.projectName(item: item))
        XCTAssertEqual(MenuBarPresenter.openActionTitle(item: item), "Return to Claude")
        XCTAssertEqual(
            MenuBarPresenter.tooltip(phase: .needsYou, item: item),
            "Claude needs you — click to return"
        )
    }

    func testAccessibilityNamesVisibleReviewAndCIItemsWhileAgentIsThinking() {
        XCTAssertEqual(
            MenuBarPresenter.accessibilityLabel(
                phase: .thinking,
                item: item(.review, title: "Review #78")
            ),
            "Review #78, acme/repo"
        )
        XCTAssertEqual(
            MenuBarPresenter.accessibilityLabel(
                phase: .thinking,
                item: item(.failingCI, title: "CI failed on #4")
            ),
            "CI failed on #4, acme/repo"
        )
    }

    func testProjectNameRejectsPrivateOrUnhelpfulContexts() {
        let rejected = [
            "/",
            FileManager.default.homeDirectoryForCurrentUser.path,
            "/tmp/.",
            "/tmp/..",
            "/tmp/bad\nname"
        ]

        for cwd in rejected {
            let item = item(
                .needsYou,
                title: "Codex needs you",
                session: session(provider: .codex, cwd: cwd)
            )
            XCTAssertNil(MenuBarPresenter.projectName(item: item), cwd)
        }
    }

    func testProjectNameMiddleTruncatesLongBasename() throws {
        let item = item(
            .needsYou,
            title: "Codex needs you",
            session: session(
                provider: .codex,
                cwd: "/tmp/very-long-project-name-that-needs-a-readable-tail"
            )
        )

        let project = try XCTUnwrap(MenuBarPresenter.projectName(item: item))
        XCTAssertEqual(project, "very-long-proje…-a-readable-tail")
    }

    private func item(
        _ kind: WorkItemKind,
        title: String,
        session: AgentSessionState? = nil
    ) -> WorkItem {
        WorkItem(
            id: UUID().uuidString,
            kind: kind,
            title: title,
            detail: "acme/repo",
            createdAt: Date(timeIntervalSince1970: 1),
            session: session
        )
    }

    private func session(provider: AgentProvider, cwd: String) -> AgentSessionState {
        AgentSessionState(
            provider: provider,
            sessionID: "019f5ee8-576e-74b3-8e9a-2b6e2404970b",
            cwd: cwd,
            phase: .needsYou,
            enteredAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1)
        )
    }
}
