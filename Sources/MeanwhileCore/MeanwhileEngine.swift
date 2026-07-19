import Foundation

public enum AgentDisplayPhase: Equatable, Sendable {
    case idle
    case thinking
    case needsYou
}

public struct MeanwhilePresentation: Equatable, Sendable {
    public var phase: AgentDisplayPhase
    public var waitGateIsOpen: Bool
    public var item: WorkItem?
    public var sessionCount: Int

    public init(
        phase: AgentDisplayPhase,
        waitGateIsOpen: Bool,
        item: WorkItem?,
        sessionCount: Int
    ) {
        self.phase = phase
        self.waitGateIsOpen = waitGateIsOpen
        self.item = item
        self.sessionCount = sessionCount
    }
}

public final class MeanwhileEngine: @unchecked Sendable {
    private let configuration: MeanwhileConfiguration
    private let dispositions: ItemDispositionStore

    public init(
        configuration: MeanwhileConfiguration = MeanwhileConfiguration(),
        dispositions: ItemDispositionStore = ItemDispositionStore()
    ) {
        self.configuration = configuration
        self.dispositions = dispositions
    }

    public func presentation(
        sessions: [AgentSessionState],
        reviews: [ReviewItem],
        failingCI: [FailingCIItem],
        sourceSelection: AttentionSourceSelection? = nil,
        now: Date = Date()
    ) -> MeanwhilePresentation {
        let sourceSelection = sourceSelection ?? AttentionSourceSelection(
            reviewsEnabled: configuration.enableReviews,
            failingCIEnabled: configuration.enableFailingCI
        )
        let activeSessions = sessions.filter { $0.phase != .idle }
        let needsYou = sessions.filter { $0.phase == .needsYou }
        let thinking = sessions.filter { $0.phase == .thinking }
        let gateIsOpen = !thinking.isEmpty

        let urgentItems = needsYou.map { session in
            WorkItem(
                id: WorkItem.needsYouID(for: session),
                kind: .needsYou,
                title: "\(providerName(session.provider)) needs you",
                detail: session.cwd,
                createdAt: session.enteredAt,
                session: session
            )
        }
        let ciItems = sourceSelection.failingCIEnabled ? failingCI.map { item in
            WorkItem(
                id: "ci:\(item.repository)#\(item.number)",
                kind: .failingCI,
                title: "CI failed on #\(item.number)",
                detail: item.repository,
                url: item.url,
                createdAt: item.createdAt
            )
        } : []
        let reviewItems = sourceSelection.reviewsEnabled ? reviews.map { item in
            WorkItem(
                id: "review:\(item.repository)#\(item.number)",
                kind: .review,
                title: "Review #\(item.number)",
                detail: item.repository,
                url: item.url,
                createdAt: item.createdAt
            )
        } : []

        let allSourceItems = urgentItems + ciItems + reviewItems
        dispositions.reconcile(activeItemIDs: Set(allSourceItems.map(\.id)), now: now)
        let eligible = urgentItems + (gateIsOpen ? ciItems + reviewItems : [])
        let visible = WorkItemOrdering.sorted(
            eligible.filter { dispositions.isAvailable(itemID: $0.id, now: now) }
        )

        let phase: AgentDisplayPhase
        if !needsYou.isEmpty {
            phase = .needsYou
        } else if !thinking.isEmpty {
            phase = .thinking
        } else {
            phase = .idle
        }
        return MeanwhilePresentation(
            phase: phase,
            waitGateIsOpen: gateIsOpen,
            item: visible.first,
            sessionCount: activeSessions.count
        )
    }

    public func snooze(_ item: WorkItem, now: Date = Date()) {
        dispositions.snooze(
            itemID: item.id,
            until: now.addingTimeInterval(configuration.snoozeSeconds),
            now: now
        )
    }

    public func dismiss(_ item: WorkItem) {
        dispositions.dismiss(itemID: item.id)
    }

    private func providerName(_ provider: AgentProvider) -> String {
        switch provider {
        case .claude: return "Claude"
        case .codex: return "Codex"
        case .unknown: return "Agent"
        }
    }
}
