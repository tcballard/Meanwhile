import Foundation
import XCTest
@testable import MeanwhileCore

final class StatusItemBloomStateTests: XCTestCase {
    func testInitialWaitingPresentationSeedsWithoutReplayingBloom() {
        var state = StatusItemBloomState()

        XCTAssertEqual(state.observe(phase: .needsYou, item: item("A")), .none)
        XCTAssertFalse(state.isActive)
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

    func testLeavingNeedsYouCancelsAndReselectionMayBloomAgain() {
        var state = StatusItemBloomState()
        _ = state.observe(phase: .idle, item: nil)
        XCTAssertStart(state.observe(phase: .needsYou, item: item("A")))
        XCTAssertEqual(state.observe(phase: .thinking, item: review()), .cancel)
        XCTAssertFalse(state.isActive)
        XCTAssertStart(state.observe(phase: .needsYou, item: item("A")))
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

    private func review() -> WorkItem {
        WorkItem(
            id: "review",
            kind: .review,
            title: "Review #1",
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
