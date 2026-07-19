import XCTest
@testable import MeanwhileCore

final class SourceRefreshSnapshotTests: XCTestCase {
    func testSuccessAndFailureTransitionsRemainSourceSpecific() {
        let start = Date(timeIntervalSince1970: 100)
        let finish = Date(timeIntervalSince1970: 101)
        var snapshot = SourceRefreshSnapshot(reviewsEnabled: true, failingCIEnabled: true)

        snapshot[.reviews].begin(at: start)
        XCTAssertTrue(snapshot.isRefreshing)
        snapshot[.reviews].succeed(at: finish)
        XCTAssertEqual(snapshot.reviews.lastSuccessAt, finish)
        XCTAssertNil(snapshot.reviews.lastFailureAt)

        snapshot[.failingCI].begin(at: start)
        snapshot[.failingCI].fail(at: finish)
        XCTAssertEqual(snapshot.failingCI.lastFailureAt, finish)
        XCTAssertNil(snapshot.failingCI.lastSuccessAt)
    }

    func testDisabledSourceIgnoresRefreshTransitions() {
        var snapshot = SourceRefreshSnapshot(reviewsEnabled: false, failingCIEnabled: true)
        snapshot[.reviews].begin(at: Date())
        XCTAssertFalse(snapshot.reviews.isRefreshing)
        XCTAssertNil(snapshot.reviews.lastAttemptAt)
    }
}
