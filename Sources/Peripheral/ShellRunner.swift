import Darwin
import Foundation

public enum ShellRunner {
    public typealias Result = (exitCode: Int32, stdout: String, stderr: String)

    /// Runs a command through zsh. A timed-out command is terminated and returns exit code 124.
    public static func run(
        _ cmd: String,
        cwd: String? = nil,
        timeoutSeconds: TimeInterval
    ) throws -> Result {
        let process = Process()
        let stdoutPipe = Pipe()
        let stderrPipe = Pipe()
        let stdoutData = LockedData()
        let stderrData = LockedData()
        let readers = DispatchGroup()
        let terminated = DispatchSemaphore(value: 0)

        process.executableURL = URL(fileURLWithPath: "/bin/zsh")
        // Avoid a login shell: zsh's startup files may replace the explicit PATH.
        process.arguments = ["-c", cmd]
        process.standardOutput = stdoutPipe
        process.standardError = stderrPipe
        process.environment = environmentForGUIProcess()

        if let cwd {
            process.currentDirectoryURL = URL(fileURLWithPath: cwd, isDirectory: true)
        }

        readers.enter()
        DispatchQueue.global(qos: .utility).async {
            stdoutData.set(stdoutPipe.fileHandleForReading.readDataToEndOfFile())
            readers.leave()
        }

        readers.enter()
        DispatchQueue.global(qos: .utility).async {
            stderrData.set(stderrPipe.fileHandleForReading.readDataToEndOfFile())
            readers.leave()
        }

        process.terminationHandler = { _ in terminated.signal() }

        do {
            try process.run()
        } catch {
            stdoutPipe.fileHandleForWriting.closeFile()
            stderrPipe.fileHandleForWriting.closeFile()
            throw error
        }

        let waitResult = terminated.wait(timeout: .now() + max(0, timeoutSeconds))
        let timedOut = waitResult == .timedOut

        if timedOut {
            process.terminate()
            if terminated.wait(timeout: .now() + .milliseconds(250)) == .timedOut {
                kill(process.processIdentifier, SIGKILL)
                _ = terminated.wait(timeout: .now() + .seconds(1))
            }
        }

        if timedOut {
            // Do not wait indefinitely for pipes inherited by a grandchild.
            _ = readers.wait(timeout: .now() + .milliseconds(100))
        } else {
            readers.wait()
        }

        return (
            exitCode: timedOut ? 124 : process.terminationStatus,
            stdout: stdoutData.string,
            stderr: stderrData.string
        )
    }

    private static func environmentForGUIProcess() -> [String: String] {
        var environment = ProcessInfo.processInfo.environment
        let inheritedPath = environment["PATH"] ?? "/usr/bin:/bin:/usr/sbin:/sbin"
        let prefixes = ["/opt/homebrew/bin", "/usr/local/bin"]
        let pathParts = inheritedPath.split(separator: ":").map(String.init)
        environment["PATH"] = (prefixes + pathParts.filter { !prefixes.contains($0) })
            .joined(separator: ":")
        return environment
    }
}

private final class LockedData: @unchecked Sendable {
    private let lock = NSLock()
    private var data = Data()

    func set(_ newData: Data) {
        lock.lock()
        data = newData
        lock.unlock()
    }

    var string: String {
        lock.lock()
        defer { lock.unlock() }
        return String(decoding: data, as: UTF8.self)
    }
}
