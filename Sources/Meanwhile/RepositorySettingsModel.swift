import Foundation
import MeanwhileCore

@MainActor
final class RepositorySettingsModel: ObservableObject {
    @Published private(set) var includesAllRepositories: Bool
    @Published private(set) var selectedRepositories: Set<String>
    @Published private(set) var availableRepositories: [String] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?
    @Published private(set) var hotKey: HotKeyConfiguration?
    @Published private(set) var hotKeyRegistrationError: String?
    @Published private(set) var integrationHealth = AgentIntegrationHealth(
        state: .notInstalled,
        claudeHooksInstalled: false,
        codexHooksInstalled: false,
        claudeStatuslineConflict: false
    )
    @Published private(set) var integrationHealthError: String?
    @Published private(set) var integrationActionMessage: String?
    @Published private(set) var integrationActionIsError = false
    @Published private(set) var isInstallingIntegrations = false
    @Published private(set) var isCheckingHealth = false
    @Published private(set) var githubAuthenticationStatus: GitHubAuthenticationStatus = .notAuthenticated
    @Published private(set) var lastAgentEvent: AgentSessionState?
    @Published private(set) var recentSignals: [RecentSignal] = []

    var connectedRepositoryCount: Int {
        includesAllRepositories ? availableRepositories.count : selectedRepositories.count
    }

    var repositoryScopeDescription: String {
        if includesAllRepositories {
            return availableRepositories.isEmpty
                ? "All accessible repositories"
                : "All \(availableRepositories.count) accessible repositories"
        }

        if selectedRepositories.isEmpty {
            return "No repositories connected"
        }

        return "\(selectedRepositories.count) selected repositories"
    }

    var sourceHealthDescription: String {
        if isLoading {
            return "Refreshing repositories"
        }

        if errorMessage != nil {
            return "Refresh needs attention"
        }

        if availableRepositories.isEmpty {
            return "Waiting for GitHub"
        }

        return "Reviews and failing CI ready"
    }

    private let preferences: RepositoryPreferences
    private let hotKeyPreferences: HotKeyPreferences
    private let catalog: GitHubRepositoryCatalog
    private let authenticationChecker: GitHubAuthenticationChecker
    private let integrationInstaller: AgentIntegrationInstaller
    private let eventStore: AgentEventStore
    private let recentSignalStore: RecentSignalStore
    private let selectionDidChange: () -> Void
    private let hotKeyDidChange: (HotKeyConfiguration?) -> Void
    private let integrationDidInstall: (AgentIntegrationInstallResult) -> Void
    private var hasLoaded = false

    init(
        preferences: RepositoryPreferences,
        hotKeyPreferences: HotKeyPreferences,
        catalog: GitHubRepositoryCatalog = GitHubRepositoryCatalog(),
        authenticationChecker: GitHubAuthenticationChecker = GitHubAuthenticationChecker(),
        integrationInstaller: AgentIntegrationInstaller,
        eventStore: AgentEventStore,
        recentSignalStore: RecentSignalStore,
        selectionDidChange: @escaping () -> Void,
        hotKeyDidChange: @escaping (HotKeyConfiguration?) -> Void,
        integrationDidInstall: @escaping (AgentIntegrationInstallResult) -> Void
    ) {
        self.preferences = preferences
        self.hotKeyPreferences = hotKeyPreferences
        self.catalog = catalog
        self.authenticationChecker = authenticationChecker
        self.integrationInstaller = integrationInstaller
        self.eventStore = eventStore
        self.recentSignalStore = recentSignalStore
        self.selectionDidChange = selectionDidChange
        self.hotKeyDidChange = hotKeyDidChange
        self.integrationDidInstall = integrationDidInstall
        let snapshot = preferences.snapshot
        includesAllRepositories = snapshot.includesAllRepositories
        selectedRepositories = snapshot.selectedRepositories
        hotKey = hotKeyPreferences.hotKey
    }

    func loadRepositories(force: Bool = false) {
        guard !isLoading, force || !hasLoaded else { return }
        isLoading = true
        errorMessage = nil

        let catalog = self.catalog
        Task.detached {
            do {
                let repositories = try catalog.repositories()
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    availableRepositories = Array(
                        Set(repositories).union(selectedRepositories)
                    ).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                    hasLoaded = true
                    isLoading = false
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.errorMessage = error.localizedDescription
                    self?.isLoading = false
                }
            }
        }
    }

    func refreshStatus() {
        guard !isCheckingHealth else { return }
        isCheckingHealth = true
        let authenticationChecker = self.authenticationChecker
        let integrationInstaller = self.integrationInstaller
        let eventStore = self.eventStore
        let recentSignalStore = self.recentSignalStore

        Task.detached {
            let healthResult = Result { try integrationInstaller.health() }
            let authenticationStatus = authenticationChecker.status()
            let latestEvent = eventStore.latestEvent()
            let signals = recentSignalStore.signals
            await MainActor.run { [weak self] in
                guard let self else { return }
                switch healthResult {
                case .success(let health):
                    integrationHealth = health
                    integrationHealthError = nil
                case .failure(let error):
                    integrationHealth = AgentIntegrationHealth(
                        state: .needsReview,
                        claudeHooksInstalled: false,
                        codexHooksInstalled: false,
                        claudeStatuslineConflict: false
                    )
                    integrationHealthError = error.localizedDescription
                }
                githubAuthenticationStatus = authenticationStatus
                lastAgentEvent = latestEvent
                recentSignals = signals
                isCheckingHealth = false
            }
        }
    }

    func setIncludesAllRepositories(_ includesAll: Bool) {
        if !includesAll, selectedRepositories.isEmpty {
            selectedRepositories = Set(availableRepositories)
            preferences.setSelectedRepositories(selectedRepositories)
        }
        includesAllRepositories = includesAll
        preferences.setIncludesAllRepositories(includesAll)
        selectionDidChange()
    }

    func isSelected(_ repository: String) -> Bool {
        includesAllRepositories || selectedRepositories.contains(repository)
    }

    func setRepository(_ repository: String, isSelected: Bool) {
        if isSelected {
            selectedRepositories.insert(repository)
        } else {
            selectedRepositories.remove(repository)
        }
        preferences.setRepository(repository, isSelected: isSelected)
        selectionDidChange()
    }

    func setHotKey(_ hotKey: HotKeyConfiguration?) {
        hotKeyPreferences.setHotKey(hotKey)
        self.hotKey = hotKeyPreferences.hotKey
        hotKeyDidChange(self.hotKey)
    }

    func setHotKeyRegistrationError(_ message: String?) {
        hotKeyRegistrationError = message
    }

    func installIntegrations() {
        guard !isInstallingIntegrations else { return }
        isInstallingIntegrations = true
        integrationActionMessage = nil
        integrationActionIsError = false
        let installer = integrationInstaller
        Task.detached {
            let result = Result { try installer.install() }
            await MainActor.run { [weak self] in
                guard let self else { return }
                isInstallingIntegrations = false
                switch result {
                case .success(let installResult):
                    integrationDidInstall(installResult)
                    integrationHealth = AgentIntegrationHealth(
                        state: .installed,
                        claudeHooksInstalled: installResult.claudeHooksInstalled,
                        codexHooksInstalled: installResult.codexHooksInstalled,
                        claudeStatuslineConflict: installResult.claudeStatuslineConflict
                    )
                    integrationHealthError = nil
                    integrationActionMessage = installResult.claudeStatuslineConflict
                        ? "Hooks installed. Your existing Claude status line was preserved."
                        : "Claude and Codex hooks are installed."
                    integrationActionIsError = false
                    refreshStatus()
                case .failure(let error):
                    integrationActionMessage = error.localizedDescription
                    integrationActionIsError = true
                }
            }
        }
    }
}
