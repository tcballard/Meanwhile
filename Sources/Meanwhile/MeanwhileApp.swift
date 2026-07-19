import AppKit
import MeanwhileCore
import Peripheral
import SwiftUI

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum DefaultsKey {
        static let integrationPrompted = "Meanwhile.agentIntegrationPrompted"
    }

    private static let statusItemBloomDuration: TimeInterval = 6

    private let repositoryPreferences = RepositoryPreferences()
    private let settingsWindowController = SettingsWindowController()
    private let terminalFocuser = TerminalFocuser()
    private let configuration = MeanwhileConfiguration.load()
    private let eventStore = AgentEventStore()
    private let recentSignalStore = RecentSignalStore()
    private let launchAtLoginController = LaunchAtLoginController()
    private let needsYouNotificationPreferences = NeedsYouNotificationPreferences()
    private lazy var attentionSourcePreferences = AttentionSourcePreferences(
        defaultSelection: AttentionSourceSelection(
            reviewsEnabled: configuration.enableReviews,
            failingCIEnabled: configuration.enableFailingCI
        )
    )
    private lazy var integrationInstaller = AgentIntegrationInstaller(helperURL: helperURL())
    private lazy var hotKeyPreferences = HotKeyPreferences(defaultHotKey: configuration.hotKey)
    private lazy var needsYouNotificationController = NeedsYouNotificationController()
    private var menuBar: MenuBarController<EmptyView>?
    private var runtime: MeanwhileRuntime?
    private var currentItem: WorkItem?
    private var openItemMenuItem: NSMenuItem?
    private var snoozeMenuItem: NSMenuItem?
    private var hideMenuItem: NSMenuItem?
    private var hotKey: GlobalHotKey?
    private var lastRecordedItemID: String?
    private var latestPresentation: MeanwhilePresentation?
    private var bloomState = StatusItemBloomState()
    private var needsYouNotificationState = NeedsYouNotificationState()
    private var bloomExpirationWorkItem: DispatchWorkItem?
    private var pendingBloomSettlement = false
    private var attentionTestState = AttentionTestState()
    private var attentionTestExpirationWorkItem: DispatchWorkItem?
    private lazy var agentFocusRouter = AgentFocusRouter(
        focusTerminal: { [terminalFocuser] session in
            terminalFocuser.focus(session)
        }
    )
    private lazy var settingsModel = RepositorySettingsModel(
        preferences: repositoryPreferences,
        hotKeyPreferences: hotKeyPreferences,
        integrationInstaller: integrationInstaller,
        eventStore: eventStore,
        recentSignalStore: recentSignalStore,
        notificationPreferences: needsYouNotificationPreferences,
        attentionSourcePreferences: attentionSourcePreferences,
        notificationController: needsYouNotificationController,
        sessionStaleAfter: configuration.sessionStaleSeconds,
        appVersion: Bundle.main.object(
            forInfoDictionaryKey: "CFBundleShortVersionString"
        ) as? String ?? "Unknown",
        buildVersion: Bundle.main.object(
            forInfoDictionaryKey: "CFBundleVersion"
        ) as? String ?? "Unknown",
        operatingSystemVersion: ProcessInfo.processInfo.operatingSystemVersionString,
        launchAtLoginStatus: { [launchAtLoginController] in
            launchAtLoginController.status
        },
        setLaunchAtLoginEnabled: { [launchAtLoginController] enabled in
            try launchAtLoginController.setEnabled(enabled)
        },
        openLoginItemsSettings: { [launchAtLoginController] in
            launchAtLoginController.openSystemSettings()
        },
        copyText: { text in
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            return pasteboard.setString(text, forType: .string)
        },
        openURL: { url in
            NSWorkspace.shared.open(url)
        },
        selectionDidChange: { [weak self] in
            self?.runtime?.repositorySelectionDidChange()
        },
        hotKeyDidChange: { [weak self] _ in
            self?.registerHotKeyFromPreferences()
        },
        integrationDidInstall: { [weak self] _ in
            guard let self else { return }
            UserDefaults.standard.set(true, forKey: DefaultsKey.integrationPrompted)
            recentSignalStore.record(
                RecentSignal(
                    kind: .integrationsInstalled,
                    title: "Agent integrations installed",
                    detail: "Claude and Codex"
                )
            )
        },
        notificationSettingsDidChange: { [weak self] in
            self?.reconcileNeedsYouNotification()
        },
        runAttentionTest: { [weak self] completion in
            self?.runAttentionTest(completion: completion)
        },
        sourceRefreshSnapshot: { [weak self] in
            self?.runtime?.sourceRefreshSnapshot
                ?? SourceRefreshSnapshot(
                    reviewsEnabled: self?.attentionSourcePreferences.selection.reviewsEnabled ?? true,
                    failingCIEnabled: self?.attentionSourcePreferences.selection.failingCIEnabled ?? true
                )
        },
        refreshSources: { [weak self] completion in
            self?.runtime?.refreshSources(completion: completion)
        },
        sourceSelectionDidChange: { [weak self] selection in
            self?.runtime?.sourceSelectionDidChange(selection)
        }
    )

    func applicationWillFinishLaunching(_ notification: Notification) {
        needsYouNotificationController.onPermissionChange = { [weak self] permission in
            guard let self else { return }
            settingsModel.setNeedsYouNotificationPermission(permission)
            reconcileNeedsYouNotification()
        }
        needsYouNotificationController.onResponse = { [weak self] identifier in
            self?.handleNeedsYouNotificationResponse(identifier: identifier)
        }
        needsYouNotificationController.onTestResponse = { [weak self] in
            self?.openSettings()
        }
        needsYouNotificationController.start()
        if !needsYouNotificationPreferences.settings.isEnabled {
            needsYouNotificationController.cancelAllManaged()
        }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        let contextMenu = makeContextMenu()
        let menuBar = MenuBarController(
            systemImageName: MenuBarPresenter.idleIconName,
            onClick: { [weak self] in self?.openCurrentItem() },
            contextMenu: contextMenu
        ) {
            EmptyView()
        }
        menuBar.statusItem.length = NSStatusItem.squareLength
        menuBar.statusItem.button?.toolTip = "Meanwhile — waiting for an agent event"
        menuBar.setAccessibility(label: "Meanwhile, idle")
        menuBar.onContextMenuClose = { [weak self] in
            self?.settleBloomAfterContextMenuIfNeeded()
        }
        self.menuBar = menuBar

        let preferences = repositoryPreferences
        let reviewSource = GitHubReviewSource(
            repositoryIsAllowed: { preferences.allows(repository: $0) }
        )
        let ciSource = GitHubCISource(
            repositoryIsAllowed: { preferences.allows(repository: $0) }
        )
        let runtime = MeanwhileRuntime(
            eventStore: eventStore,
            reviewSource: reviewSource,
            ciSource: ciSource,
            configuration: configuration,
            sourceSelection: attentionSourcePreferences.selection
        ) { [weak self] presentation in
            Task { @MainActor [weak self] in self?.present(presentation) }
        }
        self.runtime = runtime
        runtime.start()
        registerHotKeyFromPreferences()

        DispatchQueue.main.async { [weak self] in
            self?.showFirstRunSettingsIfNeeded()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        bloomExpirationWorkItem?.cancel()
        attentionTestExpirationWorkItem?.cancel()
        runtime?.stop()
    }

    func applicationDidBecomeActive(_ notification: Notification) {
        needsYouNotificationController.refreshPermission()
    }

    private func present(_ presentation: MeanwhilePresentation) {
        latestPresentation = presentation
        currentItem = presentation.item
        recordPresentationIfNeeded(presentation.item)
        reconcileNeedsYouNotification(presentation)
        if attentionTestState.observeRealAttention(isActive: presentation.item != nil) == .preempted {
            attentionTestExpirationWorkItem?.cancel()
            attentionTestExpirationWorkItem = nil
            settingsModel.attentionTestDidEnd()
        }
        if attentionTestState.isActive { return }
        let transition = bloomState.observe(
            phase: presentation.phase,
            item: presentation.item
        )
        switch transition {
        case .none:
            if pendingBloomSettlement,
               menuBar?.isContextMenuTracking == true {
                return
            }
            pendingBloomSettlement = false
            render(presentation, isBlooming: bloomState.isActive)
        case .start(let itemID, let generation):
            bloomExpirationWorkItem?.cancel()
            pendingBloomSettlement = false
            render(presentation, isBlooming: true)
            announceCurrentAttention(presentation)
            scheduleBloomExpiration(itemID: itemID, generation: generation)
        case .cancel:
            bloomExpirationWorkItem?.cancel()
            bloomExpirationWorkItem = nil
            pendingBloomSettlement = false
            render(presentation, isBlooming: false)
        }
    }

    private func render(
        _ presentation: MeanwhilePresentation,
        isBlooming: Bool
    ) {
        let statusText = isBlooming
            ? MenuBarPresenter.bloomText(item: presentation.item)
            : MenuBarPresenter.statusText(item: presentation.item)
        menuBar?.setTitle(statusText)
        menuBar?.statusItem.length = statusText == nil
            ? NSStatusItem.squareLength
            : NSStatusItem.variableLength
        let iconColor: NSColor?
        switch presentation.phase {
        case .idle: iconColor = nil
        case .thinking: iconColor = .systemOrange
        case .needsYou: iconColor = .systemRed
        }
        menuBar?.setIcon(
            systemName: MenuBarPresenter.iconName(phase: presentation.phase),
            accessibilityDescription: nil,
            tintColor: iconColor
        )
        menuBar?.setAccessibility(
            label: MenuBarPresenter.accessibilityLabel(
                phase: presentation.phase,
                item: presentation.item
            ),
            help: MenuBarPresenter.accessibilityHelp(
                phase: presentation.phase,
                item: presentation.item
            )
        )
        menuBar?.statusItem.button?.toolTip = MenuBarPresenter.tooltip(
            phase: presentation.phase,
            item: presentation.item
        )
        updateItemMenu(presentation.item)
    }

    private func scheduleBloomExpiration(itemID: String, generation: UInt64) {
        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                self?.expireBloom(itemID: itemID, generation: generation)
            }
        }
        bloomExpirationWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.statusItemBloomDuration,
            execute: workItem
        )
    }

    private func expireBloom(itemID: String, generation: UInt64) {
        guard bloomState.expire(itemID: itemID, generation: generation) else { return }
        bloomExpirationWorkItem = nil
        guard menuBar?.isContextMenuTracking != true else {
            pendingBloomSettlement = true
            return
        }
        if let latestPresentation {
            render(latestPresentation, isBlooming: false)
        }
    }

    private func settleBloomAfterContextMenuIfNeeded() {
        guard pendingBloomSettlement else { return }
        pendingBloomSettlement = false
        if let latestPresentation {
            render(latestPresentation, isBlooming: bloomState.isActive)
        }
    }

    private func settleBloomBeforeAction() {
        bloomExpirationWorkItem?.cancel()
        bloomExpirationWorkItem = nil
        pendingBloomSettlement = false
        guard bloomState.settle(), let latestPresentation else { return }
        render(latestPresentation, isBlooming: false)
    }

    private func announceCurrentAttention(_ presentation: MeanwhilePresentation) {
        let label = MenuBarPresenter.accessibilityLabel(
            phase: presentation.phase,
            item: presentation.item
        )
        menuBar?.announce(label)
    }

    private func updateItemMenu(_ item: WorkItem?) {
        openItemMenuItem?.title = item.map(MenuBarPresenter.openActionTitle(item:))
            ?? "No Item Available"
        openItemMenuItem?.isEnabled = item != nil
        snoozeMenuItem?.isEnabled = item != nil
        hideMenuItem?.isEnabled = item != nil
    }

    private func makeContextMenu() -> NSMenu {
        let menu = NSMenu()
        let openItem = NSMenuItem(
            title: "No Item Available",
            action: #selector(openCurrentItem),
            keyEquivalent: ""
        )
        openItem.target = self
        openItem.isEnabled = false
        openItemMenuItem = openItem
        menu.addItem(openItem)

        let snooze = NSMenuItem(
            title: "Snooze for 15 Minutes",
            action: #selector(snoozeCurrentItem),
            keyEquivalent: ""
        )
        snooze.target = self
        snooze.isEnabled = false
        snoozeMenuItem = snooze
        menu.addItem(snooze)

        let hide = NSMenuItem(
            title: "Hide Until It Changes",
            action: #selector(hideCurrentItemUntilChange),
            keyEquivalent: ""
        )
        hide.target = self
        hide.isEnabled = false
        hideMenuItem = hide
        menu.addItem(hide)
        menu.addItem(.separator())

        let settings = NSMenuItem(
            title: "Settings…",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settings.image = NSImage(systemSymbolName: "gearshape", accessibilityDescription: nil)
        settings.target = self
        menu.addItem(settings)

        let quit = NSMenuItem(
            title: "Quit Meanwhile",
            action: #selector(quitMeanwhile),
            keyEquivalent: "q"
        )
        quit.image = NSImage(systemSymbolName: "power", accessibilityDescription: nil)
        quit.target = self
        menu.addItem(quit)
        return menu
    }

    @objc private func openCurrentItem() {
        if attentionTestState.isActive {
            openSettings()
            return
        }
        guard let item = currentItem else { return }
        settleBloomBeforeAction()
        cancelNeedsYouNotification(for: item)
        open(item)
    }

    private func open(_ item: WorkItem) {
        if item.kind == .needsYou, let session = item.session {
            if agentFocusRouter.focus(session) == .unavailable {
                showFocusFailure(for: item)
            }
        } else if let url = MenuBarPresenter.destinationURL(item: item) {
            if !NSWorkspace.shared.open(url) {
                showLinkFailure(for: item, url: url)
            }
        }
    }

    private func showLinkFailure(for _: WorkItem, url: URL) {
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Couldn’t open this GitHub item"
        alert.informativeText = "The interruption is still active. Copy the link and open it in a browser when you’re ready."
        alert.addButton(withTitle: "Copy Link")
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            let pasteboard = NSPasteboard.general
            pasteboard.clearContents()
            _ = pasteboard.setString(url.absoluteString, forType: .string)
        }
    }

    private func showFocusFailure(for item: WorkItem) {
        let provider = item.session.map { providerDisplayName($0.provider) } ?? "agent"
        let alert = NSAlert()
        alert.alertStyle = .warning
        alert.messageText = "Couldn’t return to \(provider)"
        if item.session?.provider == .codex {
            alert.informativeText = """
            Meanwhile couldn’t open this task in Codex or focus its original terminal. \
            The interruption is still active.
            """
        } else {
            alert.informativeText = """
            Meanwhile couldn’t focus this task’s original terminal. \
            The interruption is still active.
            """
        }
        alert.addButton(withTitle: "Open Settings")
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            openSettings()
        }
    }

    private func registerHotKeyFromPreferences() {
        hotKey = nil
        settingsModel.setHotKeyRegistrationError(nil)
        guard let hotKeyConfiguration = hotKeyPreferences.hotKey else { return }
        do {
            hotKey = try GlobalHotKey(configuration: hotKeyConfiguration) { [weak self] in
                self?.openCurrentItem()
            }
        } catch {
            settingsModel.setHotKeyRegistrationError(error.localizedDescription)
        }
    }

    @objc private func snoozeCurrentItem() {
        settleBloomBeforeAction()
        if let item = currentItem {
            cancelNeedsYouNotification(for: item)
            recentSignalStore.record(
                RecentSignal(
                    kind: .snoozed,
                    title: "Snoozed for 15 minutes",
                    detail: item.title
                )
            )
        }
        runtime?.snoozeCurrent()
    }

    @objc private func hideCurrentItemUntilChange() {
        settleBloomBeforeAction()
        if let item = currentItem {
            cancelNeedsYouNotification(for: item)
            recentSignalStore.record(
                RecentSignal(
                    kind: .hiddenUntilChange,
                    title: "Hidden until it changes",
                    detail: item.title
                )
            )
        }
        runtime?.dismissCurrent()
    }

    private func reconcileNeedsYouNotification(
        _ presentation: MeanwhilePresentation? = nil
    ) {
        guard let presentation = presentation ?? latestPresentation else { return }
        let settings = needsYouNotificationPreferences.settings
        let permission = needsYouNotificationController.permission
        if let item = presentation.item, item.kind == .needsYou {
            let identifier = NeedsYouNotificationController.identifier(for: item.id)
            if needsYouNotificationPreferences.containsReceipt(identifier: identifier) {
                needsYouNotificationState.restoreReceipt(itemID: item.id)
            }
        }
        if !settings.isEnabled {
            needsYouNotificationController.retainOnly(itemID: nil)
        } else if permission != .unknown {
            let eligibleItemID = permission == .authorized
                && presentation.phase == .needsYou
                && presentation.item?.kind == .needsYou
                ? presentation.item?.id
                : nil
            needsYouNotificationController.retainOnly(itemID: eligibleItemID)
        }
        let transition = needsYouNotificationState.observe(
            settings: settings,
            permission: permission,
            phase: presentation.phase,
            item: presentation.item
        )
        switch transition {
        case .none:
            break
        case .deliver(let item):
            deliverNeedsYouNotification(item)
        case .replace(let previousItemID, let delivery):
            needsYouNotificationController.cancel(itemID: previousItemID)
            if let delivery {
                deliverNeedsYouNotification(delivery)
            }
        case .cancel(let itemID):
            needsYouNotificationController.cancel(itemID: itemID)
        }
    }

    private func cancelNeedsYouNotification(for item: WorkItem) {
        guard item.kind == .needsYou else { return }
        needsYouNotificationPreferences.recordReceipt(
            identifier: NeedsYouNotificationController.identifier(for: item.id)
        )
        let transition = needsYouNotificationState.acknowledge(itemID: item.id)
        if case .cancel(let itemID) = transition {
            needsYouNotificationController.cancel(itemID: itemID)
        }
    }

    private func deliverNeedsYouNotification(_ item: WorkItem) {
        guard let title = MenuBarPresenter.notificationTitle(item: item) else { return }
        let identifier = NeedsYouNotificationController.identifier(for: item.id)
        needsYouNotificationController.deliver(
            identifier: identifier,
            title: title
        ) { [weak self] outcome in
            switch outcome {
            case .delivered:
                self?.needsYouNotificationPreferences.recordReceipt(identifier: identifier)
            case .failed:
                self?.needsYouNotificationState.deliveryFailed(
                    itemID: item.id,
                    retryNotBefore: Date().addingTimeInterval(60)
                )
            case .cancelled:
                break
            }
        }
    }

    private func handleNeedsYouNotificationResponse(identifier: String) {
        let current = currentItem.flatMap { item -> WorkItem? in
            guard item.kind == .needsYou,
                  NeedsYouNotificationController.identifier(for: item.id) == identifier else {
                return nil
            }
            return item
        }
        if let current {
            settleBloomBeforeAction()
            cancelNeedsYouNotification(for: current)
            open(current)
            return
        }

        let session = eventStore.sessions(
            staleAfter: configuration.sessionStaleSeconds,
            activeStaleAfter: configuration.activeSessionStaleSeconds
        ).first { session in
            session.phase == .needsYou
                && NeedsYouNotificationController.identifier(
                    for: WorkItem.needsYouID(for: session)
                ) == identifier
        }
        guard let session else {
            showExpiredNotificationMessage()
            return
        }
        let item = WorkItem(
            id: WorkItem.needsYouID(for: session),
            kind: .needsYou,
            title: "\(providerDisplayName(session.provider)) needs you",
            detail: session.cwd,
            createdAt: session.enteredAt,
            session: session
        )
        cancelNeedsYouNotification(for: item)
        open(item)
    }

    private func showExpiredNotificationMessage() {
        let alert = NSAlert()
        alert.alertStyle = .informational
        alert.messageText = "That task is no longer waiting"
        alert.informativeText = "Meanwhile did not open a different task."
        alert.addButton(withTitle: "OK")
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func showFirstRunSettingsIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: DefaultsKey.integrationPrompted) else { return }
        UserDefaults.standard.set(true, forKey: DefaultsKey.integrationPrompted)
        openSettings()
    }

    private func helperURL() -> URL {
        let bundled = Bundle.main.bundleURL
            .appendingPathComponent("Contents/Helpers/MeanwhileHook")
        if FileManager.default.isExecutableFile(atPath: bundled.path) { return bundled }
        return Bundle.main.executableURL?
            .deletingLastPathComponent()
            .appendingPathComponent("MeanwhileHook") ?? bundled
    }

    @objc private func openSettings() {
        settingsModel.refreshStatus()
        settingsWindowController.show(model: settingsModel)
    }

    private func recordPresentationIfNeeded(_ item: WorkItem?) {
        guard item?.id != lastRecordedItemID else { return }
        lastRecordedItemID = item?.id
        guard let item else { return }

        let signal: RecentSignal
        switch item.kind {
        case .needsYou:
            signal = RecentSignal(
                kind: .agentNeedsYou,
                title: MenuBarPresenter.attentionText(item: item),
                detail: item.detail
            )
        case .review:
            signal = RecentSignal(
                kind: .reviewSurfaced,
                title: "\(item.title) surfaced",
                detail: item.detail
            )
        case .failingCI:
            signal = RecentSignal(
                kind: .ciFailed,
                title: "CI failure surfaced",
                detail: item.detail
            )
        }
        recentSignalStore.record(signal)
    }

    @objc private func quitMeanwhile() {
        NSApplication.shared.terminate(nil)
    }

    private func runAttentionTest(
        completion: @escaping (AttentionTestRunResult) -> Void
    ) {
        let realAttentionIsActive = currentItem != nil
        guard case .started(let generation) = attentionTestState.start(
            realAttentionIsActive: realAttentionIsActive
        ) else {
            completion(.blockedByRealAttention)
            return
        }

        attentionTestExpirationWorkItem?.cancel()
        renderAttentionTest()
        menuBar?.announce("Meanwhile attention test")

        let notificationsAvailable = needsYouNotificationPreferences.settings.isEnabled
            && needsYouNotificationController.permission == .authorized
        if notificationsAvailable {
            needsYouNotificationController.deliverTest { outcome in
                switch outcome {
                case .delivered: completion(.startedWithNotification)
                case .cancelled: completion(.startedMenuBarOnly)
                case .failed: completion(.failedNotification)
                }
            }
        } else {
            completion(.startedMenuBarOnly)
        }

        let workItem = DispatchWorkItem { [weak self] in
            Task { @MainActor [weak self] in
                guard let self,
                      self.attentionTestState.finish(generation: generation) == .finished else {
                    return
                }
                self.attentionTestExpirationWorkItem = nil
                self.settingsModel.attentionTestDidEnd()
                if let latestPresentation = self.latestPresentation {
                    self.render(latestPresentation, isBlooming: self.bloomState.isActive)
                }
            }
        }
        attentionTestExpirationWorkItem = workItem
        DispatchQueue.main.asyncAfter(
            deadline: .now() + Self.statusItemBloomDuration,
            execute: workItem
        )
    }

    private func renderAttentionTest() {
        menuBar?.setTitle("Test needs attention")
        menuBar?.statusItem.length = NSStatusItem.variableLength
        menuBar?.setIcon(
            systemName: MenuBarPresenter.iconName(phase: .needsYou),
            accessibilityDescription: nil,
            tintColor: .systemRed
        )
        menuBar?.setAccessibility(
            label: "Meanwhile attention test",
            help: "Click to return to Settings. This is not a real task."
        )
        menuBar?.statusItem.button?.toolTip = "Meanwhile attention test — click to return to Settings"
        openItemMenuItem?.title = "Return to Settings"
        openItemMenuItem?.isEnabled = true
        snoozeMenuItem?.isEnabled = false
        hideMenuItem?.isEnabled = false
    }
}

@main
private enum MeanwhileApp {
    @MainActor
    static func main() {
        let application = NSApplication.shared
        let delegate = AppDelegate()
        application.delegate = delegate
        application.run()
        withExtendedLifetime(delegate) {}
    }
}
