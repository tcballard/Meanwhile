import Foundation
import XCTest
@testable import MeanwhileCore

final class StatusItemBloomStateTests: XCTestCase {
    func testInitialWaitingPresentationSeedsWithoutReplayingBloom() {
        var state = StatusItemBloomState()

        XCTAssertEqual(state.observe(phase: .needsYou, item: item("A")), .none)
        XCTAssertFalse(state.isActive)
    }

    func testInitialReviewOrCIPresentationSeedsWithoutReplayingBloom() {
        var reviewState = StatusItemBloomState()
        XCTAssertEqual(reviewState.observe(phase: .thinking, item: review("R")), .none)
        XCTAssertFalse(reviewState.isActive)

        var ciState = StatusItemBloomState()
        XCTAssertEqual(ciState.observe(phase: .thinking, item: failingCI("C")), .none)
        XCTAssertFalse(ciState.isActive)
    }

    func testNewWaitingItemStartsOnceAndExpiryDoesNotRestartOnPolling() {
        var state = StatusItemBloomState()
        XCTAssertEqual(state.observe(phase: .idle, item: nil), .none)

        let transition = state.observe(phase: .needsYou, item: item("A"))
        guard case .start(let itemID, let generation) = transition else {
            return XCTFail("Expected a bloom start")
        }
        XCTAssertTrue(state.isActive)
        XCTAssertEqual(state.observe(phase: .needsYou, item: item("A")), .none)
        XCTAssertTrue(state.expire(itemID: itemID, generation: generation))
        XCTAssertFalse(state.isActive)
        XCTAssertEqual(state.observe(phase: .needsYou, item: item("A")), .none)
        XCTAssertFalse(state.isActive)
    }

    func testDifferentWaitingItemRestartsAndStaleExpiryCannotSettleIt() {
        var state = StatusItemBloomState()
        _ = state.observe(phase: .idle, item: nil)
        let first = state.observe(phase: .needsYou, item: item("A"))
        let second = state.observe(phase: .needsYou, item: item("B"))
        guard case .start(let firstID, let firstGeneration) = first,
              case .start(let secondID, let secondGeneration) = second else {
            return XCTFail("Expected two bloom starts")
        }

        XCTAssertNotEqual(firstGeneration, secondGeneration)
        XCTAssertFalse(state.expire(itemID: firstID, generation: firstGeneration))
        XCTAssertTrue(state.isActive)
        XCTAssertTrue(state.expire(itemID: secondID, generation: secondGeneration))
    }

    func testNewReviewStartsOnceAndDoesNotReplayAfterExpiry() {
        var state = StatusItemBloomState()
        XCTAssertEqual(state.observe(phase: .idle, item: nil), .none)

        let transition = state.observe(phase: .thinking, item: review("R"))
        guard case .start(let itemID, let generation) = transition else {
            return XCTFail("Expected a review bloom start")
        }
        XCTAssertEqual(itemID, "R")
        XCTAssertEqual(state.observe(phase: .thinking, item: review("R")), .none)
        XCTAssertTrue(state.expire(itemID: itemID, generation: generation))
        XCTAssertEqual(state.observe(phase: .thinking, item: review("R")), .none)
        XCTAssertFalse(state.isActive)
    }

    func testReviewToCIRestartsAndStaleExpiryCannotSettleReplacement() {
        var state = StatusItemBloomState()
        _ = state.observe(phase: .idle, item: nil)
        let first = state.observe(phase: .thinking, item: review("R"))
        let second = state.observe(phase: .thinking, item: failingCI("C"))
        guard case .start(let firstID, let firstGeneration) = first,
              case .start(let secondID, let secondGeneration) = second else {
            return XCTFail("Expected review and CI bloom starts")
        }

        XCTAssertEqual(firstID, "R")
        XCTAssertEqual(secondID, "C")
        XCTAssertNotEqual(firstGeneration, secondGeneration)
        XCTAssertFalse(state.expire(itemID: firstID, generation: firstGeneration))
        XCTAssertTrue(state.isActive)
        XCTAssertTrue(state.expire(itemID: secondID, generation: secondGeneration))
    }

    func testMoreSpecificReasonForSameItemStartsAReplacementBloom() {
        var state = StatusItemBloomState()
        _ = state.observe(phase: .idle, item: nil)
        XCTAssertStart(
            state.observe(
                phase: .needsYou,
                item: item("A", reason: .generic)
            )
        )
        XCTAssertStart(
            state.observe(
                phase: .needsYou,
                item: item("A", reason: .approvalRequired)
            )
        )
    }

    func testReplacingNeedsYouWithReviewStartsTheReviewBloom() {
        var state = StatusItemBloomState()
        _ = state.observe(phase: .idle, item: nil)
        XCTAssertStart(state.observe(phase: .needsYou, item: item("A")))
        XCTAssertStart(state.observe(phase: .thinking, item: review("R")))
        XCTAssertTrue(state.isActive)
        XCTAssertStart(state.observe(phase: .needsYou, item: item("A")))
    }

    func testRemovingReviewOrCISelectionCancelsTheActiveBloom() {
        var reviewState = StatusItemBloomState()
        _ = reviewState.observe(phase: .idle, item: nil)
        XCTAssertStart(reviewState.observe(phase: .thinking, item: review("R")))
        XCTAssertEqual(reviewState.observe(phase: .thinking, item: nil), .cancel)
        XCTAssertFalse(reviewState.isActive)

        var ciState = StatusItemBloomState()
        _ = ciState.observe(phase: .idle, item: nil)
        XCTAssertStart(ciState.observe(phase: .thinking, item: failingCI("C")))
        XCTAssertEqual(ciState.observe(phase: .idle, item: nil), .cancel)
        XCTAssertFalse(ciState.isActive)
    }

    func testReviewAndCIRequireThinkingPhase() {
        var state = StatusItemBloomState()
        _ = state.observe(phase: .idle, item: nil)

        XCTAssertEqual(state.observe(phase: .needsYou, item: review("R")), .none)
        XCTAssertStart(state.observe(phase: .thinking, item: review("R")))
        XCTAssertEqual(state.observe(phase: .needsYou, item: failingCI("C")), .cancel)
    }

    func testExplicitSettlementCancelsOnlyCurrentBloom() {
        var state = StatusItemBloomState()
        _ = state.observe(phase: .idle, item: nil)
        let transition = state.observe(phase: .needsYou, item: item("A"))
        guard case .start(let itemID, let generation) = transition else {
            return XCTFail("Expected a bloom start")
        }

        XCTAssertTrue(state.settle())
        XCTAssertFalse(state.isActive)
        XCTAssertFalse(state.expire(itemID: itemID, generation: generation))
        XCTAssertFalse(state.settle())
    }

    private func item(
        _ id: String,
        reason: AgentAttentionReason = .generic
    ) -> WorkItem {
        WorkItem(
            id: id,
            kind: .needsYou,
            title: "Codex needs you",
            detail: "/tmp/Meanwhile",
            createdAt: Date(timeIntervalSince1970: 1),
            session: AgentSessionState(
                provider: .codex,
                sessionID: id,
                cwd: "/tmp/Meanwhile",
                phase: .needsYou,
                attentionReason: reason,
                enteredAt: Date(timeIntervalSince1970: 1),
                updatedAt: Date(timeIntervalSince1970: 1)
            )
        )
    }

    private func review(_ id: String) -> WorkItem {
        WorkItem(
            id: id,
            kind: .review,
            title: "Review #1",
            detail: "acme/repo",
            createdAt: Date(timeIntervalSince1970: 1)
        )
    }

    private func failingCI(_ id: String) -> WorkItem {
        WorkItem(
            id: id,
            kind: .failingCI,
            title: "CI failed on #1",
            detail: "acme/repo",
            createdAt: Date(timeIntervalSince1970: 1)
        )
    }

    private func XCTAssertStart(
        _ transition: StatusItemBloomTransition,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        guard case .start = transition else {
            return XCTFail("Expected a bloom start", file: file, line: line)
        }
    }
}
