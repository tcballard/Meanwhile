import XCTest
@testable import Peripheral

final class PollTimerTests: XCTestCase {
    func testTimerFiresOnBackgroundQueue() {
        let fired = expectation(description: "timer fired")
        let timer = PollTimer(interval: 0.02, leeway: .milliseconds(1))

        timer.start {
            XCTAssertFalse(Thread.isMainThread)
            fired.fulfill()
        }

        wait(for: [fired], timeout: 1)
        timer.cancel()
    }
}
