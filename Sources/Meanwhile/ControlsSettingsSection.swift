import MeanwhileCore
import SwiftUI

struct ControlsSettingsSection: View {
    @Binding var hotKey: HotKeyConfiguration?
    let hotKeyRegistrationError: String?
    let setHotKeyRegistrationError: (String?) -> Void
    let isInstallingIntegrations: Bool
    let integrationActionMessage: String?
    let integrationActionIsError: Bool
    let installIntegrations: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            SettingsSectionHeader(title: "Controls")

            HStack(spacing: 10) {
                Text("Keyboard shortcut")
                    .frame(width: 132, alignment: .leading)

                ShortcutRecorder(
                    shortcut: $hotKey,
                    validationMessage: setHotKeyRegistrationError
                )
                .frame(width: 190, height: 26)

                Button {
                    hotKey = nil
                } label: {
                    Image(systemName: "xmark.circle")
                }
                .buttonStyle(.borderless)
                .disabled(hotKey == nil)
                .help("Clear keyboard shortcut")
                .accessibilityLabel("Clear keyboard shortcut")

                Spacer()

                Text("Opens the current item")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if let hotKeyRegistrationError {
                Label(hotKeyRegistrationError, systemImage: "exclamationmark.triangle.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                    .padding(.leading, 142)
            }

            HStack(spacing: 10) {
                Text("Agent integrations")
                    .frame(width: 132, alignment: .leading)

                Button("Install or Update…", action: installIntegrations)
                    .disabled(isInstallingIntegrations)

                if isInstallingIntegrations {
                    ProgressView()
                        .controlSize(.small)
                }

                Text("Adds local Claude and Codex lifecycle hooks")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            if let integrationActionMessage {
                Label(
                    integrationActionMessage,
                    systemImage: integrationActionIsError
                        ? "exclamationmark.triangle.fill"
                        : "checkmark.circle.fill"
                )
                .font(.caption)
                .foregroundStyle(integrationActionIsError ? .orange : .green)
                .padding(.leading, 142)
            }
        }
    }
}
