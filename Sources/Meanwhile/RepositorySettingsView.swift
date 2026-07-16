import MeanwhileCore
import SwiftUI

struct RepositorySettingsView: View {
    @ObservedObject var model: RepositorySettingsModel
    @AppStorage("settings.section.statusItem.expanded") private var isStatusItemExpanded = true
    @AppStorage("settings.section.connectionHealth.expanded") private var isConnectionHealthExpanded = true
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
                    hotKey: Binding(get: { model.hotKey }, set: model.setHotKey),
                    hotKeyRegistrationError: model.hotKeyRegistrationError,
                    setHotKeyRegistrationError: model.setHotKeyRegistrationError,
                    isInstallingIntegrations: model.isInstallingIntegrations,
                    integrationActionMessage: model.integrationActionMessage,
                    integrationActionIsError: model.integrationActionIsError,
                    installIntegrations: model.installIntegrations
                )
                Divider()
                CollapsibleSettingsSection(
                    title: "Connection health",
                    isExpanded: $isConnectionHealthExpanded,
                    showsProgress: model.isCheckingHealth
                ) {
                    ConnectionHealthSection(
                        integrationHealth: model.integrationHealth,
                        integrationHealthError: model.integrationHealthError,
                        lastAgentEvent: model.lastAgentEvent,
                        githubAuthenticationStatus: model.githubAuthenticationStatus,
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
                            set: model.setIncludesAllRepositories
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
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 30_000_000_000)
                guard !Task.isCancelled else { break }
                now = Date()
                model.refreshStatus()
            }
        }
    }
}
