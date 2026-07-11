import Foundation
import XCTest
@testable import MeanwhileCore

final class RepositoryPreferencesTests: XCTestCase {
    func testDefaultsToAllRepositoriesAndPersistsSpecificSelection() {
        let suiteName = "MeanwhileTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let preferences = RepositoryPreferences(defaults: defaults)

        XCTAssertTrue(preferences.allows(repository: "acme/anything"))

        preferences.setIncludesAllRepositories(false)
        preferences.setRepository("acme/widgets", isSelected: true)

        XCTAssertTrue(preferences.allows(repository: "acme/widgets"))
        XCTAssertFalse(preferences.allows(repository: "acme/other"))

        let reloaded = RepositoryPreferences(defaults: defaults)
        XCTAssertEqual(
            reloaded.snapshot,
            RepositorySelectionSnapshot(
                includesAllRepositories: false,
                selectedRepositories: ["acme/widgets"]
            )
        )
    }
}
