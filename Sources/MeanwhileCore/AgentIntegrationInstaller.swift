import Foundation

public struct AgentIntegrationInstallResult: Equatable, Sendable {
    public var claudeHooksInstalled: Bool
    public var codexHooksInstalled: Bool
    public var claudeStatuslineInstalled: Bool
    public var claudeStatuslineConflict: Bool

    public init(
        claudeHooksInstalled: Bool,
        codexHooksInstalled: Bool,
        claudeStatuslineInstalled: Bool,
        claudeStatuslineConflict: Bool
    ) {
        self.claudeHooksInstalled = claudeHooksInstalled
        self.codexHooksInstalled = codexHooksInstalled
        self.claudeStatuslineInstalled = claudeStatuslineInstalled
        self.claudeStatuslineConflict = claudeStatuslineConflict
    }
}

public final class AgentIntegrationInstaller {
    public let claudeSettingsURL: URL
    public let codexHooksURL: URL
    private let helperURL: URL
    private let fileManager: FileManager

    public init(
        helperURL: URL,
        homeDirectory: URL? = nil,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        fileManager: FileManager = .default
    ) {
        self.helperURL = helperURL
        self.fileManager = fileManager
        let home = homeDirectory ?? fileManager.homeDirectoryForCurrentUser
        let claudeDirectory = Self.configurationDirectory(
            environment["CLAUDE_CONFIG_DIR"],
            defaultName: ".claude",
            homeDirectory: home
        )
        let codexDirectory = Self.configurationDirectory(
            environment["CODEX_HOME"],
            defaultName: ".codex",
            homeDirectory: home
        )
        claudeSettingsURL = claudeDirectory.appendingPathComponent("settings.json")
        codexHooksURL = codexDirectory.appendingPathComponent("hooks.json")
    }

    public func install() throws -> AgentIntegrationInstallResult {
        let claudeCommand = command(provider: .claude)
        var claude = try loadObject(at: claudeSettingsURL)
        var claudeHooks = claude["hooks"] as? [String: Any] ?? [:]
        for event in [
            "SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse",
            "PermissionRequest", "Stop", "SessionEnd"
        ] {
            appendHook(command: claudeCommand, event: event, matcher: nil, name: nil, hooks: &claudeHooks)
        }
        appendHook(
            command: claudeCommand,
            event: "Notification",
            matcher: "permission_prompt|idle_prompt|elicitation_dialog",
            name: nil,
            hooks: &claudeHooks
        )
        claude["hooks"] = claudeHooks

        let currentStatusline = claude["statusLine"] as? [String: Any]
        let currentStatuslineCommand = currentStatusline?["command"] as? String
        let ownsStatusline = currentStatuslineCommand?.contains("MeanwhileHook") == true
        let statuslineConflict = currentStatuslineCommand != nil && !ownsStatusline
        if !statuslineConflict {
            claude["statusLine"] = [
                "type": "command",
                "command": shellQuote(helperURL.path) + " statusline"
            ]
        }
        try writeObject(claude, to: claudeSettingsURL)

        let codexCommand = command(provider: .codex)
        var codex = try loadObject(at: codexHooksURL)
        var codexHooks = codex["hooks"] as? [String: Any] ?? [:]
        let codexEvents = [
            "SessionStart", "UserPromptSubmit", "PreToolUse", "PostToolUse",
            "PermissionRequest", "Stop"
        ]
        for event in codexEvents {
            // Migrate the invalid top-level layout written by Meanwhile v0.1.
            if let legacyGroups = codex.removeValue(forKey: event) as? [[String: Any]] {
                var groups = codexHooks[event] as? [[String: Any]] ?? []
                groups.append(contentsOf: legacyGroups)
                codexHooks[event] = groups
            }
            appendHook(
                command: codexCommand,
                event: event,
                matcher: nil,
                name: "Meanwhile",
                hooks: &codexHooks
            )
        }
        codex["description"] = codex["description"] as? String
            ?? "Meanwhile agent lifecycle integration"
        codex["hooks"] = codexHooks
        try writeObject(codex, to: codexHooksURL)

        return AgentIntegrationInstallResult(
            claudeHooksInstalled: true,
            codexHooksInstalled: true,
            claudeStatuslineInstalled: !statuslineConflict,
            claudeStatuslineConflict: statuslineConflict
        )
    }

    private func command(provider: AgentProvider) -> String {
        "\(shellQuote(helperURL.path)) hook --provider \(provider.rawValue)"
    }

    private func appendHook(
        command: String,
        event: String,
        matcher: String?,
        name: String?,
        hooks: inout [String: Any]
    ) {
        var groups = hooks[event] as? [[String: Any]] ?? []
        var alreadyInstalled = false
        for groupIndex in groups.indices {
            guard var commands = groups[groupIndex]["hooks"] as? [[String: Any]] else { continue }
            for commandIndex in commands.indices where commands[commandIndex]["command"] as? String == command {
                alreadyInstalled = true
                if let name { commands[commandIndex]["name"] = name }
            }
            groups[groupIndex]["hooks"] = commands
        }
        if alreadyInstalled {
            hooks[event] = groups
            return
        }

        var hook: [String: Any] = ["type": "command", "command": command, "timeout": 5]
        if let name { hook["name"] = name }
        var group: [String: Any] = ["hooks": [hook]]
        if let matcher { group["matcher"] = matcher }
        groups.append(group)
        hooks[event] = groups
    }

    private func loadObject(at url: URL) throws -> [String: Any] {
        guard fileManager.fileExists(atPath: url.path) else { return [:] }
        let value = try JSONSerialization.jsonObject(with: Data(contentsOf: url))
        return value as? [String: Any] ?? [:]
    }

    private func writeObject(_ object: [String: Any], to url: URL) throws {
        try fileManager.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let data = try JSONSerialization.data(withJSONObject: object, options: [.prettyPrinted, .sortedKeys])
        try data.write(to: url, options: .atomic)
    }

    private func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\"'\"'") + "'"
    }

    private static func configurationDirectory(
        _ configuredPath: String?,
        defaultName: String,
        homeDirectory: URL
    ) -> URL {
        guard let configuredPath, !configuredPath.isEmpty else {
            return homeDirectory.appendingPathComponent(defaultName, isDirectory: true)
        }
        if configuredPath == "~" { return homeDirectory }
        if configuredPath.hasPrefix("~/") {
            return homeDirectory.appendingPathComponent(String(configuredPath.dropFirst(2)), isDirectory: true)
        }
        if configuredPath.hasPrefix("/") {
            return URL(fileURLWithPath: configuredPath, isDirectory: true)
        }
        return homeDirectory.appendingPathComponent(configuredPath, isDirectory: true)
    }
}
