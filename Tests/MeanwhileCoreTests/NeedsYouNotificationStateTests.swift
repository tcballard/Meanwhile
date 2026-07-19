import Foundation
import XCTest
@testable import MeanwhileCore

final class NeedsYouNotificationStateTests: XCTestCase {
    private let origin = Date(timeIntervalSince1970: 1_000)

    func testDisabledOrUnauthorizedSettingsDoNotArmOrDeliver() {
        for permission in [
            NeedsYouNotificationPermission.unknown,
            .notDetermined,
            .denied,
            .limited,
            .unavailable
        ] {
            var state = NeedsYouNotificationState()
            XCTAssertEqual(
                state.observe(
                    settings: settings(enabled: true),
                    permission: permission,
                    phase: .needsYou,
                    item: needsYouItem("A"),
                    now: origin.addingTimeInterval(120)
                ),
                .none,
                "Unexpected delivery for \(permission)"
            )
        }

        var state = NeedsYouNotificationState()
        XCTAssertEqual(
            state.observe(
                settings: settings(enabled: false),
                permission: .authorized,
                phase: .needsYou,
                item: needsYouItem("A"),
                now: origin.addingTimeInterval(120)
            ),
            .none
        )
    }

    func testReviewsAndFailingCIDoNotArmOrDeliver() {
        for item in [reviewItem(), ciItem()] {
            var state = NeedsYouNotificationState()
            XCTAssertEqual(
                state.observe(
                    settings: settings(enabled: true),
                    permission: .authorized,
                    phase: .thinking,
                    item: item,
                    now: origin.addingTimeInterval(120)
                ),
                .none
            )
            XCTAssertEqual(
                state.observe(
                    settings: settings(enabled: true),
                    permission: .authorized,
                    phase: .needsYou,
                    item: item,
                    now: origin.addingTimeInterval(120)
                ),
                .none
            )
        }
    }

    func testArmsBeforeDeadlineThenDeliversOnFirstConfirmingPollAtDeadline() {
        var state = NeedsYouNotificationState()
        let item = needsYouItem("A", createdAt: origin)

        XCTAssertEqual(observe(item, with: &state, now: origin), .none)
        XCTAssertEqual(
            observe(item, with: &state, now: origin.addingTimeInterval(59.999)),
            .none
        )
        XCTAssertEqual(
            observe(item, with: &state, now: origin.addingTimeInterval(60)),
            .deliver(item: item)
        )
    }

    func testRepeatedPollingDeliversOnlyOnce() {
        var state = NeedsYouNotificationState()
        let item = needsYouItem("A", createdAt: origin)

        XCTAssertEqual(observe(item, with: &state, now: origin), .none)
        XCTAssertEqual(
            observe(item, with: &state, now: origin.addingTimeInterval(60)),
            .deliver(item: item)
        )
        XCTAssertEqual(
            observe(item, with: &state, now: origin.addingTimeInterval(61)),
            .none
        )
        XCTAssertEqual(
            observe(item, with: &state, now: origin.addingTimeInterval(300)),
            .none
        )
    }

    func testAlreadyElapsedDelayDeliversImmediatelyFromFreshPresentation() {
        var state = NeedsYouNotificationState()
        let item = needsYouItem("A", createdAt: origin)

        XCTAssertEqual(
            observe(item, with: &state, now: origin.addingTimeInterval(120)),
            .deliver(item: item)
        )
        XCTAssertEqual(
            observe(item, with: &state, now: origin.addingTimeInterval(121)),
            .none
        )
    }

    func testChangingSelectedItemCancelsPreviousAndArmsReplacement() {
        var state = NeedsYouNotificationState()
        let first = needsYouItem("A", createdAt: origin)
        let second = needsYouItem("B", createdAt: origin.addingTimeInterval(10))
        XCTAssertEqual(observe(first, with: &state, now: origin), .none)

        XCTAssertEqual(
            observe(second, with: &state, now: origin.addingTimeInterval(20)),
            .replace(previousItemID: first.id, delivery: nil)
        )
        XCTAssertEqual(
            observe(second, with: &state, now: origin.addingTimeInterval(70)),
            .deliver(item: second)
        )
    }

    func testChangingToAlreadyDueItemCancelsPreviousAndDeliversReplacement() {
        var state = NeedsYouNotificationState()
        let first = needsYouItem("A", createdAt: origin)
        let second = needsYouItem("B", createdAt: origin.addingTimeInterval(-120))
        XCTAssertEqual(observe(first, with: &state, now: origin), .none)

        XCTAssertEqual(
            observe(second, with: &state, now: origin),
            .replace(previousItemID: first.id, delivery: second)
        )
        XCTAssertEqual(observe(second, with: &state, now: origin), .none)
    }

    func testReasonChangeForSameItemDoesNotDuplicateDelivery() {
        var state = NeedsYouNotificationState()
        let generic = needsYouItem("A", reason: .generic, createdAt: origin)
        let approval = needsYouItem("A", reason: .approvalRequired, createdAt: origin)

        XCTAssertEqual(observe(generic, with: &state, now: origin), .none)
        XCTAssertEqual(
            observe(approval, with: &state, now: origin.addingTimeInterval(60)),
            .deliver(item: approval)
        )
        XCTAssertEqual(
            observe(generic, with: &state, now: origin.addingTimeInterval(61)),
            .none
        )
    }

    func testShorteningDelayBelowElapsedTimeDeliversOnNextPoll() {
        var state = NeedsYouNotificationState()
        let item = needsYouItem("A", createdAt: origin)
        XCTAssertEqual(
            observe(
                item,
                with: &state,
                now: origin,
                delay: .fiveMinutes
            ),
            .none
        )

        XCTAssertEqual(
            observe(
                item,
                with: &state,
                now: origin.addingTimeInterval(90),
                delay: .oneMinute
            ),
            .deliver(item: item)
        )
    }

    func testResolutionDisableAndPermissionRevocationCancelCurrentItem() {
        let item = needsYouItem("A")

        var resolutionState = NeedsYouNotificationState()
        XCTAssertEqual(observe(item, with: &resolutionState, now: origin), .none)
        XCTAssertEqual(
            resolutionState.observe(
                settings: settings(enabled: true),
                permission: .authorized,
                phase: .thinking,
                item: nil,
                now: origin
            ),
            .cancel(itemID: item.id)
        )
        XCTAssertEqual(
            resolutionState.observe(
                settings: settings(enabled: true),
                permission: .authorized,
                phase: .idle,
                item: nil,
                now: origin
            ),
            .none
        )

        var disabledState = NeedsYouNotificationState()
        XCTAssertEqual(observe(item, with: &disabledState, now: origin), .none)
        XCTAssertEqual(
            disabledState.observe(
                settings: settings(enabled: false),
                permission: .authorized,
                phase: .needsYou,
                item: item,
                now: origin
            ),
            .cancel(itemID: item.id)
        )

        var deniedState = NeedsYouNotificationState()
        XCTAssertEqual(observe(item, with: &deniedState, now: origin), .none)
        XCTAssertEqual(
            deniedState.observe(
                settings: settings(enabled: true),
                permission: .denied,
                phase: .needsYou,
                item: item,
                now: origin
            ),
            .cancel(itemID: item.id)
        )
    }

    func testAcknowledgementCancelsAndSuppressesUntilItemChanges() {
        var state = NeedsYouNotificationState()
        let first = needsYouItem("A", createdAt: origin)
        let second = needsYouItem("B", createdAt: origin)

        XCTAssertEqual(observe(first, with: &state, now: origin), .none)
        XCTAssertEqual(
            observe(first, with: &state, now: origin.addingTimeInterval(60)),
            .deliver(item: first)
        )
        XCTAssertEqual(state.acknowledge(itemID: first.id), .cancel(itemID: first.id))
        XCTAssertEqual(
            observe(first, with: &state, now: origin.addingTimeInterval(300)),
            .none
        )
        XCTAssertEqual(
            observe(second, with: &state, now: origin.addingTimeInterval(300)),
            .replace(previousItemID: first.id, delivery: second)
        )
    }

    func testAcknowledgingUnknownItemStillRequestsScopedCancellation() {
        var state = NeedsYouNotificationState()

        XCTAssertEqual(
            state.acknowledge(itemID: "needs-you:stale"),
            .cancel(itemID: "needs-you:stale")
        )
    }

    func testDeliveredOrAcknowledgedItemStaysSuppressedAfterTemporaryDisappearance() {
        var deliveredState = NeedsYouNotificationState()
        let delivered = needsYouItem("delivered", createdAt: origin)
        XCTAssertEqual(
            observe(delivered, with: &deliveredState, now: origin.addingTimeInterval(60)),
            .deliver(item: delivered)
        )
        XCTAssertEqual(
            deliveredState.observe(
                settings: settings(enabled: true),
                permission: .authorized,
                phase: .thinking,
                item: nil,
                now: origin.addingTimeInterval(61)
            ),
            .cancel(itemID: delivered.id)
        )
        XCTAssertEqual(
            observe(delivered, with: &deliveredState, now: origin.addingTimeInterval(900)),
            .none
        )

        var acknowledgedState = NeedsYouNotificationState()
        let acknowledged = needsYouItem("acknowledged", createdAt: origin)
        XCTAssertEqual(observe(acknowledged, with: &acknowledgedState, now: origin), .none)
        XCTAssertEqual(
            acknowledgedState.acknowledge(itemID: acknowledged.id),
            .cancel(itemID: acknowledged.id)
        )
        _ = acknowledgedState.observe(
            settings: settings(enabled: true),
            permission: .authorized,
            phase: .thinking,
            item: nil,
            now: origin.addingTimeInterval(1)
        )
        XCTAssertEqual(
            observe(acknowledged, with: &acknowledgedState, now: origin.addingTimeInterval(900)),
            .none
        )
    }

    func testRestoredReceiptSuppressesDeliveryAcrossStateRecreation() {
        var state = NeedsYouNotificationState()
        let item = needsYouItem("restored", createdAt: origin)
        state.restoreReceipt(itemID: item.id)

        XCTAssertEqual(
            observe(item, with: &state, now: origin.addingTimeInterval(900)),
            .none
        )
    }

    func testFailedDeliveryRearmsWithBackoffInsteadOfRetryingEveryPoll() {
        var state = NeedsYouNotificationState()
        let item = needsYouItem("retry", createdAt: origin)
        let failedAt = origin.addingTimeInterval(60)

        XCTAssertEqual(observe(item, with: &state, now: failedAt), .deliver(item: item))
        state.deliveryFailed(
            itemID: item.id,
            retryNotBefore: failedAt.addingTimeInterval(60)
        )
        XCTAssertEqual(
            observe(item, with: &state, now: failedAt.addingTimeInterval(59)),
            .none
        )
        XCTAssertEqual(
            observe(item, with: &state, now: failedAt.addingTimeInterval(60)),
            .deliver(item: item)
        )
    }

    private func observe(
        _ item: WorkItem,
        with state: inout NeedsYouNotificationState,
        now: Date,
        delay: NeedsYouNotificationDelay = .oneMinute
    ) -> NeedsYouNotificationTransition {
        state.observe(
            settings: settings(enabled: true, delay: delay),
            permission: .authorized,
            phase: .needsYou,
            item: item,
            now: now
        )
    }

    private func settings(
        enabled: Bool,
        delay: NeedsYouNotificationDelay = .oneMinute
    ) -> NeedsYouNotificationSettings {
        NeedsYouNotificationSettings(isEnabled: enabled, delay: delay)
    }

    private func needsYouItem(
        _ id: String,
        reason: AgentAttentionReason = .generic,
        createdAt: Date? = nil
    ) -> WorkItem {
        let createdAt = createdAt ?? origin
        let session = AgentSessionState(
            provider: .codex,
            sessionID: id,
            cwd: "/tmp/Meanwhile",
            phase: .needsYou,
            attentionReason: reason,
            enteredAt: createdAt,
            updatedAt: createdAt
        )
        return WorkItem(
            id: "needs-you:\(id)",
            kind: .needsYou,
            title: "Codex needs you",
            detail: session.cwd,
            createdAt: createdAt,
            session: session
        )
    }

    private func reviewItem() -> WorkItem {
        WorkItem(
            id: "review",
            kind: .review,
            title: "Review #78",
            detail: "acme/repo",
            createdAt: origin
        )
    }

    private func ciItem() -> WorkItem {
        WorkItem(
            id: "ci",
            kind: .failingCI,
            title: "CI failed on #42",
            detail: "acme/repo",
            createdAt: origin
        )
    }
}
