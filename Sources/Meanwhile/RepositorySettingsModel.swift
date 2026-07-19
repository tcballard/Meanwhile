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
    @Published private(set) var launchAtLoginStatus: LaunchAtLoginStatus
    @Published private(set) var launchAtLoginError: String?
    @Published private(set) var updateState: ReleaseUpdateState = .notChecked
    @Published private(set) var updateErrorMessage: String?
    @Published private(set) var diagnosticsCopyMessage: String?
    @Published private(set) var diagnosticsCopyIsError = false
    @Published private(set) var sessionInspection = AgentSessionInspection.empty
    @Published private(set) var sessionRecoveryMessage: String?
    @Published private(set) var sessionRecoveryIsError = false
    @Published private(set) var isClearingStuckSessions = false
    @Published private(set) var needsYouNotificationSettings: NeedsYouNotificationSettings
    @Published private(set) var needsYouNotificationPermission: NeedsYouNotificationPermission
    @Published private(set) var isRequestingNotificationPermission = false
    @Published private(set) var attentionTestIsRunning = false
    @Published private(set) var attentionTestResult: AttentionTestRunResult?
    @Published private(set) var sourceRefreshSnapshot: SourceRefreshSnapshot
    @Published private(set) var githubLoginCopyMessage: String?
    @Published private(set) var attentionSourceSelection: AttentionSourceSelection

    let appVersion: String
    let buildVersion: String

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

    var sessionStaleAfterDescription: String {
        let minutes = max(1, Int(sessionStaleAfter / 60))
        if minutes.isMultiple(of: 60) {
            let hours = minutes / 60
            return hours == 1 ? "1 hour" : "\(hours) hours"
        }
        return minutes == 1 ? "1 minute" : "\(minutes) minutes"
    }

    private let preferences: RepositoryPreferences
    private let hotKeyPreferences: HotKeyPreferences
    private let catalog: GitHubRepositoryCatalog
    private let authenticationChecker: GitHubAuthenticationChecker
    private let integrationInstaller: AgentIntegrationInstaller
    private let eventStore: AgentEventStore
    private let recentSignalStore: RecentSignalStore
    private let notificationPreferences: NeedsYouNotificationPreferences
    private let attentionSourcePreferences: AttentionSourcePreferences
    private let notificationController: NeedsYouNotificationController
    private let releaseUpdateChecker: ReleaseUpdateChecker
    private let sessionStaleAfter: TimeInterval
    private let operatingSystemVersion: String
    private let launchAtLoginStatusProvider: () -> LaunchAtLoginStatus
    private let launchAtLoginSetter: (Bool) throws -> LaunchAtLoginStatus
    private let openLoginItemsSettingsAction: () -> Void
    private let copyText: (String) -> Bool
    private let openURL: (URL) -> Void
    private let selectionDidChange: () -> Void
    private let hotKeyDidChange: (HotKeyConfiguration?) -> Void
    private let integrationDidInstall: (AgentIntegrationInstallResult) -> Void
    private let notificationSettingsDidChange: () -> Void
    private let runAttentionTestAction: (@escaping (AttentionTestRunResult) -> Void) -> Void
    private let sourceRefreshSnapshotProvider: () -> SourceRefreshSnapshot
    private let refreshSourcesAction: (@escaping @Sendable (SourceRefreshSnapshot) -> Void) -> Void
    private let sourceSelectionDidChange: (AttentionSourceSelection) -> Void
    private var hasLoaded = false
    private var diagnosticsFeedbackID = UUID()

    init(
        preferences: RepositoryPreferences,
        hotKeyPreferences: HotKeyPreferences,
        catalog: GitHubRepositoryCatalog = GitHubRepositoryCatalog(),
        authenticationChecker: GitHubAuthenticationChecker = GitHubAuthenticationChecker(),
        integrationInstaller: AgentIntegrationInstaller,
        eventStore: AgentEventStore,
        recentSignalStore: RecentSignalStore,
        notificationPreferences: NeedsYouNotificationPreferences,
        attentionSourcePreferences: AttentionSourcePreferences,
        notificationController: NeedsYouNotificationController,
        releaseUpdateChecker: ReleaseUpdateChecker = ReleaseUpdateChecker(),
        sessionStaleAfter: TimeInterval,
        appVersion: String,
        buildVersion: String,
        operatingSystemVersion: String,
        launchAtLoginStatus: @escaping () -> LaunchAtLoginStatus,
        setLaunchAtLoginEnabled: @escaping (Bool) throws -> LaunchAtLoginStatus,
        openLoginItemsSettings: @escaping () -> Void,
        copyText: @escaping (String) -> Bool,
        openURL: @escaping (URL) -> Void,
        selectionDidChange: @escaping () -> Void,
        hotKeyDidChange: @escaping (HotKeyConfiguration?) -> Void,
        integrationDidInstall: @escaping (AgentIntegrationInstallResult) -> Void,
        notificationSettingsDidChange: @escaping () -> Void,
        runAttentionTest: @escaping (@escaping (AttentionTestRunResult) -> Void) -> Void,
        sourceRefreshSnapshot: @escaping () -> SourceRefreshSnapshot,
        refreshSources: @escaping (@escaping @Sendable (SourceRefreshSnapshot) -> Void) -> Void,
        sourceSelectionDidChange: @escaping (AttentionSourceSelection) -> Void
    ) {
        self.preferences = preferences
        self.hotKeyPreferences = hotKeyPreferences
        self.catalog = catalog
        self.authenticationChecker = authenticationChecker
        self.integrationInstaller = integrationInstaller
        self.eventStore = eventStore
        self.recentSignalStore = recentSignalStore
        self.notificationPreferences = notificationPreferences
        self.attentionSourcePreferences = attentionSourcePreferences
        self.notificationController = notificationController
        self.releaseUpdateChecker = releaseUpdateChecker
        self.sessionStaleAfter = sessionStaleAfter
        self.appVersion = appVersion
        self.buildVersion = buildVersion
        self.operatingSystemVersion = operatingSystemVersion
        launchAtLoginStatusProvider = launchAtLoginStatus
        launchAtLoginSetter = setLaunchAtLoginEnabled
        openLoginItemsSettingsAction = openLoginItemsSettings
        self.copyText = copyText
        self.openURL = openURL
        self.selectionDidChange = selectionDidChange
        self.hotKeyDidChange = hotKeyDidChange
        self.integrationDidInstall = integrationDidInstall
        self.notificationSettingsDidChange = notificationSettingsDidChange
        runAttentionTestAction = runAttentionTest
        sourceRefreshSnapshotProvider = sourceRefreshSnapshot
        refreshSourcesAction = refreshSources
        self.sourceSelectionDidChange = sourceSelectionDidChange
        let snapshot = preferences.snapshot
        includesAllRepositories = snapshot.includesAllRepositories
        selectedRepositories = snapshot.selectedRepositories
        hotKey = hotKeyPreferences.hotKey
        self.launchAtLoginStatus = launchAtLoginStatus()
        needsYouNotificationSettings = notificationPreferences.settings
        needsYouNotificationPermission = notificationController.permission
        self.sourceRefreshSnapshot = sourceRefreshSnapshot()
        attentionSourceSelection = attentionSourcePreferences.selection
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
        notificationController.refreshPermission()
        isCheckingHealth = true
        let authenticationChecker = self.authenticationChecker
        let integrationInstaller = self.integrationInstaller
        let eventStore = self.eventStore
        let recentSignalStore = self.recentSignalStore
        let sessionStaleAfter = self.sessionStaleAfter

        Task.detached {
            let healthResult = Result { try integrationInstaller.health() }
            let authenticationStatus = authenticationChecker.status()
            let latestEvent = eventStore.latestEvent()
            let signals = recentSignalStore.signals
            let sessionInspection = eventStore.inspectSessions(staleAfter: sessionStaleAfter)
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
                if self.sessionInspection != sessionInspection {
                    sessionRecoveryMessage = nil
                    sessionRecoveryIsError = false
                }
                self.sessionInspection = sessionInspection
                launchAtLoginStatus = launchAtLoginStatusProvider()
                sourceRefreshSnapshot = sourceRefreshSnapshotProvider()
                isCheckingHealth = false
            }
        }
    }

    func runAttentionTest() {
        guard !attentionTestIsRunning else { return }
        attentionTestIsRunning = true
        attentionTestResult = nil
        runAttentionTestAction { [weak self] result in
            Task { @MainActor [weak self] in
                self?.attentionTestResult = result
                if result == .blockedByRealAttention {
                    self?.attentionTestIsRunning = false
                }
            }
        }
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 6_500_000_000)
            self?.attentionTestIsRunning = false
        }
    }

    func attentionTestDidEnd() {
        attentionTestIsRunning = false
    }

    func refreshGitHubSources() {
        let now = Date()
        sourceRefreshSnapshot = sourceRefreshSnapshotProvider()
        sourceRefreshSnapshot.reviews.begin(at: now)
        sourceRefreshSnapshot.failingCI.begin(at: now)
        refreshSourcesAction { [weak self] snapshot in
            Task { @MainActor [weak self] in
                self?.sourceRefreshSnapshot = snapshot
                self?.refreshStatus()
            }
        }
    }

    func setAttentionSourceSelection(_ selection: AttentionSourceSelection) {
        if selection.reviewsEnabled != attentionSourceSelection.reviewsEnabled {
            attentionSourcePreferences.setReviewsEnabled(selection.reviewsEnabled)
        }
        if selection.failingCIEnabled != attentionSourceSelection.failingCIEnabled {
            attentionSourcePreferences.setFailingCIEnabled(selection.failingCIEnabled)
        }
        attentionSourceSelection = attentionSourcePreferences.selection
        sourceSelectionDidChange(attentionSourceSelection)
        sourceRefreshSnapshot.reviews.isEnabled = attentionSourceSelection.reviewsEnabled
        sourceRefreshSnapshot.failingCI.isEnabled = attentionSourceSelection.failingCIEnabled
        if !attentionSourceSelection.reviewsEnabled {
            sourceRefreshSnapshot.reviews.isRefreshing = false
        }
        if !attentionSourceSelection.failingCIEnabled {
            sourceRefreshSnapshot.failingCI.isRefreshing = false
        }
    }

    func copyGitHubLoginCommand() {
        githubLoginCopyMessage = copyText("gh auth login")
            ? "Copied `gh auth login` to the clipboard."
            : "Meanwhile could not copy the login command."
        let message = githubLoginCopyMessage
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard self?.githubLoginCopyMessage == message else { return }
            self?.githubLoginCopyMessage = nil
        }
    }

    func checkForUpdates() {
        guard updateState != .checking else { return }
        updateState = .checking
        updateErrorMessage = nil
        let checker = releaseUpdateChecker
        let currentVersion = appVersion

        Task.detached {
            let result = Result {
                try checker.check(currentVersion: currentVersion)
            }
            await MainActor.run { [weak self] in
                guard let self else { return }
                switch result {
                case .success(let state):
                    updateState = state
                case .failure(let error):
                    updateState = .unavailable
                    updateErrorMessage = (
                        error as? ReleaseUpdateCheckerError
                    )?.localizedDescription
                        ?? "Could not check GitHub releases. Confirm the GitHub CLI is installed and authenticated."
                }
            }
        }
    }

    func setLaunchAtLoginEnabled(_ enabled: Bool) {
        launchAtLoginError = nil
        do {
            launchAtLoginStatus = try launchAtLoginSetter(enabled)
        } catch {
            launchAtLoginStatus = launchAtLoginStatusProvider()
            launchAtLoginError =
                "Meanwhile could not change this Login Item. Open Login Items in System Settings and try again."
        }
    }

    func openLoginItemsSettings() {
        openLoginItemsSettingsAction()
    }

    func setNeedsYouNotificationsEnabled(_ enabled: Bool) {
        notificationPreferences.setEnabled(enabled)
        needsYouNotificationSettings = notificationPreferences.settings
        notificationSettingsDidChange()

        guard enabled,
              !isRequestingNotificationPermission,
              needsYouNotificationPermission == .notDetermined
                || needsYouNotificationPermission == .unknown else { return }
        requestNeedsYouNotificationPermission()
    }

    func setNeedsYouNotificationDelay(_ delay: NeedsYouNotificationDelay) {
        notificationPreferences.setDelay(delay)
        needsYouNotificationSettings = notificationPreferences.settings
        notificationSettingsDidChange()
    }

    func setNeedsYouNotificationPermission(_ permission: NeedsYouNotificationPermission) {
        needsYouNotificationPermission = permission
        isRequestingNotificationPermission = false
    }

    func openNotificationSettings() {
        notificationController.openSystemSettings()
    }

    func requestNeedsYouNotificationPermission() {
        guard needsYouNotificationSettings.isEnabled,
              !isRequestingNotificationPermission,
              needsYouNotificationPermission == .notDetermined
                || needsYouNotificationPermission == .unknown else { return }
        isRequestingNotificationPermission = true
        notificationController.requestPermission()
    }

    func retryNotificationStatus() {
        notificationController.refreshPermission()
    }

    func openLatestRelease() {
        guard let releaseURL = updateState.releaseURL else { return }
        openURL(releaseURL)
    }

    func clearStuckSessions() {
        guard !isClearingStuckSessions, sessionInspection.stuckCount > 0 else { return }
        isClearingStuckSessions = true
        sessionRecoveryMessage = nil
        sessionRecoveryIsError = false
        let eventStore = self.eventStore
        let staleAfter = sessionStaleAfter

        Task.detached {
            let result = Result {
                try eventStore.clearStuckSessions(staleAfter: staleAfter)
            }
            let inspection = eventStore.inspectSessions(staleAfter: staleAfter)
            await MainActor.run { [weak self] in
                guard let self else { return }
                isClearingStuckSessions = false
                sessionInspection = inspection
                switch result {
                case .success(let count):
                    let message = count == 1
                        ? "Cleared 1 stuck session."
                        : "Cleared \(count) stuck sessions."
                    sessionRecoveryMessage = message
                    Task { [weak self] in
                        try? await Task.sleep(nanoseconds: 3_000_000_000)
                        guard self?.sessionRecoveryMessage == message else { return }
                        self?.sessionRecoveryMessage = nil
                    }
                case .failure:
                    sessionRecoveryMessage = "Meanwhile could not clear every stuck session."
                    sessionRecoveryIsError = true
                }
            }
        }
    }

    func copyDiagnostics() {
        let snapshot = DiagnosticsSnapshot(
            appVersion: appVersion,
            buildVersion: buildVersion,
            operatingSystemVersion: operatingSystemVersion,
            launchAtLoginStatus: launchAtLoginStatus,
            updateState: updateState,
            integrationHealth: integrationHealth,
            githubAuthenticationStatus: githubAuthenticationStatus,
            repositoryScopeIncludesAll: includesAllRepositories,
            accessibleRepositoryCount: availableRepositories.count,
            selectedRepositoryCount: selectedRepositories.count,
            attentionSourceSelection: attentionSourceSelection,
            hotKeyConfigured: hotKey != nil,
            sessionInspection: sessionInspection,
            lastAgentEvent: lastAgentEvent,
            recentSignals: recentSignals
        )
        let copied = copyText(MeanwhileDiagnosticsReport.make(snapshot: snapshot))
        let feedbackID = UUID()
        diagnosticsFeedbackID = feedbackID
        diagnosticsCopyMessage = copied ? "Copied" : "Try Again"
        diagnosticsCopyIsError = !copied
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard self?.diagnosticsFeedbackID == feedbackID else { return }
            self?.diagnosticsCopyMessage = nil
            self?.diagnosticsCopyIsError = false
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
