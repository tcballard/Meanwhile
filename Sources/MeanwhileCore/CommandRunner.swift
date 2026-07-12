import Foundation
import Peripheral

public struct ShellCommandResult: Equatable, Sendable {
    public var exitCode: Int32
    public var stdout: String
    public var stderr: String

    public init(exitCode: Int32, stdout: String, stderr: String) {
        self.exitCode = exitCode
        self.stdout = stdout
        self.stderr = stderr
    }
}

public protocol CommandRunning: Sendable {
    func run(_ command: String, timeoutSeconds: TimeInterval) throws -> ShellCommandResult
}

public struct PeripheralCommandRunner: CommandRunning {
    public init() {}

    public func run(
        _ command: String,
        timeoutSeconds: TimeInterval
    ) throws -> ShellCommandResult {
        let result = try ShellRunner.run(command, timeoutSeconds: timeoutSeconds)
        return ShellCommandResult(
            exitCode: result.exitCode,
            stdout: result.stdout,
            stderr: result.stderr
        )
    }
}
