import Foundation
import XCTest
@testable import MeanwhileCore

final class AgentIntegrationInstallerTests: XCTestCase {
    func testInstallsHooksIdempotentlyAndPreservesUnrelatedSettings() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let claudeDirectory = home.appendingPathComponent(".claude", isDirectory: true)
        try FileManager.default.createDirectory(at: claudeDirectory, withIntermediateDirectories: true)
        try Data("{\"theme\":\"dark\"}".utf8).write(
            to: claudeDirectory.appendingPathComponent("settings.json")
        )
        let installer = AgentIntegrationInstaller(
            helperURL: URL(fileURLWithPath: "/Applications/Meanwhile.app/Contents/Helpers/MeanwhileHook"),
            homeDirectory: home,
            environment: [:]
        )
        _ = try installer.install()
        _ = try installer.install()

        let claude = try object(installer.claudeSettingsURL)
        XCTAssertEqual(claude["theme"] as? String, "dark")
        let hooks = try XCTUnwrap(claude["hooks"] as? [String: Any])
        XCTAssertEqual((hooks["UserPromptSubmit"] as? [[String: Any]])?.count, 1)
        XCTAssertEqual((hooks["PreToolUse"] as? [[String: Any]])?.count, 1)
        XCTAssertEqual((hooks["PostToolUse"] as? [[String: Any]])?.count, 1)
        XCTAssertEqual((hooks["SessionEnd"] as? [[String: Any]])?.count, 1)
        XCTAssertNotNil(claude["statusLine"])
        let codex = try object(installer.codexHooksURL)
        XCTAssertEqual(codex["description"] as? String, "Meanwhile agent lifecycle integration")
        let codexHooks = try XCTUnwrap(codex["hooks"] as? [String: Any])
        XCTAssertEqual((codexHooks["PermissionRequest"] as? [[String: Any]])?.count, 1)
        XCTAssertEqual((codexHooks["PreToolUse"] as? [[String: Any]])?.count, 1)
        XCTAssertEqual((codexHooks["PostToolUse"] as? [[String: Any]])?.count, 1)
        XCTAssertNil(codexHooks["SessionEnd"])
        XCTAssertNil(codex["PermissionRequest"])
        let preToolGroups = try XCTUnwrap(codexHooks["PreToolUse"] as? [[String: Any]])
        let preToolCommands = try XCTUnwrap(preToolGroups.first?["hooks"] as? [[String: Any]])
        XCTAssertEqual(preToolCommands.first?["name"] as? String, "Meanwhile")
    }

    func testMigratesInvalidTopLevelCodexHooks() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let codexDirectory = home.appendingPathComponent(".codex", isDirectory: true)
        try FileManager.default.createDirectory(at: codexDirectory, withIntermediateDirectories: true)
        try Data("{\"Stop\":[{\"hooks\":[{\"type\":\"command\",\"command\":\"old\"}]}]}".utf8)
            .write(to: codexDirectory.appendingPathComponent("hooks.json"))
        let installer = AgentIntegrationInstaller(
            helperURL: URL(fileURLWithPath: "/tmp/MeanwhileHook"),
            homeDirectory: home,
            environment: [:]
        )

        _ = try installer.install()

        let codex = try object(installer.codexHooksURL)
        XCTAssertNil(codex["Stop"])
        let hooks = try XCTUnwrap(codex["hooks"] as? [String: Any])
        XCTAssertEqual((hooks["Stop"] as? [[String: Any]])?.count, 2)
    }

    func testPreservesExistingClaudeStatuslineAndReportsConflict() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let directory = home.appendingPathComponent(".claude", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("{\"statusLine\":{\"type\":\"command\",\"command\":\"my-status\"}}".utf8)
            .write(to: directory.appendingPathComponent("settings.json"))
        let installer = AgentIntegrationInstaller(
            helperURL: URL(fileURLWithPath: "/tmp/MeanwhileHook"),
            homeDirectory: home,
            environment: [:]
        )
        let result = try installer.install()
        XCTAssertTrue(result.claudeStatuslineConflict)
        let claude = try object(installer.claudeSettingsURL)
        XCTAssertEqual((claude["statusLine"] as? [String: Any])?["command"] as? String, "my-status")
    }

    func testHonorsClaudeAndCodexConfigurationDirectories() throws {
        let home = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString, isDirectory: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let codexDirectory = home.appendingPathComponent("absolute-codex", isDirectory: true)
        let installer = AgentIntegrationInstaller(
            helperURL: URL(fileURLWithPath: "/tmp/MeanwhileHook"),
            homeDirectory: home,
            environment: [
                "CLAUDE_CONFIG_DIR": "~/custom-claude",
                "CODEX_HOME": codexDirectory.path
            ]
        )

        _ = try installer.install()

        XCTAssertEqual(
            installer.claudeSettingsURL,
            home.appendingPathComponent("custom-claude/settings.json")
        )
        XCTAssertEqual(
            installer.codexHooksURL,
            codexDirectory.appendingPathComponent("hooks.json")
        )
        XCTAssertTrue(FileManager.default.fileExists(atPath: installer.claudeSettingsURL.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: installer.codexHooksURL.path))
    }

    private func object(_ url: URL) throws -> [String: Any] {
        try XCTUnwrap(
            JSONSerialization.jsonObject(with: Data(contentsOf: url)) as? [String: Any]
        )
    }
}
