import Foundation
import XCTest
@testable import Peripheral

final class ConfigTests: XCTestCase {
    private struct Settings: Codable, Equatable {
        var name: String
        var count: Int
    }

    func testLoadsJSONFromProvidedConfigDirectory() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: directory) }

        let expected = Settings(name: "loaded", count: 4)
        let data = try JSONEncoder().encode(expected)
        try data.write(to: directory.appendingPathComponent("demo.json"))

        let loaded = Config.load(
            app: "demo",
            defaults: Settings(name: "default", count: 0),
            directory: directory
        )

        XCTAssertEqual(loaded, expected)
    }

    func testReturnsDefaultsWhenFileIsMissing() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let defaults = Settings(name: "default", count: 2)

        XCTAssertEqual(
            Config.load(app: "missing", defaults: defaults, directory: directory),
            defaults
        )
    }
}
