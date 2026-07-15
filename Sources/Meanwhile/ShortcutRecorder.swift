import AppKit
import MeanwhileCore
import SwiftUI

struct ShortcutRecorder: NSViewRepresentable {
    @Binding var shortcut: HotKeyConfiguration?
    let validationMessage: (String?) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(shortcut: $shortcut, validationMessage: validationMessage)
    }

    func makeNSView(context: Context) -> ShortcutRecorderButton {
        let button = ShortcutRecorderButton()
        button.captureHandler = { configuration in
            context.coordinator.shortcut.wrappedValue = configuration
        }
        button.validationHandler = context.coordinator.validationMessage
        button.configuration = shortcut
        return button
    }

    func updateNSView(_ button: ShortcutRecorderButton, context: Context) {
        context.coordinator.shortcut = $shortcut
        context.coordinator.validationMessage = validationMessage
        button.captureHandler = { configuration in
            context.coordinator.shortcut.wrappedValue = configuration
        }
        button.validationHandler = context.coordinator.validationMessage
        button.configuration = shortcut
    }

    final class Coordinator {
        var shortcut: Binding<HotKeyConfiguration?>
        var validationMessage: (String?) -> Void

        init(
            shortcut: Binding<HotKeyConfiguration?>,
            validationMessage: @escaping (String?) -> Void
        ) {
            self.shortcut = shortcut
            self.validationMessage = validationMessage
        }
    }
}

final class ShortcutRecorderButton: NSButton {
    var captureHandler: ((HotKeyConfiguration?) -> Void)?
    var validationHandler: ((String?) -> Void)?
    var configuration: HotKeyConfiguration? {
        didSet {
            if !isRecording { updateTitle() }
        }
    }

    private var isRecording = false

    override init(frame frameRect: NSRect) {
        super.init(frame: frameRect)
        setButtonType(.momentaryPushIn)
        bezelStyle = .rounded
        controlSize = .regular
        alignment = .center
        focusRingType = .default
        target = self
        action = #selector(beginRecording)
        toolTip = "Record a global keyboard shortcut"
        setAccessibilityLabel("Keyboard shortcut")
        setAccessibilityHelp("Press a key with Command, Control, Option, or Shift. Press Delete to clear.")
        updateTitle()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override var acceptsFirstResponder: Bool { true }

    override func becomeFirstResponder() -> Bool {
        guard super.becomeFirstResponder() else { return false }
        isRecording = true
        title = "Type shortcut…"
        validationHandler?(nil)
        return true
    }

    override func resignFirstResponder() -> Bool {
        let resigned = super.resignFirstResponder()
        if resigned {
            isRecording = false
            updateTitle()
        }
        return resigned
    }

    override func keyDown(with event: NSEvent) {
        let modifierFlags = event.modifierFlags.intersection([.command, .control, .option, .shift])
        if event.keyCode == 53, modifierFlags.isEmpty {
            finishRecording()
            return
        }
        if (event.keyCode == 51 || event.keyCode == 117), modifierFlags.isEmpty {
            validationHandler?(nil)
            captureHandler?(nil)
            finishRecording()
            return
        }

        guard let key = Self.key(for: event) else {
            validationHandler?("Use a letter, number, Space, Tab, Return, or Escape.")
            NSSound.beep()
            return
        }
        let modifiers = Self.modifiers(from: modifierFlags)
        guard !modifiers.isEmpty else {
            validationHandler?("Include at least one modifier key.")
            NSSound.beep()
            return
        }

        let configuration = HotKeyConfiguration(key: key, modifiers: modifiers)
        validationHandler?(nil)
        captureHandler?(configuration)
        finishRecording()
    }

    @objc private func beginRecording() {
        window?.makeFirstResponder(self)
    }

    private func finishRecording() {
        isRecording = false
        window?.makeFirstResponder(nil)
        updateTitle()
    }

    private func updateTitle() {
        title = configuration.map(Self.displayName) ?? "Click to record shortcut"
        setAccessibilityValue(configuration.map(Self.displayName) ?? "Not set")
    }

    private static func key(for event: NSEvent) -> String? {
        switch event.keyCode {
        case 36: return "return"
        case 48: return "tab"
        case 49: return "space"
        case 53: return "escape"
        default:
            guard let characters = event.charactersIgnoringModifiers?.lowercased(),
                  characters.count == 1,
                  let scalar = characters.unicodeScalars.first else {
                return nil
            }
            if ("a"..."z").contains(Character(String(scalar)))
                || ("0"..."9").contains(Character(String(scalar))) {
                return String(scalar)
            }
            return nil
        }
    }

    private static func modifiers(from flags: NSEvent.ModifierFlags) -> [HotKeyModifier] {
        var modifiers: [HotKeyModifier] = []
        if flags.contains(.control) { modifiers.append(.control) }
        if flags.contains(.option) { modifiers.append(.option) }
        if flags.contains(.shift) { modifiers.append(.shift) }
        if flags.contains(.command) { modifiers.append(.command) }
        return modifiers
    }

    private static func displayName(_ configuration: HotKeyConfiguration) -> String {
        var value = ""
        if configuration.modifiers.contains(.control) { value += "⌃" }
        if configuration.modifiers.contains(.option) { value += "⌥" }
        if configuration.modifiers.contains(.shift) { value += "⇧" }
        if configuration.modifiers.contains(.command) { value += "⌘" }
        switch configuration.key {
        case "space": value += "Space"
        case "return": value += "Return"
        case "tab": value += "Tab"
        case "escape": value += "Esc"
        default: value += configuration.key.uppercased()
        }
        return value
    }
}
