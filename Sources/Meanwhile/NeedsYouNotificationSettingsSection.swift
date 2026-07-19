import MeanwhileCore
import SwiftUI

struct NeedsYouNotificationSettingsSection: View {
    @Binding var settings: NeedsYouNotificationSettings
    let permission: NeedsYouNotificationPermission
    let isRequestingPermission: Bool
    let requestPermission: () -> Void
    let openSystemSettings: () -> Void
    let retryStatus: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            HStack(alignment: .top, spacing: 10) {
                Text("Needs-you reminders")
                    .frame(width: 132, alignment: .leading)

                Toggle("Notify when a task keeps waiting", isOn: $settings.isEnabled)
                    .labelsHidden()
                    .toggleStyle(.switch)
                    .accessibilityHint(
                        "Posts one notification if the same needs-you task is still waiting."
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(statusTitle)
                        .font(.callout.weight(.medium))
                    Text(statusDetail)
                        .font(.caption)
                        .foregroundStyle(statusNeedsAttention ? .orange : .secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 8)

                if settings.isEnabled {
                    if permission == .denied || permission == .limited {
                        Button("Open Notifications…", action: openSystemSettings)
                    } else if permission == .unavailable {
                        Button("Try Again", action: retryStatus)
                    } else if !isRequestingPermission,
                              permission == .notDetermined || permission == .unknown {
                        Button("Allow Notifications…", action: requestPermission)
                    }
                }
            }

            HStack(spacing: 10) {
                Text("Notify after")
                    .frame(width: 132, alignment: .leading)

                Picker("Notify after", selection: $settings.delay) {
                    ForEach(NeedsYouNotificationDelay.allCases, id: \.self) { delay in
                        Text(delay.label).tag(delay)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .frame(width: 132)
                .disabled(!settings.isEnabled)

                Text("Measured from when the task first needs you")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Text("One quiet reminder per waiting task. Reviews and failing CI never notify.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .padding(.leading, 142)
        }
    }

    private var statusTitle: String {
        if !settings.isEnabled { return "Off" }
        if isRequestingPermission { return "Requesting permission" }
        switch permission {
        case .authorized: return "One quiet reminder"
        case .notDetermined, .unknown: return "Permission needed"
        case .denied: return "Blocked by macOS"
        case .limited: return "Notification Center is off"
        case .unavailable: return "Status unavailable"
        }
    }

    private var statusDetail: String {
        if !settings.isEnabled {
            return "Menu bar only. Turn this on to ask macOS for permission."
        }
        if isRequestingPermission { return "Waiting for macOS permission." }
        switch permission {
        case .authorized:
            return "Notifies only while the same needs-you task is still waiting."
        case .notDetermined, .unknown:
            return "macOS permission is required before Meanwhile can notify."
        case .denied:
            return "Allow Meanwhile under Notifications in System Settings."
        case .limited:
            return "Turn on Notification Center delivery for Meanwhile."
        case .unavailable:
            return "Meanwhile couldn’t read notification settings."
        }
    }

    private var statusNeedsAttention: Bool {
        settings.isEnabled && (
            permission == .denied
                || permission == .limited
                || permission == .unavailable
        )
    }
}

private extension NeedsYouNotificationDelay {
    var label: String {
        switch self {
        case .oneMinute: return "1 minute"
        case .fiveMinutes: return "5 minutes"
        case .fifteenMinutes: return "15 minutes"
        case .thirtyMinutes: return "30 minutes"
        }
    }
}
