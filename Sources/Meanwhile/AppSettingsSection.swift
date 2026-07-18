import MeanwhileCore
import SwiftUI

struct AppSettingsSection: View {
    let appVersion: String
    let buildVersion: String
    let updateState: ReleaseUpdateState
    let updateErrorMessage: String?
    let checkForUpdates: () -> Void
    let openLatestRelease: () -> Void
    let diagnosticsCopyMessage: String?
    let diagnosticsCopyIsError: Bool
    let copyDiagnostics: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 10) {
                Text("Software update")
                    .frame(width: 132, alignment: .leading)

                Image(systemName: updateSymbol)
                    .foregroundStyle(updateTint)
                    .frame(width: 18, height: 18)
                    .accessibilityHidden(true)

                VStack(alignment: .leading, spacing: 2) {
                    Text(updateTitle)
                        .font(.callout.weight(.medium))
                    Text(updateDetail)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 8)

                if updateState.releaseURL != nil {
                    Button("View Release…", action: openLatestRelease)
                }
                Button("Check Again", action: checkForUpdates)
                    .disabled(updateState == .checking)
            }

            if let updateErrorMessage {
                SettingsInlineMessage(
                    updateErrorMessage,
                    systemImage: "exclamationmark.triangle.fill",
                    tint: .orange
                )
            }

            HStack(alignment: .top, spacing: 10) {
                Text("Support")
                    .frame(width: 132, alignment: .leading)

                Button(action: copyDiagnostics) {
                    if let diagnosticsCopyMessage {
                        Label(
                            diagnosticsCopyMessage,
                            systemImage: diagnosticsCopyIsError
                                ? "exclamationmark.triangle.fill"
                                : "checkmark.circle.fill"
                        )
                        .foregroundStyle(diagnosticsCopyIsError ? .orange : .green)
                    } else {
                        Text("Copy Diagnostics")
                    }
                }
                .frame(minWidth: 116)
                .accessibilityLabel(diagnosticsCopyMessage ?? "Copy Diagnostics")
                .accessibilityHint("Copies a privacy-safe support summary to the clipboard.")

                Text("Copies a privacy-safe status summary without repository names, paths, prompts, session IDs, or credentials.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var updateTitle: String {
        switch updateState {
        case .notChecked: return "Version \(appVersion)"
        case .checking: return "Checking for updates…"
        case .current: return "Meanwhile is up to date"
        case .updateAvailable(let version, _): return "\(version) is available"
        case .developmentBuild: return "Development build"
        case .unavailable: return "Update check unavailable"
        }
    }

    private var updateDetail: String {
        switch updateState {
        case .notChecked:
            return "Installed version \(appVersion) (\(buildVersion))."
        case .checking:
            return "Comparing \(appVersion) with the latest GitHub release."
        case .current(let version, _):
            return "Installed \(appVersion) (\(buildVersion)); latest release \(version)."
        case .updateAvailable:
            return "Installed \(appVersion) (\(buildVersion)). Meanwhile never updates automatically."
        case .developmentBuild(let version, _):
            return "Installed \(appVersion) (\(buildVersion)); latest public release \(version)."
        case .unavailable:
            return "Installed \(appVersion) (\(buildVersion))."
        }
    }

    private var updateSymbol: String {
        switch updateState {
        case .current: return "checkmark.circle.fill"
        case .updateAvailable: return "arrow.down.circle.fill"
        case .developmentBuild: return "hammer.circle.fill"
        case .unavailable: return "exclamationmark.triangle.fill"
        case .notChecked, .checking: return "arrow.triangle.2.circlepath"
        }
    }

    private var updateTint: Color {
        switch updateState {
        case .current: return .green
        case .updateAvailable: return .accentColor
        case .developmentBuild: return .purple
        case .unavailable: return .orange
        case .notChecked, .checking: return .secondary
        }
    }
}
