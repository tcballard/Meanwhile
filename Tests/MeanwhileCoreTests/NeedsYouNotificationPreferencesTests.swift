import Foundation
import XCTest
@testable import MeanwhileCore

final class NeedsYouNotificationPreferencesTests: XCTestCase {
    func testDefaultsToDisabledWithOneMinuteDelay() throws {
        let fixture = try makeFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }

        let preferences = NeedsYouNotificationPreferences(defaults: fixture.defaults)

        XCTAssertEqual(
            preferences.settings,
            NeedsYouNotificationSettings(isEnabled: false, delay: .oneMinute)
        )
    }

    func testPersistsEnabledStateAndDelayAcrossInstances() throws {
        let fixture = try makeFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }

        let preferences = NeedsYouNotificationPreferences(defaults: fixture.defaults)
        preferences.setEnabled(true)
        preferences.setDelay(.fifteenMinutes)

        XCTAssertEqual(
            NeedsYouNotificationPreferences(defaults: fixture.defaults).settings,
            NeedsYouNotificationSettings(isEnabled: true, delay: .fifteenMinutes)
        )
    }

    func testInvalidPersistedDelayFallsBackToOneMinuteWithoutLosingEnabledIntent() throws {
        let fixture = try makeFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        fixture.defaults.set(true, forKey: "Meanwhile.notifications.needsYou.enabled")
        fixture.defaults.set(777, forKey: "Meanwhile.notifications.needsYou.delaySeconds")

        let preferences = NeedsYouNotificationPreferences(defaults: fixture.defaults)

        XCTAssertEqual(
            preferences.settings,
            NeedsYouNotificationSettings(isEnabled: true, delay: .oneMinute)
        )
    }

    func testSupportedDelaysExposeTheirSchedulingIntervals() {
        XCTAssertEqual(
            NeedsYouNotificationDelay.allCases.map(\.timeInterval),
            [60, 300, 900, 1_800]
        )
    }

    func testPersistsAndBoundsOpaqueDeliveryReceipts() throws {
        let fixture = try makeFixture()
        defer { fixture.defaults.removePersistentDomain(forName: fixture.suiteName) }
        let preferences = NeedsYouNotificationPreferences(defaults: fixture.defaults)

        for index in 0..<35 {
            preferences.recordReceipt(identifier: "opaque-\(index)")
        }
        preferences.recordReceipt(identifier: "opaque-34")

        let reloaded = NeedsYouNotificationPreferences(defaults: fixture.defaults)
        XCTAssertFalse(reloaded.containsReceipt(identifier: "opaque-0"))
        XCTAssertFalse(reloaded.containsReceipt(identifier: "opaque-2"))
        XCTAssertTrue(reloaded.containsReceipt(identifier: "opaque-3"))
        XCTAssertTrue(reloaded.containsReceipt(identifier: "opaque-34"))
    }

    private func makeFixture() throws -> (suiteName: String, defaults: UserDefaults) {
        let suiteName = "NeedsYouNotificationPreferencesTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defaults.removePersistentDomain(forName: suiteName)
        return (suiteName, defaults)
    }
}
