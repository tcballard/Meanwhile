import Foundation
import XCTest
@testable import MeanwhileCore

final class MeanwhileEngineTests: XCTestCase {
    func testOrdinaryItemsAppearImmediatelyWhileThinking() {
        let context = makeEngine()
        defer { context.cleanup() }
        let start = Date(timeIntervalSince1970: 1_000)
        let session = makeSession(phase: .thinking, enteredAt: start)
        let review = makeReview(number: 8, createdAt: start.addingTimeInterval(-100))

        let presentation = context.engine.presentation(
            sessions: [session], reviews: [review], failingCI: [],
            now: start
        )
        XCTAssertEqual(presentation.phase, .thinking)
        XCTAssertTrue(presentation.waitGateIsOpen)
        XCTAssertEqual(presentation.item?.kind, .review)
    }

    func testIdleAlwaysHidesOrdinaryItems() {
        let context = makeEngine()
        defer { context.cleanup() }
        let now = Date(timeIntervalSince1970: 2_000)
        let presentation = context.engine.presentation(
            sessions: [makeSession(phase: .idle, enteredAt: now.addingTimeInterval(-100))],
            reviews: [makeReview(number: 1, createdAt: now.addingTimeInterval(-100))],
            failingCI: [makeCI(number: 2, createdAt: now.addingTimeInterval(-100))],
            now: now
        )
        XCTAssertEqual(presentation.phase, .idle)
        XCTAssertNil(presentation.item)
    }

    func testNeedsYouBypassesDebounceAndPreemptsCIAndReviews() {
        let context = makeEngine()
        defer { context.cleanup() }
        let now = Date(timeIntervalSince1970: 3_000)
        let presentation = context.engine.presentation(
            sessions: [
                makeSession(phase: .thinking, enteredAt: now.addingTimeInterval(-30), id: "thinking"),
                makeSession(phase: .needsYou, enteredAt: now.addingTimeInterval(-1), id: "permission")
            ],
            reviews: [makeReview(number: 1, createdAt: now.addingTimeInterval(-300))],
            failingCI: [makeCI(number: 2, createdAt: now.addingTimeInterval(-200))],
            now: now
        )
        XCTAssertEqual(presentation.phase, .needsYou)
        XCTAssertEqual(presentation.item?.kind, .needsYou)
    }

    func testPriorityIsCIThenReviewAndOldestWithinKind() {
        let context = makeEngine()
        defer { context.cleanup() }
        let now = Date(timeIntervalSince1970: 4_000)
        let presentation = context.engine.presentation(
            sessions: [makeSession(phase: .thinking, enteredAt: now.addingTimeInterval(-30))],
            reviews: [makeReview(number: 1, createdAt: now.addingTimeInterval(-500))],
            failingCI: [
                makeCI(number: 3, createdAt: now.addingTimeInterval(-100)),
                makeCI(number: 2, createdAt: now.addingTimeInterval(-200))
            ],
            now: now
        )
        XCTAssertEqual(presentation.item?.id, "ci:acme/repo#2")
    }

    func testSnoozeMovesToNextDeterministicItem() {
        let context = makeEngine()
        defer { context.cleanup() }
        let now = Date(timeIntervalSince1970: 5_000)
        let session = makeSession(phase: .thinking, enteredAt: now.addingTimeInterval(-30))
        let ci = makeCI(number: 2, createdAt: now.addingTimeInterval(-200))
        let review = makeReview(number: 1, createdAt: now.addingTimeInterval(-500))
        let first = context.engine.presentation(
            sessions: [session], reviews: [review], failingCI: [ci], now: now
        )
        context.engine.snooze(try! XCTUnwrap(first.item), now: now)
        let second = context.engine.presentation(
            sessions: [session], reviews: [review], failingCI: [ci], now: now
        )
        XCTAssertEqual(second.item?.kind, .review)
    }

    private func makeEngine() -> (engine: MeanwhileEngine, cleanup: () -> Void) {
        let suite = "MeanwhileEngineTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        return (
            MeanwhileEngine(dispositions: ItemDispositionStore(defaults: defaults)),
            { defaults.removePersistentDomain(forName: suite) }
        )
    }

    private func makeSession(
        phase: AgentPhase,
        enteredAt: Date,
        id: String = "session"
    ) -> AgentSessionState {
        AgentSessionState(
            provider: .claude,
            sessionID: id,
            cwd: "/tmp/repo",
            phase: phase,
            enteredAt: enteredAt,
            updatedAt: enteredAt
        )
    }

    private func makeReview(number: Int, createdAt: Date) -> ReviewItem {
        ReviewItem(
            repository: "acme/repo", number: number, title: "Review",
            url: URL(string: "https://example.com/review/\(number)")!, createdAt: createdAt
        )
    }

    private func makeCI(number: Int, createdAt: Date) -> FailingCIItem {
        FailingCIItem(
            repository: "acme/repo", number: number, title: "CI",
            url: URL(string: "https://example.com/ci/\(number)")!, createdAt: createdAt
        )
    }
}
