import XCTest
@testable import MeanwhileCore

final class AttentionSourcePreferencesTests: XCTestCase {
    func testSeedsFromConfigurationAndPersistsIndependentChoices() {
        let suite = "AttentionSourcePreferencesTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suite)!
        defer { defaults.removePersistentDomain(forName: suite) }
        let initial = AttentionSourcePreferences(
            defaults: defaults,
            defaultSelection: AttentionSourceSelection(
                reviewsEnabled: false,
                failingCIEnabled: true
            )
        )

        XCTAssertEqual(
            initial.selection,
            AttentionSourceSelection(reviewsEnabled: false, failingCIEnabled: true)
        )
        initial.setReviewsEnabled(true)
        initial.setFailingCIEnabled(false)

        let reloaded = AttentionSourcePreferences(
            defaults: defaults,
            defaultSelection: AttentionSourceSelection(
                reviewsEnabled: false,
                failingCIEnabled: true
            )
        )
        XCTAssertEqual(
            reloaded.selection,
            AttentionSourceSelection(reviewsEnabled: true, failingCIEnabled: false)
        )
        XCTAssertTrue(reloaded.selection.isEnabled(.reviews))
        XCTAssertFalse(reloaded.selection.isEnabled(.failingCI))
    }
}
