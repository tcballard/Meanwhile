import AppKit
import Foundation

public enum AgentFocusOutcome: Equatable, Sendable {
    case codexTask
    case terminalFallback
    case unavailable
}

@MainActor
public final class AgentFocusRouter {
    private let openURL: (URL) -> Bool
    private let focusTerminal: (AgentSessionState) -> Bool

    public init(
        openURL: @escaping (URL) -> Bool = { NSWorkspace.shared.open($0) },
        focusTerminal: @escaping (AgentSessionState) -> Bool
    ) {
        self.openURL = openURL
        self.focusTerminal = focusTerminal
    }

    public func focus(_ session: AgentSessionState) -> AgentFocusOutcome {
        if let url = Self.codexThreadURL(for: session), openURL(url) {
            return .codexTask
        }
        return focusTerminal(session) ? .terminalFallback : .unavailable
    }

    nonisolated static func codexThreadURL(for session: AgentSessionState) -> URL? {
        guard session.provider == .codex,
              UUID(uuidString: session.sessionID) != nil else { return nil }
        return URL(string: "codex://threads/\(session.sessionID)")
    }
}
