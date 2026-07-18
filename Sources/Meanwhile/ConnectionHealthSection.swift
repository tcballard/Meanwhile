import MeanwhileCore
import SwiftUI

struct ConnectionHealthSection: View {
    let integrationHealth: AgentIntegrationHealth
    let integrationHealthError: String?
    let lastAgentEvent: AgentSessionState?
    let githubAuthenticationStatus: GitHubAuthenticationStatus
    let sessionInspection: AgentSessionInspection
    let sessionRecoveryMessage: String?
    let sessionRecoveryIsError: Bool
    let isClearingStuckSessions: Bool
    let staleAfter: String
    let clearStuckSessions: () -> Void
    let now: Date
    @State private var isConfirmingClear = false

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HealthRow(
                systemImage: integrationHealthSymbol,
                tint: integrationHealthTint,
                title: "Agent hooks",
                value: integrationHealthTitle,
                detail: integrationHealthDetail
            )
            HealthRow(
                systemImage: sessionHealthSymbol,
                tint: sessionHealthTint,
                title: "Agent sessions",
                value: sessionHealthTitle,
                detail: sessionHealthDetail,
                actionTitle: sessionInspection.stuckCount > 0 ? "Clear…" : nil,
                actionAccessibilityLabel: "Clear stuck agent sessions",
                action: { isConfirmingClear = true },
                actionDisabled: isClearingStuckSessions
            )
            HealthRow(
                systemImage: agentEventSymbol,
                tint: agentEventTint,
                title: "Last agent event",
                value: lastAgentEventTitle,
                detail: lastAgentEventDetail
            )
            HealthRow(
                systemImage: githubHealthSymbol,
                tint: githubHealthTint,
                title: "GitHub",
                value: githubHealthTitle,
                detail: githubHealthDetail
            )
        }
        .confirmationDialog(
            "Clear sessions that may be stuck?",
            isPresented: $isConfirmingClear
        ) {
            Button("Clear Stuck Sessions", role: .destructive) {
                clearStuckSessions()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Meanwhile will recheck and forget only non-idle sessions with no event for more than \(staleAfter). The latest event summary is kept.")
        }
    }

    private var sessionHealthTitle: String {
        if isClearingStuckSessions { return "Clearing stuck sessions…" }
        if sessionInspection.stuckCount == 1 { return "1 session may be stuck" }
        if sessionInspection.stuckCount > 1 {
            return "\(sessionInspection.stuckCount) sessions may be stuck"
        }
        if sessionInspection.activeCount == 1 { return "1 active session" }
        if sessionInspection.activeCount > 1 {
            return "\(sessionInspection.activeCount) active sessions"
        }
        return "No active sessions"
    }

    private var sessionHealthDetail: String {
        if let sessionRecoveryMessage { return sessionRecoveryMessage }
        if sessionInspection.stuckCount > 0 {
            return "No agent event for more than \(staleAfter). Clear only if the agent has stopped."
        }
        if sessionInspection.activeCount > 0 {
            return "No sessions currently look stuck."
        }
        return "Agent sessions will appear here while Claude or Codex is active."
    }

    private var sessionHealthSymbol: String {
        if sessionRecoveryIsError { return "exclamationmark.triangle.fill" }
        if sessionInspection.stuckCount > 0 { return "clock.badge.exclamationmark.fill" }
        if sessionInspection.activeCount > 0 { return "waveform.circle.fill" }
        return "circle.dashed"
    }

    private var sessionHealthTint: Color {
        if sessionRecoveryIsError || sessionInspection.stuckCount > 0 { return .orange }
        if sessionInspection.activeCount > 0 { return .green }
        return .secondary
    }

    private var integrationHealthTitle: String {
        switch integrationHealth.state {
        case .installed: return "Installed"
        case .needsReview: return "Needs review"
        case .notInstalled: return "Not installed"
        }
    }

    private var integrationHealthDetail: String {
        if let integrationHealthError { return integrationHealthError }
        if integrationHealth.claudeStatuslineConflict {
            return "Claude and Codex hooks are installed; your Claude status line was preserved."
        }
        switch integrationHealth.state {
        case .installed:
            return "Claude and Codex are connected."
        case .needsReview:
            let missing = integrationHealth.claudeHooksInstalled ? "Codex" : "Claude"
            return "\(missing) hooks are missing or incomplete."
        case .notInstalled:
            return "Install hooks to let Meanwhile hear agent lifecycle events."
        }
    }

    private var integrationHealthSymbol: String {
        switch integrationHealth.state {
        case .installed: return "checkmark.circle.fill"
        case .needsReview: return "exclamationmark.triangle.fill"
        case .notInstalled: return "circle.dashed"
        }
    }

    private var integrationHealthTint: Color {
        switch integrationHealth.state {
        case .installed: return .green
        case .needsReview: return .orange
        case .notInstalled: return .secondary
        }
    }

    private var lastAgentEventTitle: String {
        guard let lastAgentEvent else { return "No events yet" }
        switch lastAgentEvent.phase {
        case .thinking: return "Thinking"
        case .needsYou: return "Needs you"
        case .idle: return "Finished"
        }
    }

    private var lastAgentEventDetail: String {
        guard let lastAgentEvent else {
            return "Install integrations, then start an agent session."
        }
        return "\(providerDisplayName(lastAgentEvent.provider)) · \(relativeDateString(lastAgentEvent.updatedAt, relativeTo: now))"
    }

    private var agentEventSymbol: String {
        guard let lastAgentEvent else { return "clock.badge.questionmark" }
        switch lastAgentEvent.phase {
        case .thinking: return "ellipsis.message.fill"
        case .needsYou: return "exclamationmark.bubble.fill"
        case .idle: return "checkmark.circle.fill"
        }
    }

    private var agentEventTint: Color {
        guard let lastAgentEvent else { return .secondary }
        switch lastAgentEvent.phase {
        case .thinking: return .orange
        case .needsYou: return .red
        case .idle: return .green
        }
    }

    private var githubHealthTitle: String {
        githubAuthenticationStatus == .authenticated
            ? "Authenticated"
            : "Not authenticated"
    }

    private var githubHealthDetail: String {
        githubAuthenticationStatus == .authenticated
            ? "Using the GitHub CLI session on this Mac."
            : "Run gh auth login, then refresh repository sources."
    }

    private var githubHealthSymbol: String {
        githubAuthenticationStatus == .authenticated
            ? "checkmark.circle.fill"
            : "person.crop.circle.badge.exclamationmark"
    }

    private var githubHealthTint: Color {
        githubAuthenticationStatus == .authenticated ? .green : .orange
    }
}

private struct HealthRow: View {
    let systemImage: String
    let tint: Color
    let title: String
    let value: String
    let detail: String
    var actionTitle: String? = nil
    var actionAccessibilityLabel: String? = nil
    var action: (() -> Void)? = nil
    var actionDisabled = false

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .frame(width: 18, height: 18)
                    .accessibilityHidden(true)
                Text(title)
                    .frame(width: 118, alignment: .leading)
                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.callout.weight(.semibold))
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .accessibilityElement(children: .combine)
            if let actionTitle, let action {
                Button(actionTitle, action: action)
                    .disabled(actionDisabled)
                    .accessibilityLabel(actionAccessibilityLabel ?? actionTitle)
            }
        }
    }
}
