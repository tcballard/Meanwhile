import AppKit
import Foundation

@MainActor
public final class TerminalFocuser {
    private let scriptRunner: (String) -> Bool

    public convenience init() {
        self.init { script in
            var error: NSDictionary?
            let result = NSAppleScript(source: script)?.executeAndReturnError(&error)
            return error == nil && result?.booleanValue == true
        }
    }

    init(scriptRunner: @escaping (String) -> Bool) {
        self.scriptRunner = scriptRunner
    }

    @discardableResult
    public func focus(_ session: AgentSessionState) -> Bool {
        guard let tty = session.terminal.tty else { return false }
        if isITerm(session.terminal.program) {
            return scriptRunner(iTermScript(tty: tty))
        }
        if isAppleTerminal(session.terminal.program) {
            return scriptRunner(terminalScript(tty: tty))
        }
        return false
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
        guard let program = normalizedProgram(program) else { return false }
        return ["apple_terminal", "terminal", "terminal.app"].contains(program)
    }

    private func isITerm(_ program: String?) -> Bool {
        guard let program = normalizedProgram(program) else { return false }
        return ["iterm", "iterm2", "iterm.app"].contains(program)
    }

    private func normalizedProgram(_ program: String?) -> String? {
        guard let program = program?.trimmingCharacters(in: .whitespacesAndNewlines),
              !program.isEmpty else { return nil }
        return (program as NSString).lastPathComponent.lowercased()
    }
}
