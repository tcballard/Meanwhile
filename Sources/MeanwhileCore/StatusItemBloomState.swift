import Foundation

public enum StatusItemBloomTransition: Equatable, Sendable {
    case none
    case start(itemID: String, generation: UInt64)
    case cancel
}

public struct StatusItemBloomState: Sendable {
    private struct Candidate: Equatable, Sendable {
        var itemID: String
        var reason: AgentAttentionReason
    }

    private var hasObservedPresentation = false
    private var selectedCandidate: Candidate?
    private var activeItemID: String?
    private var activeGeneration: UInt64?
    private var generation: UInt64 = 0

    public init() {}

    public var isActive: Bool { activeItemID != nil }

    public mutating func observe(
        phase: AgentDisplayPhase,
        item: WorkItem?
    ) -> StatusItemBloomTransition {
        let candidate: Candidate?
        if phase == .needsYou,
           let item,
           item.kind == .needsYou {
            candidate = Candidate(
                itemID: item.id,
                reason: item.session?.effectiveAttentionReason ?? .generic
            )
        } else {
            candidate = nil
        }

        guard hasObservedPresentation else {
            hasObservedPresentation = true
            selectedCandidate = candidate
            return .none
        }
        guard candidate != selectedCandidate else { return .none }

        selectedCandidate = candidate
        generation &+= 1
        if let candidate {
            activeItemID = candidate.itemID
            activeGeneration = generation
            return .start(itemID: candidate.itemID, generation: generation)
        }

        guard isActive else { return .none }
        activeItemID = nil
        activeGeneration = nil
        return .cancel
    }

    @discardableResult
    public mutating func expire(itemID: String, generation: UInt64) -> Bool {
        guard activeItemID == itemID,
              activeGeneration == generation else { return false }
        activeItemID = nil
        activeGeneration = nil
        return true
    }

    @discardableResult
    public mutating func settle() -> Bool {
        guard isActive else { return false }
        generation &+= 1
        activeItemID = nil
        activeGeneration = nil
        return true
    }
}
