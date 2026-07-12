import Foundation

public struct LaunchAgentDefinition: Sendable {
    public var label: String
    public var programArguments: [String]
    public var environmentVariables: [String: String]
    public var runAtLoad: Bool
    public var keepAlive: Bool

    public init(
        label: String,
        programArguments: [String],
        environmentVariables: [String: String] = [:],
        runAtLoad: Bool = true,
        keepAlive: Bool = false
    ) {
        self.label = label
        self.programArguments = programArguments
        self.environmentVariables = environmentVariables
        self.runAtLoad = runAtLoad
        self.keepAlive = keepAlive
    }
}

public enum LaunchAgentInstallerError: Error {
    case invalidLabel
    case missingProgramArguments
}

/// Writes and removes user LaunchAgent plists. It intentionally does not invoke `launchctl`.
public struct LaunchAgentInstaller {
    public let directory: URL
    private let fileManager: FileManager

    public init(
        directory: URL? = nil,
        fileManager: FileManager = .default
    ) {
        self.directory = directory ?? fileManager.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/LaunchAgents", isDirectory: true)
        self.fileManager = fileManager
    }

    @discardableResult
    public func install(_ definition: LaunchAgentDefinition) throws -> URL {
        guard Self.isValid(label: definition.label) else {
            throw LaunchAgentInstallerError.invalidLabel
        }
        guard !definition.programArguments.isEmpty else {
            throw LaunchAgentInstallerError.missingProgramArguments
        }

        try fileManager.createDirectory(
            at: directory,
            withIntermediateDirectories: true
        )

        var plist: [String: Any] = [
            "Label": definition.label,
            "ProgramArguments": definition.programArguments,
            "RunAtLoad": definition.runAtLoad,
            "KeepAlive": definition.keepAlive
        ]
        if !definition.environmentVariables.isEmpty {
            plist["EnvironmentVariables"] = definition.environmentVariables
        }

        let data = try PropertyListSerialization.data(
            fromPropertyList: plist,
            format: .xml,
            options: 0
        )
        let destination = plistURL(for: definition.label)
        try data.write(to: destination, options: .atomic)
        return destination
    }

    public func uninstall(label: String) throws {
        guard Self.isValid(label: label) else {
            throw LaunchAgentInstallerError.invalidLabel
        }
        let url = plistURL(for: label)
        guard fileManager.fileExists(atPath: url.path) else { return }
        try fileManager.removeItem(at: url)
    }

    public func plistURL(for label: String) -> URL {
        directory.appendingPathComponent("\(label).plist")
    }

    private static func isValid(label: String) -> Bool {
        !label.isEmpty && !label.contains("/") && !label.contains("..")
    }
}
