import MeanwhileCore
import SwiftUI

struct ConnectionHealthSection: View {
    let integrationHealth: AgentIntegrationHealth
    let integrationHealthError: String?
    let lastAgentEvent: AgentSessionState?
    let githubAuthenticationStatus: GitHubAuthenticationStatus
    let now: Date

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

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: systemImage)
                .foregroundStyle(tint)
                .frame(width: 18, height: 18)
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
    }
}
