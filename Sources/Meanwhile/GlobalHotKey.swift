import Carbon.HIToolbox
import Foundation
import MeanwhileCore

@MainActor
final class GlobalHotKey {
    private static var nextID: UInt32 = 1

    private var eventHandler: EventHandlerRef?
    private var hotKey: EventHotKeyRef?
    private let handler: () -> Void

    init(configuration: HotKeyConfiguration, handler: @escaping () -> Void) throws {
        self.handler = handler

        guard let keyCode = Self.keyCode(for: configuration.key) else {
            throw HotKeyError.unsupportedKey(configuration.key)
        }

        let modifierFlags = Self.modifierFlags(for: configuration.modifiers)
        guard modifierFlags != 0 else {
            throw HotKeyError.missingModifiers
        }

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        let installStatus = InstallEventHandler(
            GetApplicationEventTarget(),
            { _, _, userData in
                guard let userData else { return noErr }
                let hotKey = Unmanaged<GlobalHotKey>
                    .fromOpaque(userData)
                    .takeUnretainedValue()
                Task { @MainActor in hotKey.handler() }
                return noErr
            },
            1,
            &eventType,
            Unmanaged.passUnretained(self).toOpaque(),
            &eventHandler
        )
        guard installStatus == noErr else {
            throw HotKeyError.registrationFailed(installStatus)
        }

        let id = EventHotKeyID(
            signature: Self.signature("MWKH"),
            id: Self.nextID
        )
        Self.nextID += 1

        let registerStatus = RegisterEventHotKey(
            UInt32(keyCode),
            modifierFlags,
            id,
            GetApplicationEventTarget(),
            0,
            &hotKey
        )
        guard registerStatus == noErr else {
            throw HotKeyError.registrationFailed(registerStatus)
        }
    }

    deinit {
        if let hotKey {
            UnregisterEventHotKey(hotKey)
        }
        if let eventHandler {
            RemoveEventHandler(eventHandler)
        }
    }

    private static func modifierFlags(for modifiers: [HotKeyModifier]) -> UInt32 {
        modifiers.reduce(UInt32(0)) { flags, modifier in
            switch modifier {
            case .command: return flags | UInt32(cmdKey)
            case .control: return flags | UInt32(controlKey)
            case .option: return flags | UInt32(optionKey)
            case .shift: return flags | UInt32(shiftKey)
            }
        }
    }

    private static func keyCode(for key: String) -> Int? {
        switch key.lowercased() {
        case "a": return kVK_ANSI_A
        case "b": return kVK_ANSI_B
        case "c": return kVK_ANSI_C
        case "d": return kVK_ANSI_D
        case "e": return kVK_ANSI_E
        case "f": return kVK_ANSI_F
        case "g": return kVK_ANSI_G
        case "h": return kVK_ANSI_H
        case "i": return kVK_ANSI_I
        case "j": return kVK_ANSI_J
        case "k": return kVK_ANSI_K
        case "l": return kVK_ANSI_L
        case "m": return kVK_ANSI_M
        case "n": return kVK_ANSI_N
        case "o": return kVK_ANSI_O
        case "p": return kVK_ANSI_P
        case "q": return kVK_ANSI_Q
        case "r": return kVK_ANSI_R
        case "s": return kVK_ANSI_S
        case "t": return kVK_ANSI_T
        case "u": return kVK_ANSI_U
        case "v": return kVK_ANSI_V
        case "w": return kVK_ANSI_W
        case "x": return kVK_ANSI_X
        case "y": return kVK_ANSI_Y
        case "z": return kVK_ANSI_Z
        case "0": return kVK_ANSI_0
        case "1": return kVK_ANSI_1
        case "2": return kVK_ANSI_2
        case "3": return kVK_ANSI_3
        case "4": return kVK_ANSI_4
        case "5": return kVK_ANSI_5
        case "6": return kVK_ANSI_6
        case "7": return kVK_ANSI_7
        case "8": return kVK_ANSI_8
        case "9": return kVK_ANSI_9
        case "space": return kVK_Space
        case "tab": return kVK_Tab
        case "return", "enter": return kVK_Return
        case "escape", "esc": return kVK_Escape
        default: return nil
        }
    }

    private static func signature(_ string: String) -> OSType {
        string.utf8.reduce(OSType(0)) { result, byte in
            (result << 8) + OSType(byte)
        }
    }
}

enum HotKeyError: LocalizedError {
    case unsupportedKey(String)
    case missingModifiers
    case registrationFailed(OSStatus)

    var errorDescription: String? {
        switch self {
        case .unsupportedKey(let key):
            return "Unsupported hotkey key: \(key)"
        case .missingModifiers:
            return "Hotkey requires at least one modifier"
        case .registrationFailed(let status):
            return "Could not register hotkey: \(status)"
        }
    }
}
