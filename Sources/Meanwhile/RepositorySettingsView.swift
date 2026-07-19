import MeanwhileCore
import SwiftUI

struct RepositorySettingsView: View {
    @ObservedObject var model: RepositorySettingsModel
    @AppStorage("settings.section.statusItem.expanded") private var isStatusItemExpanded = true
    @AppStorage("settings.section.connectionHealth.expanded") private var isConnectionHealthExpanded = true
    @AppStorage("settings.section.aboutSupport.expanded") private var isAboutSupportExpanded = true
    @AppStorage("settings.section.notifications.expanded") private var isNotificationsExpanded = true
    @AppStorage("settings.section.repositorySources.expanded") private var isRepositorySourcesExpanded = true
    @AppStorage("settings.section.recentSignals.expanded") private var isRecentSignalsExpanded = true
    @State private var searchText = ""
    @State private var now = Date()

    private var filteredRepositories: [String] {
        guard !searchText.isEmpty else { return model.availableRepositories }
        return model.availableRepositories.filter {
            $0.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var aboutSupportTrailing: String {
        switch model.updateState {
        case .updateAvailable(let version, _):
            return "\(version) available"
        case .unavailable:
            return "Check unavailable"
        case .checking:
            return "Checking"
        case .notChecked, .current, .developmentBuild:
            return "Version \(model.appVersion)"
        }
    }

    private var aboutSupportTrailingTint: Color {
        switch model.updateState {
        case .updateAvailable:
            return .accentColor
        case .unavailable:
            return .orange
        case .notChecked, .checking, .current, .developmentBuild:
            return Color(nsColor: .tertiaryLabelColor)
        }
    }

    private var notificationTrailing: String {
        let settings = model.needsYouNotificationSettings
        guard settings.isEnabled else { return "Off" }
        if model.isRequestingNotificationPermission { return "Requesting" }
        switch model.needsYouNotificationPermission {
        case .authorized: return "After \(settings.delay.shortLabel)"
        case .denied: return "Blocked"
        case .limited: return "Limited"
        case .unavailable: return "Unavailable"
        case .notDetermined, .unknown: return "Permission needed"
        }
    }

    private var notificationTrailingTint: Color {
        guard model.needsYouNotificationSettings.isEnabled else {
            return Color(nsColor: .tertiaryLabelColor)
        }
        switch model.needsYouNotificationPermission {
        case .denied, .limited, .unavailable:
            return .orange
        default:
            return Color(nsColor: .tertiaryLabelColor)
        }
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                CollapsibleSettingsSection(
                    title: "Status item",
                    isExpanded: $isStatusItemExpanded
                ) {
                    StatusItemSettingsSection(
                        repositoryScopeDescription: model.repositoryScopeDescription,
                        sourceHealthDescription: model.sourceHealthDescription,
                        sourceHasError: model.errorMessage != nil
                    )
                }
                Divider()
                ControlsSettingsSection(
                    hotKey: Binding(
                        get: { model.hotKey },
                        set: { model.setHotKey($0) }
                    ),
                    hotKeyRegistrationError: model.hotKeyRegistrationError,
                    setHotKeyRegistrationError: model.setHotKeyRegistrationError,
                    isInstallingIntegrations: model.isInstallingIntegrations,
                    integrationActionMessage: model.integrationActionMessage,
                    integrationActionIsError: model.integrationActionIsError,
                    installIntegrations: model.installIntegrations,
                    launchAtLoginStatus: model.launchAtLoginStatus,
                    launchAtLoginError: model.launchAtLoginError,
                    setLaunchAtLoginEnabled: { model.setLaunchAtLoginEnabled($0) },
                    openLoginItemsSettings: model.openLoginItemsSettings
                )
                Divider()
                CollapsibleSettingsSection(
                    title: "Notifications",
                    trailing: notificationTrailing,
                    trailingTint: notificationTrailingTint,
                    isExpanded: $isNotificationsExpanded,
                    showsProgress: model.isRequestingNotificationPermission
                ) {
                    NeedsYouNotificationSettingsSection(
                        settings: Binding(
                            get: { model.needsYouNotificationSettings },
                            set: { settings in
                                if settings.isEnabled
                                    != model.needsYouNotificationSettings.isEnabled {
                                    model.setNeedsYouNotificationsEnabled(settings.isEnabled)
                                }
                                if settings.delay != model.needsYouNotificationSettings.delay {
                                    model.setNeedsYouNotificationDelay(settings.delay)
                                }
                            }
                        ),
                        permission: model.needsYouNotificationPermission,
                        isRequestingPermission: model.isRequestingNotificationPermission,
                        requestPermission: model.requestNeedsYouNotificationPermission,
                        openSystemSettings: model.openNotificationSettings,
                        retryStatus: model.retryNotificationStatus
                    )
                }
                Divider()
                CollapsibleSettingsSection(
                    title: "About & support",
                    trailing: aboutSupportTrailing,
                    trailingTint: aboutSupportTrailingTint,
                    isExpanded: $isAboutSupportExpanded,
                    showsProgress: model.updateState == .checking
                ) {
                    AppSettingsSection(
                        appVersion: model.appVersion,
                        buildVersion: model.buildVersion,
                        updateState: model.updateState,
                        updateErrorMessage: model.updateErrorMessage,
                        checkForUpdates: model.checkForUpdates,
                        openLatestRelease: model.openLatestRelease,
                        diagnosticsCopyMessage: model.diagnosticsCopyMessage,
                        diagnosticsCopyIsError: model.diagnosticsCopyIsError,
                        copyDiagnostics: model.copyDiagnostics
                    )
                }
                Divider()
                CollapsibleSettingsSection(
                    title: "Connection health",
                    trailing: model.sessionInspection.stuckCount > 0
                        ? "\(model.sessionInspection.stuckCount) may be stuck"
                        : nil,
                    trailingTint: .orange,
                    isExpanded: $isConnectionHealthExpanded,
                    showsProgress: model.isCheckingHealth
                ) {
                    ConnectionHealthSection(
                        integrationHealth: model.integrationHealth,
                        integrationHealthError: model.integrationHealthError,
                        lastAgentEvent: model.lastAgentEvent,
                        githubAuthenticationStatus: model.githubAuthenticationStatus,
                        sessionInspection: model.sessionInspection,
                        sessionRecoveryMessage: model.sessionRecoveryMessage,
                        sessionRecoveryIsError: model.sessionRecoveryIsError,
                        isClearingStuckSessions: model.isClearingStuckSessions,
                        staleAfter: model.sessionStaleAfterDescription,
                        clearStuckSessions: model.clearStuckSessions,
                        now: now
                    )
                }
                Divider()
                CollapsibleSettingsSection(
                    title: "Repository sources",
                    trailing: model.availableRepositories.isEmpty
                        ? nil
                        : "\(filteredRepositories.count) shown",
                    isExpanded: $isRepositorySourcesExpanded
                ) {
                    RepositorySourcesSection(
                        searchText: $searchText,
                        includesAllRepositories: Binding(
                            get: { model.includesAllRepositories },
                            set: { model.setIncludesAllRepositories($0) }
                        ),
                        availableRepositories: model.availableRepositories,
                        filteredRepositories: filteredRepositories,
                        isLoading: model.isLoading,
                        errorMessage: model.errorMessage,
                        refresh: { model.loadRepositories(force: true) },
                        isSelected: model.isSelected,
                        setRepository: model.setRepository
                    )
                }
                Divider()
                CollapsibleSettingsSection(
                    title: "Recent signals",
                    isExpanded: $isRecentSignalsExpanded
                ) {
                    RecentSignalsSection(signals: model.recentSignals, now: now)
                }
            }
            .padding(.horizontal, 24)
            .padding(.vertical, 20)
        }
        .frame(width: 620, height: 680)
        .background(Color(nsColor: .windowBackgroundColor))
        .task {
            model.loadRepositories()
            model.refreshStatus()
            model.checkForUpdates()
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled else { break }
                now = Date()
                model.refreshStatus()
            }
        }
    }
}

private extension NeedsYouNotificationDelay {
    var shortLabel: String {
        switch self {
        case .oneMinute: return "1 min"
        case .fiveMinutes: return "5 min"
        case .fifteenMinutes: return "15 min"
        case .thirtyMinutes: return "30 min"
        }
    }
}
