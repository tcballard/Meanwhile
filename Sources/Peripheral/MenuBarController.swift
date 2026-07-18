import AppKit
import SwiftUI

/// Owns an `NSStatusItem` and an anchored SwiftUI popover.
@MainActor
public final class MenuBarController<Content: View>: NSObject, NSMenuDelegate {
    public let statusItem: NSStatusItem
    public let popover: NSPopover
    private let onClick: (() -> Void)?
    private let contextMenu: NSMenu?

    public init(
        title: String? = nil,
        systemImageName: String? = nil,
        onClick: (() -> Void)? = nil,
        contextMenu: NSMenu? = nil,
        contentSize: NSSize = NSSize(width: 280, height: 190),
        @ViewBuilder content: () -> Content
    ) {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        popover = NSPopover()
        self.onClick = onClick
        self.contextMenu = contextMenu
        super.init()

        contextMenu?.delegate = self

        popover.behavior = .transient
        popover.animates = true
        popover.contentSize = contentSize
        popover.contentViewController = NSHostingController(rootView: content())

        setTitle(title)
        setIcon(systemName: systemImageName)

        statusItem.button?.target = self
        statusItem.button?.action = #selector(handleClick(_:))
        statusItem.button?.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    public func setTitle(_ title: String?) {
        statusItem.button?.title = title ?? ""
        updateImagePosition()
    }

    public func setIcon(
        systemName: String?,
        accessibilityDescription: String? = "Peripheral",
        tintColor: NSColor? = nil
    ) {
        guard let systemName else {
            statusItem.button?.image = nil
            return
        }

        let baseImage = NSImage(
            systemSymbolName: systemName,
            accessibilityDescription: accessibilityDescription
        )
        let image: NSImage?
        if let tintColor {
            image = baseImage?.withSymbolConfiguration(
                NSImage.SymbolConfiguration(paletteColors: [tintColor])
            )
            image?.isTemplate = false
        } else {
            baseImage?.isTemplate = true
            image = baseImage
        }
        statusItem.button?.image = image
        updateImagePosition()
    }

    public func setAccessibility(label: String, help: String? = nil) {
        statusItem.button?.setAccessibilityLabel(label)
        statusItem.button?.setAccessibilityHelp(help)
    }

    public func showPopover() {
        guard let button = statusItem.button else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    public func closePopover() {
        popover.performClose(nil)
    }

    private func updateImagePosition() {
        guard let button = statusItem.button, button.image != nil else { return }
        button.imagePosition = button.title.isEmpty ? .imageOnly : .imageLeading
    }

    @objc private func handleClick(_ sender: Any?) {
        if NSApp.currentEvent?.type == .rightMouseUp,
           let contextMenu,
           let button = statusItem.button {
            statusItem.menu = contextMenu
            button.performClick(nil)
            return
        }

        if let onClick {
            onClick()
            return
        }

        if popover.isShown {
            closePopover()
        } else {
            showPopover()
        }
    }

    public func menuDidClose(_ menu: NSMenu) {
        if menu === contextMenu {
            statusItem.menu = nil
        }
    }
}
