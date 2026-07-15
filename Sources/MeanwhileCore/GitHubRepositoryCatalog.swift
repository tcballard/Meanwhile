import Foundation

public enum GitHubRepositoryCatalogError: Error {
    case commandFailed(exitCode: Int32, stderr: String)
}

extension GitHubRepositoryCatalogError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case let .commandFailed(exitCode, stderr):
            let detail = stderr.trimmingCharacters(in: .whitespacesAndNewlines)
            return detail.isEmpty
                ? "GitHub CLI exited with code \(exitCode)."
                : detail
        }
    }
}

public struct GitHubRepositoryCatalog: Sendable {
    public static let command = "gh api --method GET /user/repos --raw-field affiliation=owner,collaborator,organization_member --raw-field per_page=100 --paginate --jq '.[].full_name'"

    private let runner: any CommandRunning

    public init(runner: any CommandRunning = PeripheralCommandRunner()) {
        self.runner = runner
    }

    public func repositories() throws -> [String] {
        let result = try runner.run(Self.command, timeoutSeconds: 30)
        guard result.exitCode == 0 else {
            throw GitHubRepositoryCatalogError.commandFailed(
                exitCode: result.exitCode,
                stderr: result.stderr
            )
        }

        return Array(
            Set(
                result.stdout
                    .split(whereSeparator: { $0.isNewline })
                    .map(String.init)
                    .filter { !$0.isEmpty }
            )
        ).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
}

public enum GitHubAuthenticationStatus: Equatable, Sendable {
    case authenticated
    case notAuthenticated
}

public struct GitHubAuthenticationChecker: Sendable {
    public static let command = "gh auth status"

    private let runner: any CommandRunning

    public init(runner: any CommandRunning = PeripheralCommandRunner()) {
        self.runner = runner
    }

    public func status() -> GitHubAuthenticationStatus {
        guard let result = try? runner.run(Self.command, timeoutSeconds: 10) else {
            return .notAuthenticated
        }
        return result.exitCode == 0 ? .authenticated : .notAuthenticated
    }
}
