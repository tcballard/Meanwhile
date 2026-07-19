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
        case .failingCI:
            return itemNumber(item).map { "CI! #\($0)" } ?? "CI!"
        case .review:
            return itemNumber(item).map { "#\($0)" } ?? "Review"
        }
    }

    public static func bloomText(item: WorkItem?) -> String? {
        guard let item else { return nil }
        switch item.kind {
        case .needsYou:
            return contextualTitle(
                attentionText(item: item),
                context: projectName(item: item)
            )
        case .review:
            let base = itemNumber(item).map { "Review #\($0)" } ?? "Review ready"
            return contextualTitle(base, context: repositoryName(item: item))
        case .failingCI:
            let base = itemNumber(item).map { "CI failed #\($0)" } ?? "CI failed"
            return contextualTitle(base, context: repositoryName(item: item))
        }
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

    public static func repositoryName(item: WorkItem) -> String? {
        guard item.kind == .review || item.kind == .failingCI else { return nil }
        let repository = item.detail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !repository.isEmpty,
              repository.rangeOfCharacter(from: .controlCharacters) == nil else { return nil }
        let name = repository.split(separator: "/").last.map(String.init) ?? repository
        guard !name.isEmpty, name != ".", name != ".." else { return nil }
        return middleTruncated(name, limit: 32)
    }

    public static func notificationTitle(item: WorkItem) -> String? {
        guard item.kind == .needsYou else { return nil }
        let provider = item.session.map { providerName($0.provider) } ?? "Agent"
        switch item.session?.effectiveAttentionReason ?? .generic {
        case .approvalRequired:
            return "\(provider) still needs approval"
        case .answerRequired:
            return "\(provider) still needs an answer"
        case .generic:
            return "\(provider) still needs attention"
        }
    }

    public static func destinationURL(item: WorkItem) -> URL? {
        guard let url = item.url else { return nil }
        guard item.kind == .failingCI,
              url.lastPathComponent != "checks" else { return url }
        return url.appendingPathComponent("checks")
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
        case .review:
            let base = itemNumber(item).map { "Open Review #\($0)" } ?? "Open Review"
            return menuActionTitle(base, repository: repositoryName(item: item))
        case .failingCI:
            let base = itemNumber(item).map { "Inspect CI #\($0)" } ?? "Inspect CI"
            return menuActionTitle(base, repository: repositoryName(item: item))
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
            let number = itemNumber(item)
            let repository = middleTruncated(item.detail, limit: 64)
            switch item.kind {
            case .review:
                let identity = number.map { "\(repository) #\($0)" } ?? repository
                return "Review requested — \(identity) — click to open"
            case .failingCI:
                let identity = number.map { "\(repository) #\($0)" } ?? repository
                return "CI failed — \(identity) — click to inspect checks"
            case .needsYou:
                return "\(item.title) — click to return"
            }
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
            case .review:
                if let number = itemNumber(item) {
                    return "Review requested for pull request \(number) in \(item.detail)"
                }
                return "Review requested in \(item.detail)"
            case .failingCI:
                if let number = itemNumber(item) {
                    return "Continuous integration failed for pull request \(number) in \(item.detail)"
                }
                return "Continuous integration failed in \(item.detail)"
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
            case .review:
                return itemNumber(item).map { "Opens pull request \($0) on GitHub." }
                    ?? "Opens the pull request on GitHub."
            case .failingCI:
                return itemNumber(item).map { "Opens the failed checks for pull request \($0) on GitHub." }
                    ?? "Opens the failed checks on GitHub."
            }
        }
        return phase == .needsYou
            ? "It will reappear when its state changes."
            : nil
    }

    public static func statuslineText(item: WorkItem) -> String {
        switch item.kind {
        case .needsYou: return "Meanwhile: \(attentionText(item: item))"
        case .failingCI: return "Meanwhile: \(item.title) — \(item.detail)"
        case .review: return "Meanwhile: \(item.title) — \(item.detail)"
        }
    }

    private static func itemNumber(_ item: WorkItem) -> String? {
        guard let marker = item.title.lastIndex(of: "#") else { return nil }
        let suffix = item.title[item.title.index(after: marker)...]
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !suffix.isEmpty, suffix.allSatisfy(\.isNumber) else { return nil }
        return suffix
    }

    private static func contextualTitle(_ base: String, context: String?) -> String {
        guard let context else { return base }
        let separator = " — "
        let totalLimit = 46
        let contextLimit = min(20, totalLimit - base.count - separator.count)
        guard contextLimit >= 8 else { return base }
        let compactContext = middleTruncated(context, limit: contextLimit)
        let combined = "\(base)\(separator)\(compactContext)"
        return combined.count <= totalLimit ? combined : base
    }

    private static func menuActionTitle(_ base: String, repository: String?) -> String {
        guard let repository else { return base }
        let separator = " — "
        let totalLimit = 30
        let repositoryLimit = totalLimit - base.count - separator.count
        guard repositoryLimit >= 6 else { return base }
        return "\(base)\(separator)\(middleTruncated(repository, limit: repositoryLimit))"
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
