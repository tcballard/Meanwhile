import Foundation

public enum WorkItemKind: Int, Codable, CaseIterable, Sendable {
    case needsYou = 0
    case failingCI = 1
    case review = 2
}

public struct WorkItem: Equatable, Codable, Sendable, Identifiable {
    public var id: String
    public var kind: WorkItemKind
    public var title: String
    public var detail: String
    public var url: URL?
    public var createdAt: Date
    public var session: AgentSessionState?

    public init(
        id: String,
        kind: WorkItemKind,
        title: String,
        detail: String,
        url: URL? = nil,
        createdAt: Date,
        session: AgentSessionState? = nil
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.url = url
        self.createdAt = createdAt
        self.session = session
    }

    public static func needsYouID(for session: AgentSessionState) -> String {
        "needs-you:\(session.id):\(session.enteredAt.timeIntervalSince1970)"
    }
}

public enum WorkItemOrdering {
    public static func sorted(_ items: [WorkItem]) -> [WorkItem] {
        items.sorted { lhs, rhs in
            if lhs.kind.rawValue != rhs.kind.rawValue {
                return lhs.kind.rawValue < rhs.kind.rawValue
            }
            if lhs.createdAt != rhs.createdAt {
                return lhs.createdAt < rhs.createdAt
            }
            return lhs.id < rhs.id
        }
    }
}
