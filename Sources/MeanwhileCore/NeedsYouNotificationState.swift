import Foundation

public enum NeedsYouNotificationTransition: Equatable, Sendable {
    case none
    case deliver(item: WorkItem)
    case replace(previousItemID: String, delivery: WorkItem?)
    case cancel(itemID: String)
}

public struct NeedsYouNotificationState: Sendable {
    private enum DeliveryState: Sendable {
        case armed
        case attempted
        case acknowledged
    }

    private struct Candidate: Sendable {
        var itemID: String
        var deliveryState: DeliveryState
        var retryNotBefore: Date?
    }

    private var candidate: Candidate?
    private var suppressedItemIDs: Set<String> = []
    private var suppressionOrder: [String] = []

    public init() {}

    public mutating func observe(
        settings: NeedsYouNotificationSettings,
        permission: NeedsYouNotificationPermission,
        phase: AgentDisplayPhase,
        item: WorkItem?,
        now: Date = Date()
    ) -> NeedsYouNotificationTransition {
        let eligibleItem: WorkItem?
        if settings.isEnabled,
           permission == .authorized,
           phase == .needsYou,
           let item,
           item.kind == .needsYou {
            eligibleItem = item
        } else {
            eligibleItem = nil
        }

        guard let eligibleItem else {
            guard let previous = candidate else { return .none }
            candidate = nil
            return .cancel(itemID: previous.itemID)
        }

        if suppressedItemIDs.contains(eligibleItem.id) {
            let previousItemID = candidate?.itemID
            candidate = Candidate(
                itemID: eligibleItem.id,
                deliveryState: .attempted,
                retryNotBefore: nil
            )
            if let previousItemID, previousItemID != eligibleItem.id {
                return .replace(previousItemID: previousItemID, delivery: nil)
            }
            return .none
        }

        let deadline = eligibleItem.createdAt.addingTimeInterval(
            settings.delay.timeInterval
        )
        if var existing = candidate, existing.itemID == eligibleItem.id {
            let deliveryDate = max(deadline, existing.retryNotBefore ?? .distantPast)
            guard existing.deliveryState == .armed, now >= deliveryDate else {
                return .none
            }
            existing.deliveryState = .attempted
            existing.retryNotBefore = nil
            candidate = existing
            suppress(itemID: eligibleItem.id)
            return .deliver(item: eligibleItem)
        }

        let previousItemID = candidate?.itemID
        let delayHasElapsed = now >= deadline
        candidate = Candidate(
            itemID: eligibleItem.id,
            deliveryState: delayHasElapsed ? .attempted : .armed,
            retryNotBefore: nil
        )
        let delivery = delayHasElapsed ? eligibleItem : nil
        if delivery != nil {
            suppress(itemID: eligibleItem.id)
        }
        if let previousItemID {
            return .replace(previousItemID: previousItemID, delivery: delivery)
        }
        return delivery.map(NeedsYouNotificationTransition.deliver(item:)) ?? .none
    }

    public mutating func acknowledge(itemID: String) -> NeedsYouNotificationTransition {
        suppress(itemID: itemID)
        guard var existing = candidate, existing.itemID == itemID else {
            return .cancel(itemID: itemID)
        }
        existing.deliveryState = .acknowledged
        existing.retryNotBefore = nil
        candidate = existing
        return .cancel(itemID: itemID)
    }

    public mutating func restoreReceipt(itemID: String) {
        suppress(itemID: itemID)
        guard var existing = candidate, existing.itemID == itemID else { return }
        existing.deliveryState = .attempted
        existing.retryNotBefore = nil
        candidate = existing
    }

    public mutating func deliveryFailed(itemID: String, retryNotBefore: Date) {
        unsuppress(itemID: itemID)
        guard var existing = candidate, existing.itemID == itemID else { return }
        existing.deliveryState = .armed
        existing.retryNotBefore = retryNotBefore
        candidate = existing
    }

    private mutating func suppress(itemID: String) {
        guard suppressedItemIDs.insert(itemID).inserted else { return }
        suppressionOrder.append(itemID)
        if suppressionOrder.count > 64 {
            let removed = suppressionOrder.removeFirst()
            suppressedItemIDs.remove(removed)
        }
    }

    private mutating func unsuppress(itemID: String) {
        suppressedItemIDs.remove(itemID)
        suppressionOrder.removeAll { $0 == itemID }
    }
}
