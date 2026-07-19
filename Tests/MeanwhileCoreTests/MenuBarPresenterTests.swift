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
        XCTAssertEqual(MenuBarPresenter.statusText(item: item(.failingCI, title: "CI failed on #4")), "CI! #4")
        XCTAssertEqual(MenuBarPresenter.statusText(item: item(.review, title: "Review #78")), "#78")
    }

    func testReviewAndCIBloomNameTheSingleActionableItem() {
        XCTAssertEqual(
            MenuBarPresenter.bloomText(item: item(.review, title: "Review #78")),
            "Review #78 — repo"
        )
        XCTAssertEqual(
            MenuBarPresenter.bloomText(item: item(.failingCI, title: "CI failed on #42")),
            "CI failed #42 — repo"
        )
    }

    func testReviewAndCIActionsAreExplicitAndCompact() {
        let review = item(.review, title: "Review #78")
        let ci = item(.failingCI, title: "CI failed on #42")

        XCTAssertEqual(MenuBarPresenter.openActionTitle(item: review), "Open Review #78 — repo")
        XCTAssertEqual(MenuBarPresenter.openActionTitle(item: ci), "Inspect CI #42 — repo")
        XCTAssertLessThanOrEqual(MenuBarPresenter.openActionTitle(item: review).count, 30)
        XCTAssertLessThanOrEqual(MenuBarPresenter.openActionTitle(item: ci).count, 30)

        let longRepository = item(
            .review,
            title: "Review #78",
            detail: "acme/a-very-long-repository-name-with-a-readable-tail"
        )
        XCTAssertLessThanOrEqual(MenuBarPresenter.openActionTitle(item: longRepository).count, 30)
    }

    func testReviewAndCITooltipsExplainTheClickDestination() {
        XCTAssertEqual(
            MenuBarPresenter.tooltip(
                phase: .thinking,
                item: item(.review, title: "Review #78")
            ),
            "Review requested — acme/repo #78 — click to open"
        )
        XCTAssertEqual(
            MenuBarPresenter.tooltip(
                phase: .thinking,
                item: item(.failingCI, title: "CI failed on #42")
            ),
            "CI failed — acme/repo #42 — click to inspect checks"
        )
    }

    func testReviewAndCIAccessibilityNamesTheItemAndItsResult() {
        XCTAssertEqual(
            MenuBarPresenter.accessibilityLabel(
                phase: .thinking,
                item: item(.review, title: "Review #78")
            ),
            "Review requested for pull request 78 in acme/repo"
        )
        XCTAssertEqual(
            MenuBarPresenter.accessibilityHelp(
                phase: .thinking,
                item: item(.review, title: "Review #78")
            ),
            "Opens pull request 78 on GitHub."
        )
        XCTAssertEqual(
            MenuBarPresenter.accessibilityLabel(
                phase: .thinking,
                item: item(.failingCI, title: "CI failed on #42")
            ),
            "Continuous integration failed for pull request 42 in acme/repo"
        )
        XCTAssertEqual(
            MenuBarPresenter.accessibilityHelp(
                phase: .thinking,
                item: item(.failingCI, title: "CI failed on #42")
            ),
            "Opens the failed checks for pull request 42 on GitHub."
        )
    }

    func testReviewOpensPullRequestAndCIOpensThatPullRequestsChecks() throws {
        let pullRequestURL = try XCTUnwrap(URL(string: "https://github.com/acme/repo/pull/42"))
        let checksURL = pullRequestURL.appendingPathComponent("checks")
        let review = item(.review, title: "Review #42", url: pullRequestURL)
        let ci = item(.failingCI, title: "CI failed on #42", url: pullRequestURL)
        let ciAlreadyAtChecks = item(.failingCI, title: "CI failed on #42", url: checksURL)

        XCTAssertEqual(MenuBarPresenter.destinationURL(item: review), pullRequestURL)
        XCTAssertEqual(MenuBarPresenter.destinationURL(item: ci), checksURL)
        XCTAssertEqual(MenuBarPresenter.destinationURL(item: ciAlreadyAtChecks), checksURL)
        XCTAssertNil(MenuBarPresenter.destinationURL(item: item(.failingCI, title: "CI failed on #42")))
    }

    func testMalformedReviewAndCITitlesDoNotBecomeFakePullRequestNumbers() {
        let review = item(.review, title: "Review ready")
        let mixedReview = item(.review, title: "Review #12oops")
        let ci = item(.failingCI, title: "CI failed on #not-a-number")

        XCTAssertEqual(MenuBarPresenter.statusText(item: review), "Review")
        XCTAssertEqual(MenuBarPresenter.bloomText(item: review), "Review ready — repo")
        XCTAssertEqual(MenuBarPresenter.openActionTitle(item: review), "Open Review — repo")
        XCTAssertEqual(
            MenuBarPresenter.accessibilityLabel(phase: .thinking, item: review),
            "Review requested in acme/repo"
        )
        XCTAssertEqual(MenuBarPresenter.statusText(item: mixedReview), "Review")

        XCTAssertEqual(MenuBarPresenter.statusText(item: ci), "CI!")
        XCTAssertEqual(MenuBarPresenter.bloomText(item: ci), "CI failed — repo")
        XCTAssertEqual(MenuBarPresenter.openActionTitle(item: ci), "Inspect CI — repo")
        XCTAssertEqual(
            MenuBarPresenter.accessibilityHelp(phase: .thinking, item: ci),
            "Opens the failed checks on GitHub."
        )
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
            "Codex needs attention in “Meanwhile” — click to return"
        )
        XCTAssertEqual(
            MenuBarPresenter.accessibilityLabel(phase: .needsYou, item: item),
            "Codex needs attention in Meanwhile"
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
            "Claude needs attention — click to return"
        )
    }

    func testReasonAwareBloomExplainsWhyAndWhereThenKeepsStableTitleCompact() {
        let approval = item(
            .needsYou,
            title: "Codex needs you",
            session: session(
                provider: .codex,
                cwd: "/Users/example/Developer/Meanwhile",
                reason: .approvalRequired
            )
        )
        let answer = item(
            .needsYou,
            title: "Claude needs you",
            session: session(
                provider: .claude,
                cwd: "/Users/example/Developer/Meanwhile",
                reason: .answerRequired
            )
        )

        XCTAssertEqual(MenuBarPresenter.statusText(item: approval), "Codex needs you")
        XCTAssertEqual(
            MenuBarPresenter.bloomText(item: approval),
            "Codex needs approval — Meanwhile"
        )
        XCTAssertEqual(
            MenuBarPresenter.bloomText(item: answer),
            "Claude needs an answer — Meanwhile"
        )
        XCTAssertEqual(
            MenuBarPresenter.tooltip(phase: .needsYou, item: approval),
            "Codex needs approval in “Meanwhile” — click to return"
        )
        XCTAssertEqual(
            MenuBarPresenter.accessibilityLabel(phase: .needsYou, item: answer),
            "Claude needs an answer in Meanwhile"
        )
        XCTAssertEqual(
            MenuBarPresenter.statuslineText(item: approval),
            "Meanwhile: Codex needs approval"
        )
    }

    func testBloomBoundsLongProjectContextWithoutTruncatingReason() {
        let item = item(
            .needsYou,
            title: "Claude needs you",
            session: session(
                provider: .claude,
                cwd: "/tmp/very-long-project-name-that-needs-a-readable-tail",
                reason: .answerRequired
            )
        )

        let bloom = MenuBarPresenter.bloomText(item: item)
        XCTAssertEqual(bloom, "Claude needs an answer — very-long…dable-tail")
        XCTAssertLessThanOrEqual(bloom?.count ?? .max, 46)
    }

    func testReviewBloomBoundsLongUnicodeRepositoryWithoutLosingIdentity() throws {
        let item = item(
            .review,
            title: "Review #78",
            detail: "acme/Meanwhile-🚀-repository-with-a-very-readable-tail"
        )

        let bloom = try XCTUnwrap(MenuBarPresenter.bloomText(item: item))
        XCTAssertTrue(bloom.hasPrefix("Review #78 — "))
        XCTAssertLessThanOrEqual(bloom.count, 46)
    }

    func testNeedsYouNotificationTitlesStayReasonAwareAndReviewCIRemainSilent() {
        let approval = item(
            .needsYou,
            title: "Codex needs you",
            session: session(
                provider: .codex,
                cwd: "/tmp/Meanwhile",
                reason: .approvalRequired
            )
        )
        let answer = item(
            .needsYou,
            title: "Claude needs you",
            session: session(
                provider: .claude,
                cwd: "/tmp/Meanwhile",
                reason: .answerRequired
            )
        )

        XCTAssertEqual(MenuBarPresenter.notificationTitle(item: approval), "Codex still needs approval")
        XCTAssertEqual(MenuBarPresenter.notificationTitle(item: answer), "Claude still needs an answer")
        XCTAssertNil(MenuBarPresenter.notificationTitle(item: item(.review, title: "Review #78")))
        XCTAssertNil(MenuBarPresenter.notificationTitle(item: item(.failingCI, title: "CI failed on #42")))
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
        detail: String = "acme/repo",
        url: URL? = nil,
        session: AgentSessionState? = nil
    ) -> WorkItem {
        WorkItem(
            id: UUID().uuidString,
            kind: kind,
            title: title,
            detail: detail,
            url: url,
            createdAt: Date(timeIntervalSince1970: 1),
            session: session
        )
    }

    private func session(
        provider: AgentProvider,
        cwd: String,
        reason: AgentAttentionReason? = nil
    ) -> AgentSessionState {
        AgentSessionState(
            provider: provider,
            sessionID: "019f5ee8-576e-74b3-8e9a-2b6e2404970b",
            cwd: cwd,
            phase: .needsYou,
            attentionReason: reason,
            enteredAt: Date(timeIntervalSince1970: 1),
            updatedAt: Date(timeIntervalSince1970: 1)
        )
    }
}
