import Foundation

public enum LaunchAtLoginStatus: Equatable, Sendable {
    case disabled
    case enabled
    case requiresApproval
    case unavailable
}

public struct DiagnosticsSnapshot: Sendable {
    public var appVersion: String
    public var buildVersion: String
    public var operatingSystemVersion: String
    public var launchAtLoginStatus: LaunchAtLoginStatus
    public var updateState: ReleaseUpdateState
    public var integrationHealth: AgentIntegrationHealth
    public var githubAuthenticationStatus: GitHubAuthenticationStatus
    public var repositoryScopeIncludesAll: Bool
    public var accessibleRepositoryCount: Int
    public var selectedRepositoryCount: Int
    public var hotKeyConfigured: Bool
    public var sessionInspection: AgentSessionInspection
    public var lastAgentEvent: AgentSessionState?
    public var recentSignals: [RecentSignal]

    public init(
        appVersion: String,
        buildVersion: String,
        operatingSystemVersion: String,
        launchAtLoginStatus: LaunchAtLoginStatus,
        updateState: ReleaseUpdateState,
        integrationHealth: AgentIntegrationHealth,
        githubAuthenticationStatus: GitHubAuthenticationStatus,
        repositoryScopeIncludesAll: Bool,
        accessibleRepositoryCount: Int,
        selectedRepositoryCount: Int,
        hotKeyConfigured: Bool,
        sessionInspection: AgentSessionInspection,
        lastAgentEvent: AgentSessionState?,
        recentSignals: [RecentSignal]
    ) {
        self.appVersion = appVersion
        self.buildVersion = buildVersion
        self.operatingSystemVersion = operatingSystemVersion
        self.launchAtLoginStatus = launchAtLoginStatus
        self.updateState = updateState
        self.integrationHealth = integrationHealth
        self.githubAuthenticationStatus = githubAuthenticationStatus
        self.repositoryScopeIncludesAll = repositoryScopeIncludesAll
        self.accessibleRepositoryCount = accessibleRepositoryCount
        self.selectedRepositoryCount = selectedRepositoryCount
        self.hotKeyConfigured = hotKeyConfigured
        self.sessionInspection = sessionInspection
        self.lastAgentEvent = lastAgentEvent
        self.recentSignals = recentSignals
    }
}

public enum MeanwhileDiagnosticsReport {
    public static func make(
        snapshot: DiagnosticsSnapshot,
        generatedAt: Date = Date()
    ) -> String {
        var lines = [
            "Meanwhile diagnostics",
            "Schema: 1",
            "Generated: \(timestamp(generatedAt))",
            "App: \(snapshot.appVersion) (\(snapshot.buildVersion))",
            "macOS: \(snapshot.operatingSystemVersion)",
            "Launch at login: \(launchAtLoginDescription(snapshot.launchAtLoginStatus))",
            "Update: \(updateDescription(snapshot.updateState))",
            "Integrations: \(integrationDescription(snapshot.integrationHealth.state))",
            "Claude hooks: \(yesNo(snapshot.integrationHealth.claudeHooksInstalled))",
            "Codex hooks: \(yesNo(snapshot.integrationHealth.codexHooksInstalled))",
            "Claude status line conflict: \(yesNo(snapshot.integrationHealth.claudeStatuslineConflict))",
            "GitHub CLI: \(snapshot.githubAuthenticationStatus == .authenticated ? "authenticated" : "not authenticated")",
            "Repository scope: \(repositoryScopeDescription(snapshot))",
            "Keyboard shortcut: \(snapshot.hotKeyConfigured ? "configured" : "not configured")",
            "Active agent sessions: \(snapshot.sessionInspection.activeCount)",
            "Sessions that may be stuck: \(snapshot.sessionInspection.stuckCount)"
        ]

        if let event = snapshot.lastAgentEvent {
            lines.append(
                "Last agent event: \(event.provider.rawValue), \(event.phase.rawValue), \(timestamp(event.updatedAt))"
            )
        } else {
            lines.append("Last agent event: none")
        }

        lines.append("Recent signals: \(snapshot.recentSignals.count)")
        for kind in RecentSignalKind.allCases {
            let count = snapshot.recentSignals.lazy.filter { $0.kind == kind }.count
            lines.append("Recent \(kind.rawValue): \(count)")
        }
        if let newest = snapshot.recentSignals.map(\.date).max() {
            lines.append("Newest signal: \(timestamp(newest))")
        } else {
            lines.append("Newest signal: none")
        }

        return lines.joined(separator: "\n") + "\n"
    }

    private static func timestamp(_ date: Date) -> String {
        ISO8601DateFormatter().string(from: date)
    }

    private static func yesNo(_ value: Bool) -> String {
        value ? "yes" : "no"
    }

    private static func launchAtLoginDescription(_ status: LaunchAtLoginStatus) -> String {
        switch status {
        case .disabled: return "off"
        case .enabled: return "on"
        case .requiresApproval: return "needs approval"
        case .unavailable: return "unavailable"
        }
    }

    private static func updateDescription(_ state: ReleaseUpdateState) -> String {
        switch state {
        case .notChecked: return "not checked"
        case .checking: return "checking"
        case .current(let version, _): return "current (\(version))"
        case .updateAvailable(let version, _): return "available (\(version))"
        case .developmentBuild(let version, _): return "development build; latest release \(version)"
        case .unavailable: return "unavailable"
        }
    }

    private static func integrationDescription(
        _ state: AgentIntegrationHealthState
    ) -> String {
        switch state {
        case .installed: return "installed"
        case .needsReview: return "needs review"
        case .notInstalled: return "not installed"
        }
    }

    private static func repositoryScopeDescription(
        _ snapshot: DiagnosticsSnapshot
    ) -> String {
        if snapshot.repositoryScopeIncludesAll {
            return "all accessible (\(snapshot.accessibleRepositoryCount))"
        }
        return "selected only (\(snapshot.selectedRepositoryCount))"
    }
}
