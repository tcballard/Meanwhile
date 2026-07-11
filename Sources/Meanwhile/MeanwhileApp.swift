import AppKit
import MeanwhileCore
import Peripheral
import SwiftUI

@MainActor
private final class AppDelegate: NSObject, NSApplicationDelegate {
    private enum DefaultsKey {
        static let integrationPrompted = "Meanwhile.agentIntegrationPrompted"
    }

    private let repositoryPreferences = RepositoryPreferences()
    private let settingsWindowController = SettingsWindowController()
    private let terminalFocuser = TerminalFocuser()
    private var menuBar: MenuBarController<EmptyView>?
    private var runtime: MeanwhileRuntime?
    private var currentItem: WorkItem?
    private var openItemMenuItem: NSMenuItem?
    private var snoozeMenuItem: NSMenuItem?
    private var dismissMenuItem: NSMenuItem?
    private lazy var settingsModel = RepositorySettingsModel(
        preferences: repositoryPreferences,
        selectionDidChange: { [weak self] in
            self?.runtime?.repositorySelectionDidChange()
        }
    )

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
        self.menuBar = menuBar

        let preferences = repositoryPreferences
        let reviewSource = GitHubReviewSource(
            repositoryIsAllowed: { preferences.allows(repository: $0) }
        )
        let ciSource = GitHubCISource(
            repositoryIsAllowed: { preferences.allows(repository: $0) }
        )
        let runtime = MeanwhileRuntime(
            reviewSource: reviewSource,
            ciSource: ciSource
        ) { [weak self] presentation in
            Task { @MainActor [weak self] in self?.present(presentation) }
        }
        self.runtime = runtime
        runtime.start()

        DispatchQueue.main.async { [weak self] in
            self?.offerAgentIntegrationIfNeeded()
        }
    }

    func applicationWillTerminate(_ notification: Notification) {
        runtime?.stop()
    }

    private func present(_ presentation: MeanwhilePresentation) {
        currentItem = presentation.item
        let statusText = MenuBarPresenter.statusText(item: presentation.item)
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
            accessibilityDescription: accessibilityDescription(for: presentation),
            tintColor: iconColor
        )
        menuBar?.statusItem.button?.toolTip = tooltip(for: presentation)
        updateItemMenu(presentation.item)
    }

    private func updateItemMenu(_ item: WorkItem?) {
        openItemMenuItem?.title = item.map { item in
            switch item.kind {
            case .review, .failingCI:
                return "Open \(item.title) — \(item.detail)"
            case .needsYou:
                return "Open \(item.title)"
            }
        } ?? "No Item Available"
        openItemMenuItem?.isEnabled = item != nil
        snoozeMenuItem?.isEnabled = item != nil
        dismissMenuItem?.isEnabled = item != nil
    }

    private func accessibilityDescription(for presentation: MeanwhilePresentation) -> String {
        switch presentation.phase {
        case .idle: return "Meanwhile — idle"
        case .thinking: return "Meanwhile — agent thinking"
        case .needsYou: return "Meanwhile — agent needs you"
        }
    }

    private func tooltip(for presentation: MeanwhilePresentation) -> String {
        if let item = presentation.item { return "\(item.title): \(item.detail)" }
        switch presentation.phase {
        case .idle: return "Meanwhile — idle"
        case .thinking: return "Agent thinking — no eligible items"
        case .needsYou: return "Agent needs you"
        }
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

        let dismiss = NSMenuItem(
            title: "Dismiss",
            action: #selector(dismissCurrentItem),
            keyEquivalent: ""
        )
        dismiss.target = self
        dismiss.isEnabled = false
        dismissMenuItem = dismiss
        menu.addItem(dismiss)
        menu.addItem(.separator())

        let integrations = NSMenuItem(
            title: "Install Agent Integrations…",
            action: #selector(installAgentIntegrations),
            keyEquivalent: ""
        )
        integrations.image = NSImage(systemSymbolName: "link", accessibilityDescription: nil)
        integrations.target = self
        menu.addItem(integrations)

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
        guard let item = currentItem else { return }
        if item.kind == .needsYou, let session = item.session {
            _ = terminalFocuser.focus(session)
        } else if let url = item.url {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func snoozeCurrentItem() {
        runtime?.snoozeCurrent()
    }

    @objc private func dismissCurrentItem() {
        runtime?.dismissCurrent()
    }

    @objc private func installAgentIntegrations() {
        do {
            let result = try AgentIntegrationInstaller(helperURL: helperURL()).install()
            UserDefaults.standard.set(true, forKey: DefaultsKey.integrationPrompted)
            let alert = NSAlert()
            alert.messageText = "Agent integrations installed"
            alert.informativeText = result.claudeStatuslineConflict
                ? "Claude and Codex hooks are installed. Your existing Claude status line was preserved; add the MeanwhileHook statusline command manually if you want Meanwhile there too. In Codex, open /hooks once to review and trust the new hooks."
                : "Claude and Codex hooks and the Claude status line are installed. In Codex, open /hooks once to review and trust the new hooks."
            alert.runModal()
        } catch {
            let alert = NSAlert(error: error)
            alert.runModal()
        }
    }

    private func offerAgentIntegrationIfNeeded() {
        guard !UserDefaults.standard.bool(forKey: DefaultsKey.integrationPrompted) else { return }
        UserDefaults.standard.set(true, forKey: DefaultsKey.integrationPrompted)
        let alert = NSAlert()
        alert.messageText = "Connect Claude Code and Codex?"
        alert.informativeText = "Meanwhile uses local lifecycle hooks to know when an agent is thinking or needs you. Existing hook settings are preserved."
        alert.addButton(withTitle: "Install Integrations")
        alert.addButton(withTitle: "Later")
        if alert.runModal() == .alertFirstButtonReturn {
            installAgentIntegrations()
        }
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
        settingsWindowController.show(model: settingsModel)
    }

    @objc private func quitMeanwhile() {
        NSApplication.shared.terminate(nil)
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
