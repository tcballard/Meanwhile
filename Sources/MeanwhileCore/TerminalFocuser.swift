import AppKit
import Foundation

@MainActor
public final class TerminalFocuser {
    public init() {}

    @discardableResult
    public func focus(_ session: AgentSessionState) -> Bool {
        if let tty = session.terminal.tty {
            if isITerm(session.terminal.program), run(script: iTermScript(tty: tty)) {
                return true
            }
            if isAppleTerminal(session.terminal.program), run(script: terminalScript(tty: tty)) {
                return true
            }
            if run(script: terminalScript(tty: tty)) || run(script: iTermScript(tty: tty)) {
                return true
            }
        }
        return activateTerminal(named: session.terminal.program)
    }

    private func activateTerminal(named program: String?) -> Bool {
        let bundleIdentifiers: [String]
        switch program?.lowercased() {
        case "apple_terminal", "terminal", "terminal.app":
            bundleIdentifiers = ["com.apple.Terminal"]
        case "iterm.app", "iterm2", "iterm":
            bundleIdentifiers = ["com.googlecode.iterm2"]
        case "vscode", "visual studio code":
            bundleIdentifiers = ["com.microsoft.VSCode"]
        case "warpterminal", "warp":
            bundleIdentifiers = ["dev.warp.Warp-Stable", "dev.warp.Warp"]
        case "ghostty":
            bundleIdentifiers = ["com.mitchellh.ghostty"]
        default:
            bundleIdentifiers = ["com.apple.Terminal", "com.googlecode.iterm2"]
        }
        for identifier in bundleIdentifiers {
            if let app = NSRunningApplication.runningApplications(
                withBundleIdentifier: identifier
            ).first {
                return app.activate(options: [.activateAllWindows])
            }
        }
        return false
    }

    private func run(script: String) -> Bool {
        var error: NSDictionary?
        let result = NSAppleScript(source: script)?.executeAndReturnError(&error)
        return error == nil && result?.booleanValue == true
    }

    private func terminalScript(tty: String) -> String {
        let tty = appleScriptString(tty)
        return """
        tell application "Terminal"
          repeat with terminalWindow in windows
            repeat with terminalTab in tabs of terminalWindow
              if (tty of terminalTab as text) is "\(tty)" then
                set selected tab of terminalWindow to terminalTab
                set index of terminalWindow to 1
                activate
                return true
              end if
            end repeat
          end repeat
        end tell
        return false
        """
    }

    private func iTermScript(tty: String) -> String {
        let tty = appleScriptString(tty)
        return """
        tell application "iTerm2"
          repeat with terminalWindow in windows
            repeat with terminalTab in tabs of terminalWindow
              repeat with terminalSession in sessions of terminalTab
                if (tty of terminalSession as text) is "\(tty)" then
                  select terminalSession
                  select terminalTab
                  activate
                  return true
                end if
              end repeat
            end repeat
          end repeat
        end tell
        return false
        """
    }

    private func appleScriptString(_ value: String) -> String {
        value
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
    }

    private func isAppleTerminal(_ program: String?) -> Bool {
        guard let program = program?.lowercased() else { return false }
        return program.contains("terminal") && !program.contains("iterm")
    }

    private func isITerm(_ program: String?) -> Bool {
        program?.lowercased().contains("iterm") == true
    }
}
