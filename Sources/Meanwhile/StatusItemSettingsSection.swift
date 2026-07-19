import SwiftUI

struct StatusItemSettingsSection: View {
    let repositoryScopeDescription: String
    let sourceHealthDescription: String
    let sourceHasError: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Watching")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(repositoryScopeDescription)
                    .font(.callout.weight(.semibold))
                Spacer(minLength: 12)
                Label(
                    sourceHealthDescription,
                    systemImage: sourceHasError
                        ? "exclamationmark.triangle.fill"
                        : "checkmark.circle.fill"
                )
                .font(.caption.weight(.medium))
                .foregroundStyle(sourceHasError ? .orange : .green)
            }

            Grid(alignment: .leading, horizontalSpacing: 14, verticalSpacing: 7) {
                StatusLanguageRow(
                    systemImage: "exclamationmark.bubble.fill",
                    tint: .red,
                    label: "Codex needs you",
                    meaning: "Briefly shows why and where; click to return"
                )
                StatusLanguageRow(
                    systemImage: "rectangle.stack.fill",
                    tint: .orange,
                    label: "#78",
                    meaning: "Briefly names the repository; click to open the PR"
                )
                StatusLanguageRow(
                    systemImage: "rectangle.stack.fill",
                    tint: .orange,
                    label: "CI! #42",
                    meaning: "Briefly names the repository; click to inspect checks"
                )
                StatusLanguageRow(
                    systemImage: "rectangle.stack",
                    tint: .secondary,
                    label: "Icon only",
                    meaning: "Nothing needs your attention"
                )
            }
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Menu bar status meanings")
        }
    }
}

private struct StatusLanguageRow: View {
    let systemImage: String
    let tint: Color
    let label: String
    let meaning: String

    var body: some View {
        GridRow {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .foregroundStyle(tint)
                    .frame(width: 16)
                Text(label)
                    .font(.caption.weight(.semibold))
            }
            .frame(width: 92, alignment: .leading)

            Text(meaning)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
