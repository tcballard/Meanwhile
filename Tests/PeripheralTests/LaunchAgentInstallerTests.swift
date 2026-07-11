import Foundation
import XCTest
@testable import Peripheral

final class LaunchAgentInstallerTests: XCTestCase {
    func testInstallWritesValidPlistAndUninstallRemovesIt() throws {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: directory) }
        let installer = LaunchAgentInstaller(directory: directory)
        let definition = LaunchAgentDefinition(
            label: "com.example.demo",
            programArguments: ["/tmp/demo", "--quiet"],
            environmentVariables: ["MODE": "test"],
            runAtLoad: false
        )

        let url = try installer.install(definition)
        let plist = try XCTUnwrap(
            PropertyListSerialization.propertyList(
                from: Data(contentsOf: url),
                format: nil
            ) as? [String: Any]
        )

        XCTAssertEqual(plist["Label"] as? String, "com.example.demo")
        XCTAssertEqual(plist["ProgramArguments"] as? [String], ["/tmp/demo", "--quiet"])
        XCTAssertEqual(plist["RunAtLoad"] as? Bool, false)
        XCTAssertTrue(FileManager.default.fileExists(atPath: url.path))

        try installer.uninstall(label: definition.label)
        XCTAssertFalse(FileManager.default.fileExists(atPath: url.path))
    }

    func testRejectsUnsafeLabelsForInstallAndUninstall() {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        let installer = LaunchAgentInstaller(directory: directory)

        XCTAssertThrowsError(
            try installer.install(
                LaunchAgentDefinition(
                    label: "../../unsafe",
                    programArguments: ["/tmp/demo"]
                )
            )
        )
        XCTAssertThrowsError(try installer.uninstall(label: "../../unsafe"))
    }
}
