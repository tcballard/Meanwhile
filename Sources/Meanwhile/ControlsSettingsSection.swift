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
    let launchAtLoginStatus: LaunchAtLoginStatus
    let launchAtLoginError: String?
    let setLaunchAtLoginEnabled: (Bool) -> Void
    let openLoginItemsSettings: () -> Void

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

            HStack(alignment: .top, spacing: 10) {
                Text("Launch at login")
                    .frame(width: 132, alignment: .leading)

                Toggle(
                    "Launch Meanwhile when you log in",
                    isOn: Binding(
                        get: { launchAtLoginStatus.isRequested },
                        set: { setLaunchAtLoginEnabled($0) }
                    )
                )
                .labelsHidden()
                .toggleStyle(.switch)
                .accessibilityHint("Controls whether Meanwhile opens automatically after login.")

                VStack(alignment: .leading, spacing: 2) {
                    Text(launchAtLoginTitle)
                        .font(.callout.weight(.medium))
                    Text(launchAtLoginDetail)
                        .font(.caption)
                        .foregroundStyle(
                            launchAtLoginStatus == .requiresApproval || launchAtLoginError != nil
                                ? .orange
                                : .secondary
                        )
                }

                Spacer(minLength: 8)

                if launchAtLoginStatus == .requiresApproval || launchAtLoginError != nil {
                    Button("Open Login Items…", action: openLoginItemsSettings)
                }
            }

            if let launchAtLoginError {
                SettingsInlineMessage(
                    launchAtLoginError,
                    systemImage: "exclamationmark.triangle.fill",
                    tint: .orange
                )
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

    private var launchAtLoginTitle: String {
        switch launchAtLoginStatus {
        case .disabled: return "Off"
        case .enabled: return "On"
        case .requiresApproval: return "Approval needed"
        case .unavailable: return "Unavailable"
        }
    }

    private var launchAtLoginDetail: String {
        switch launchAtLoginStatus {
        case .disabled:
            return "Meanwhile opens only when you launch it."
        case .enabled:
            return "Meanwhile will be ready after your next login."
        case .requiresApproval:
            return "Allow Meanwhile in System Settings to finish enabling it."
        case .unavailable:
            return "macOS could not find the app's login item."
        }
    }
}

private extension LaunchAtLoginStatus {
    var isRequested: Bool {
        self == .enabled || self == .requiresApproval
    }
}
