import Darwin
import Foundation
import MeanwhileCore

private enum MeanwhileHook {
    static func run() {
        let arguments = Array(CommandLine.arguments.dropFirst())
        guard let mode = arguments.first else { return }

        switch mode {
        case "hook":
            recordHook(arguments: Array(arguments.dropFirst()))
        case "statusline":
            if let snapshot = StatuslineSnapshotStore().read(), !snapshot.text.isEmpty {
                print(snapshot.text)
            }
        default:
            return
        }
    }

    private static func recordHook(arguments: [String]) {
        defer { print("{}") }
        guard let providerIndex = arguments.firstIndex(of: "--provider"),
              arguments.indices.contains(providerIndex + 1) else { return }
        let provider = AgentProvider(rawValue: arguments[providerIndex + 1]) ?? .unknown
        guard let data = try? FileHandle.standardInput.readToEnd(), !data.isEmpty else { return }

        let store = AgentEventStore()
        guard let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sessionID = object["session_id"] as? String else { return }
        let previous = store.session(provider: provider, sessionID: sessionID)
        var environment = ProcessInfo.processInfo.environment
        if environment["MEANWHILE_TTY"] == nil, let tty = parentTTY() {
            environment["MEANWHILE_TTY"] = tty
        }
        guard let state = try? HookEventDecoder.decode(
            data,
            provider: provider,
            environment: environment,
            previous: previous
        ) else { return }
        try? store.write(state)
    }

    private static func parentTTY() -> String? {
        let process = Process()
        let pipe = Pipe()
        process.executableURL = URL(fileURLWithPath: "/bin/ps")
        process.arguments = ["-o", "tty=", "-p", String(getppid())]
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice
        guard (try? process.run()) != nil else { return nil }
        process.waitUntilExit()
        let value = String(
            decoding: pipe.fileHandleForReading.readDataToEndOfFile(),
            as: UTF8.self
        ).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty, value != "??" else { return nil }
        return value.hasPrefix("/dev/") ? value : "/dev/\(value)"
    }
}

MeanwhileHook.run()
