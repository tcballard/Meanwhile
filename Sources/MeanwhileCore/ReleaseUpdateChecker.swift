import Foundation

public enum ReleaseUpdateState: Equatable, Sendable {
    case notChecked
    case checking
    case current(latestVersion: String, releaseURL: URL)
    case updateAvailable(version: String, releaseURL: URL)
    case developmentBuild(latestVersion: String, releaseURL: URL)
    case unavailable

    public var releaseURL: URL? {
        switch self {
        case .current(_, let releaseURL),
             .updateAvailable(_, let releaseURL),
             .developmentBuild(_, let releaseURL):
            return releaseURL
        case .notChecked, .checking, .unavailable:
            return nil
        }
    }
}

public enum ReleaseUpdateCheckerError: Error, Equatable {
    case commandFailed
    case invalidResponse
    case invalidVersion
}

extension ReleaseUpdateCheckerError: LocalizedError {
    public var errorDescription: String? {
        switch self {
        case .commandFailed:
            return "Could not check GitHub releases. Confirm the GitHub CLI is installed and authenticated."
        case .invalidResponse:
            return "GitHub returned an unreadable release response."
        case .invalidVersion:
            return "The installed and latest release versions could not be compared."
        }
    }
}

public struct ReleaseUpdateChecker: Sendable {
    public static let command =
        "gh release view --repo tcballard/Meanwhile --json tagName,url"

    private struct ReleasePayload: Decodable {
        var tagName: String
        var url: String
    }

    private let runner: any CommandRunning

    public init(runner: any CommandRunning = PeripheralCommandRunner()) {
        self.runner = runner
    }

    public func check(currentVersion: String) throws -> ReleaseUpdateState {
        let result = try runner.run(Self.command, timeoutSeconds: 15)
        guard result.exitCode == 0 else {
            throw ReleaseUpdateCheckerError.commandFailed
        }

        guard let data = result.stdout.data(using: .utf8),
              let payload = try? JSONDecoder().decode(ReleasePayload.self, from: data),
              let releaseURL = URL(string: payload.url),
              releaseURL.scheme == "https",
              releaseURL.host == "github.com" else {
            throw ReleaseUpdateCheckerError.invalidResponse
        }

        guard let current = SemanticVersion(currentVersion),
              let latest = SemanticVersion(payload.tagName) else {
            throw ReleaseUpdateCheckerError.invalidVersion
        }

        if current < latest {
            return .updateAvailable(version: payload.tagName, releaseURL: releaseURL)
        }
        if latest < current {
            return .developmentBuild(
                latestVersion: payload.tagName,
                releaseURL: releaseURL
            )
        }
        return .current(latestVersion: payload.tagName, releaseURL: releaseURL)
    }
}

public struct SemanticVersion: Comparable, Equatable, Sendable {
    private let components: [Int]

    public init?(_ value: String) {
        var normalized = value.trimmingCharacters(in: .whitespacesAndNewlines)
        if normalized.lowercased().hasPrefix("v") {
            normalized.removeFirst()
        }
        let core = normalized.split(separator: "-", maxSplits: 1).first.map(String.init) ?? ""
        let parts = core.split(separator: ".", omittingEmptySubsequences: false)
        guard (2...4).contains(parts.count),
              parts.allSatisfy({ !$0.isEmpty && $0.allSatisfy(\.isNumber) }) else {
            return nil
        }
        var parsed = parts.compactMap { Int($0) }
        guard parsed.count == parts.count else { return nil }
        while parsed.count < 3 {
            parsed.append(0)
        }
        components = parsed
    }

    public static func < (lhs: SemanticVersion, rhs: SemanticVersion) -> Bool {
        let count = max(lhs.components.count, rhs.components.count)
        for index in 0..<count {
            let left = index < lhs.components.count ? lhs.components[index] : 0
            let right = index < rhs.components.count ? rhs.components[index] : 0
            if left != right { return left < right }
        }
        return false
    }
}
