import MeanwhileCore
import SwiftUI

struct AttentionSourcesSettingsSection: View {
    @Binding var selection: AttentionSourceSelection

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            sourceRow(
                title: "Agent requests",
                detail: "Permission prompts, questions, and other agent handoffs.",
                isOn: .constant(true),
                isLocked: true
            )
            sourceRow(
                title: "Failing CI",
                detail: "Failed checks on your open pull requests while an agent is thinking.",
                isOn: $selection.failingCIEnabled
            )
            sourceRow(
                title: "Review requests",
                detail: "Pull requests waiting for your review while an agent is thinking.",
                isOn: $selection.reviewsEnabled
            )
            Text("GitHub sources remain wait-gated: enabling them does not show work while every agent is idle.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func sourceRow(
        title: String,
        detail: String,
        isOn: Binding<Bool>,
        isLocked: Bool = false
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.callout.weight(.semibold))
                Text(detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 12)
            if isLocked {
                Label("Always on", systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.green)
                    .accessibilityLabel("Agent requests always on")
            } else {
                Toggle("", isOn: isOn)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .accessibilityLabel(title)
            }
        }
    }
}
