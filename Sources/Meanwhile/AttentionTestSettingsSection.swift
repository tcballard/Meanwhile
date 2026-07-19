import SwiftUI

enum AttentionTestRunResult: Equatable {
    case startedMenuBarOnly
    case startedWithNotification
    case blockedByRealAttention
    case failedNotification

    var message: String {
        switch self {
        case .startedMenuBarOnly:
            return "The menu bar will show a test for six seconds. Reminders are off or unavailable."
        case .startedWithNotification:
            return "The menu bar and a clearly labelled test notification are active."
        case .blockedByRealAttention:
            return "A real task needs you now, so Meanwhile did not replace it with a test."
        case .failedNotification:
            return "The menu-bar test worked, but macOS did not accept the test notification."
        }
    }

    var isError: Bool {
        self == .blockedByRealAttention || self == .failedNotification
    }
}

struct AttentionTestSettingsSection: View {
    let isRunning: Bool
    let result: AttentionTestRunResult?
    let run: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Test the attention loop")
                        .font(.callout.weight(.semibold))
                    Text("Preview the menu-bar bloom and, when enabled, a test reminder. No agent or GitHub activity is created.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 8)
                Button(isRunning ? "Testing…" : "Run Attention Test", action: run)
                    .disabled(isRunning)
                    .accessibilityHint("Shows a labelled six-second test without creating work")
            }
            if let result {
                SettingsInlineMessage(
                    result.message,
                    systemImage: result.isError
                        ? "exclamationmark.triangle.fill"
                        : "checkmark.circle.fill",
                    tint: result.isError ? .orange : .secondary
                )
            }
        }
    }
}
