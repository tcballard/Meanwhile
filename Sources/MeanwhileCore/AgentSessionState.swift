import Foundation

public enum AgentProvider: String, Codable, Sendable {
    case claude
    case codex
    case unknown
}

public enum AgentPhase: String, Codable, Sendable {
    case thinking
    case needsYou = "needs-you"
    case idle
}

public enum AgentAttentionReason: String, Codable, Sendable {
    case approvalRequired = "approval-required"
    case answerRequired = "answer-required"
    case generic

    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = Self(rawValue: rawValue) ?? .generic
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        try container.encode(rawValue)
    }
}

public struct TerminalContext: Equatable, Codable, Sendable {
    public var program: String?
    public var sessionID: String?
    public var tty: String?

    public init(program: String? = nil, sessionID: String? = nil, tty: String? = nil) {
        self.program = program
        self.sessionID = sessionID
        self.tty = tty
    }
}

public struct AgentSessionState: Equatable, Codable, Sendable, Identifiable {
    public var provider: AgentProvider
    public var sessionID: String
    public var cwd: String
    public var phase: AgentPhase
    public var attentionReason: AgentAttentionReason?
    public var enteredAt: Date
    public var updatedAt: Date
    public var terminal: TerminalContext

    public var id: String { "\(provider.rawValue):\(sessionID)" }

    public init(
        provider: AgentProvider,
        sessionID: String,
        cwd: String,
        phase: AgentPhase,
        attentionReason: AgentAttentionReason? = nil,
        enteredAt: Date,
        updatedAt: Date,
        terminal: TerminalContext = TerminalContext()
    ) {
        self.provider = provider
        self.sessionID = sessionID
        self.cwd = cwd
        self.phase = phase
        self.attentionReason = attentionReason
        self.enteredAt = enteredAt
        self.updatedAt = updatedAt
        self.terminal = terminal
    }

    public var effectiveAttentionReason: AgentAttentionReason? {
        guard phase == .needsYou else { return nil }
        return attentionReason ?? .generic
    }
}
