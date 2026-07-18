import Foundation

public enum HookEventDecoderError: Error {
    case invalidPayload
    case missingSessionID
    case missingWorkingDirectory
    case unsupportedEvent(String)
}

public enum HookEventDecoder {
    public static func decode(
        _ data: Data,
        provider: AgentProvider,
        now: Date = Date(),
        environment: [String: String] = ProcessInfo.processInfo.environment,
        previous: AgentSessionState? = nil
    ) throws -> AgentSessionState {
        guard let object = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let eventName = object["hook_event_name"] as? String else {
            throw HookEventDecoderError.invalidPayload
        }
        guard let sessionID = object["session_id"] as? String, !sessionID.isEmpty else {
            throw HookEventDecoderError.missingSessionID
        }
        guard let cwd = object["cwd"] as? String, !cwd.isEmpty else {
            throw HookEventDecoderError.missingWorkingDirectory
        }

        let phase: AgentPhase
        let attentionReason: AgentAttentionReason?
        switch eventName {
        case "SessionStart", "Stop", "SessionEnd":
            phase = .idle
            attentionReason = nil
        case "UserPromptSubmit", "PreToolUse", "PostToolUse":
            phase = .thinking
            attentionReason = nil
        case "PermissionRequest":
            phase = .needsYou
            attentionReason = .approvalRequired
        case "Notification":
            let notificationType = object["notification_type"] as? String
                ?? object["type"] as? String
            switch notificationType {
            case "permission_prompt":
                phase = .needsYou
                attentionReason = .approvalRequired
            case "idle_prompt", "elicitation_dialog":
                phase = .needsYou
                attentionReason = .answerRequired
            default:
                throw HookEventDecoderError.unsupportedEvent(eventName)
            }
        default:
            throw HookEventDecoderError.unsupportedEvent(eventName)
        }

        let effectiveAttentionReason = phase == .needsYou
            ? attentionReason ?? .generic
            : nil
        let preservesEntry = previous?.phase == phase
            && previous?.effectiveAttentionReason == effectiveAttentionReason
        let enteredAt = preservesEntry ? previous?.enteredAt ?? now : now
        return AgentSessionState(
            provider: provider,
            sessionID: sessionID,
            cwd: cwd,
            phase: phase,
            attentionReason: attentionReason,
            enteredAt: enteredAt,
            updatedAt: now,
            terminal: TerminalContext(
                program: environment["TERM_PROGRAM"],
                sessionID: environment["TERM_SESSION_ID"]
                    ?? environment["ITERM_SESSION_ID"]
                    ?? environment["WEZTERM_PANE"],
                tty: environment["MEANWHILE_TTY"]
            )
        )
    }
}
