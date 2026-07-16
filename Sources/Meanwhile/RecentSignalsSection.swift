import MeanwhileCore
import SwiftUI

struct RecentSignalsSection: View {
    let signals: [RecentSignal]
    let now: Date

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if signals.isEmpty {
                HStack(spacing: 10) {
                    Image(systemName: "waveform.path")
                        .foregroundStyle(.secondary)
                        .frame(width: 18)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("No signals recorded yet")
                            .font(.callout.weight(.medium))
                        Text("Agent, review, CI, snooze, and hide activity will appear here.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                ForEach(Array(signals.prefix(5).enumerated()), id: \.element.id) { index, signal in
                    if index > 0 { Divider().padding(.leading, 28) }
                    RecentSignalRow(signal: signal, now: now)
                }
            }
        }
    }
}

private struct RecentSignalRow: View {
    let signal: RecentSignal
    let now: Date

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: symbol)
                .foregroundStyle(tint)
                .frame(width: 18, height: 18)
            VStack(alignment: .leading, spacing: 2) {
                Text(signal.title)
                    .font(.callout.weight(.medium))
                Text(signal.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 12)
            Text(relativeDateString(signal.date, relativeTo: now))
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .monospacedDigit()
        }
        .accessibilityElement(children: .combine)
    }

    private var symbol: String {
        switch signal.kind {
        case .agentNeedsYou: return "exclamationmark.bubble.fill"
        case .reviewSurfaced: return "arrow.triangle.pull"
        case .ciFailed: return "xmark.circle.fill"
        case .snoozed: return "clock.fill"
        case .hiddenUntilChange: return "eye.slash.fill"
        case .integrationsInstalled: return "checkmark.circle.fill"
        }
    }

    private var tint: Color {
        switch signal.kind {
        case .agentNeedsYou, .ciFailed: return .red
        case .reviewSurfaced, .snoozed: return .orange
        case .hiddenUntilChange: return .secondary
        case .integrationsInstalled: return .green
        }
    }
}
