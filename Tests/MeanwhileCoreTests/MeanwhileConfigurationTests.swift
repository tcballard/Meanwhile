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
        XCTAssertNil(config.hotKey)
    }

    func testDecodesAndNormalizesHotKeyConfiguration() throws {
        let config = try JSONDecoder().decode(
            MeanwhileConfiguration.self,
            from: Data("""
            {
              "hotKey": {
                "key": " Space ",
                "modifiers": ["option", "control", "option"]
              }
            }
            """.utf8)
        )

        XCTAssertEqual(
            config.hotKey,
            HotKeyConfiguration(key: "space", modifiers: [.control, .option])
        )
    }

    func testIgnoresHotKeyWithoutModifiers() throws {
        let config = try JSONDecoder().decode(
            MeanwhileConfiguration.self,
            from: Data("""
            {
              "hotKey": {
                "key": "m",
                "modifiers": []
              }
            }
            """.utf8)
        )

        XCTAssertNil(config.hotKey)
    }

    func testHotKeyPreferencesUseConfigDefaultUntilUserChangesSetting() {
        let suiteName = "MeanwhileTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let defaultHotKey = HotKeyConfiguration(key: "space", modifiers: [.control, .option])
        let preferences = HotKeyPreferences(defaults: defaults, defaultHotKey: defaultHotKey)

        XCTAssertEqual(preferences.hotKey, defaultHotKey)

        preferences.setHotKey(HotKeyConfiguration(key: "m", modifiers: [.command]))
        XCTAssertEqual(
            preferences.hotKey,
            HotKeyConfiguration(key: "m", modifiers: [.command])
        )

        preferences.setHotKey(nil)
        XCTAssertNil(preferences.hotKey)
    }
}
