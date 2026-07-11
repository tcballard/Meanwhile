import Foundation
import XCTest
@testable import MeanwhileCore

final class MeanwhileConfigurationTests: XCTestCase {
    func testPartialConfigUsesDefaultsAndClampsInvalidDurations() throws {
        let config = try JSONDecoder().decode(
            MeanwhileConfiguration.self,
            from: Data("{\"snoozeSeconds\":-4,\"enableFailingCI\":false}".utf8)
        )
        XCTAssertEqual(config.snoozeSeconds, 900)
        XCTAssertEqual(config.sessionStaleSeconds, 3_600)
        XCTAssertEqual(config.activeSessionStaleSeconds, 86_400)
        XCTAssertTrue(config.enableReviews)
        XCTAssertFalse(config.enableFailingCI)
    }
}
