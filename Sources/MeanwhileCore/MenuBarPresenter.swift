import Foundation

public enum MenuBarPresenter {
    public static let idleIconName = "rectangle.stack"
    public static let thinkingIconName = "rectangle.stack.fill"
    public static let needsYouIconName = "exclamationmark.bubble.fill"

    public static func iconName(phase: AgentDisplayPhase) -> String {
        switch phase {
        case .idle: return idleIconName
        case .thinking: return thinkingIconName
        case .needsYou: return needsYouIconName
        }
    }

    public static func statusText(item: WorkItem?) -> String? {
        guard let item else { return nil }
        switch item.kind {
        case .needsYou: return item.title
        case .failingCI: return "CI!"
        case .review:
            let number = item.title.split(separator: "#").last.map(String.init)
            return number.map { "#\($0)" } ?? "Review"
        }
    }

    public static func bloomText(item: WorkItem?) -> String? {
        guard let item, item.kind == .needsYou else {
            return statusText(item: item)
        }
        let attention = attentionText(item: item)
        guard let project = projectName(item: item) else { return attention }

        let separator = " — "
        let totalLimit = 46
        let projectLimit = min(20, totalLimit - attention.count - separator.count)
        guard projectLimit >= 8 else { return attention }
        let compactProject = middleTruncated(project, limit: projectLimit)
        let combined = "\(attention)\(separator)\(compactProject)"
        return combined.count <= totalLimit ? combined : attention
    }

    public static func attentionText(item: WorkItem) -> String {
        guard item.kind == .needsYou else { return item.title }
        let provider = item.session.map { providerName($0.provider) } ?? "Agent"
        switch item.session?.effectiveAttentionReason ?? .generic {
        case .approvalRequired:
            return "\(provider) needs approval"
        case .answerRequired:
            return "\(provider) needs an answer"
        case .generic:
            return "\(provider) needs attention"
        }
    }

    public static func projectName(item: WorkItem) -> String? {
        guard let cwd = item.session?.cwd.trimmingCharacters(in: .whitespacesAndNewlines),
              !cwd.isEmpty,
              cwd.rangeOfCharacter(from: .controlCharacters) == nil else { return nil }
        let url = URL(fileURLWithPath: cwd).standardizedFileURL
        guard url != FileManager.default.homeDirectoryForCurrentUser.standardizedFileURL else {
            return nil
        }
        let name = (cwd as NSString).lastPathComponent
        guard !name.isEmpty,
              name != "/",
              name != ".",
              name != "..",
              name.rangeOfCharacter(from: .controlCharacters) == nil else { return nil }
        return middleTruncated(name, limit: 32)
    }

    public static func openActionTitle(item: WorkItem) -> String {
        switch item.kind {
        case .needsYou:
            let action: String
            switch item.session?.provider {
            case .claude: action = "Return to Claude"
            case .codex: action = "Return to Codex"
            case .unknown, nil: action = "Return to waiting task"
            }
            if let project = projectName(item: item) {
                return "\(action) — \(project)"
            }
            return action
        case .review, .failingCI:
            return "Open \(item.title) — \(item.detail)"
        }
    }

    public static func tooltip(phase: AgentDisplayPhase, item: WorkItem?) -> String {
        if let item {
            if item.kind == .needsYou {
                let attention = attentionText(item: item)
                if let project = projectName(item: item) {
                    return "\(attention) in “\(project)” — click to return"
                }
                return "\(attention) — click to return"
            }
            return "\(item.title): \(item.detail)"
        }
        switch phase {
        case .idle: return "Meanwhile — idle"
        case .thinking: return "Agent thinking — no eligible items"
        case .needsYou: return "Waiting task hidden"
        }
    }

    public static func accessibilityLabel(
        phase: AgentDisplayPhase,
        item: WorkItem?
    ) -> String {
        if let item {
            switch item.kind {
            case .needsYou:
                let attention = attentionText(item: item)
                if let project = projectName(item: item) {
                    return "\(attention) in \(project)"
                }
                return attention
            case .review, .failingCI:
                return "\(item.title), \(item.detail)"
            }
        }
        switch phase {
        case .idle: return "Meanwhile, idle"
        case .thinking: return "Meanwhile, agent thinking"
        case .needsYou: return "Waiting task hidden"
        }
    }

    public static func accessibilityHelp(
        phase: AgentDisplayPhase,
        item: WorkItem?
    ) -> String? {
        if let item {
            switch item.kind {
            case .needsYou:
                guard let provider = item.session?.provider,
                      provider != .unknown else {
                    return "Returns to the waiting task."
                }
                return "Returns to the waiting \(providerName(provider)) task."
            case .review, .failingCI:
                return "Opens \(item.title)."
            }
        }
        return phase == .needsYou
            ? "It will reappear when its state changes."
            : nil
    }

    public static func statuslineText(item: WorkItem) -> String {
        switch item.kind {
        case .needsYou: return "Meanwhile: \(attentionText(item: item))"
        case .failingCI: return "Meanwhile: CI failed — \(item.detail)"
        case .review: return "Meanwhile: \(item.title) — \(item.detail)"
        }
    }

    private static func providerName(_ provider: AgentProvider) -> String {
        switch provider {
        case .claude: return "Claude"
        case .codex: return "Codex"
        case .unknown: return "Agent"
        }
    }

    private static func middleTruncated(_ value: String, limit: Int) -> String {
        guard value.count > limit, limit > 1 else { return value }
        let leadingCount = (limit - 1) / 2
        let trailingCount = limit - leadingCount - 1
        return "\(value.prefix(leadingCount))…\(value.suffix(trailingCount))"
    }
}
