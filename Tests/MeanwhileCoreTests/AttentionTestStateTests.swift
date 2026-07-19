import XCTest
@testable import MeanwhileCore

final class AttentionTestStateTests: XCTestCase {
    func testStartsOnceAndIgnoresStaleExpiry() {
        var state = AttentionTestState()
        XCTAssertEqual(state.start(realAttentionIsActive: false), .started(generation: 1))
        XCTAssertEqual(state.start(realAttentionIsActive: false), .none)
        XCTAssertEqual(state.finish(generation: 0), .none)
        XCTAssertTrue(state.isActive)
        XCTAssertEqual(state.finish(generation: 1), .finished)
        XCTAssertFalse(state.isActive)
    }

    func testRealAttentionBlocksAndPreemptsTest() {
        var state = AttentionTestState()
        XCTAssertEqual(state.start(realAttentionIsActive: true), .none)
        XCTAssertEqual(state.start(realAttentionIsActive: false), .started(generation: 1))
        XCTAssertEqual(state.observeRealAttention(isActive: true), .preempted)
        XCTAssertFalse(state.isActive)
    }
}
