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
        case .needsYou: return "Needs you"
        case .failingCI: return "CI!"
        case .review:
            let number = item.title.split(separator: "#").last.map(String.init)
            return number.map { "#\($0)" } ?? "Review"
        }
    }

    public static func statuslineText(item: WorkItem) -> String {
        switch item.kind {
        case .needsYou: return "Meanwhile: \(item.title)"
        case .failingCI: return "Meanwhile: CI failed — \(item.detail)"
        case .review: return "Meanwhile: \(item.title) — \(item.detail)"
        }
    }
}
