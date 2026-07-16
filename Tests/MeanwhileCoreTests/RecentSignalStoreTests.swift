import Foundation
import XCTest
@testable import MeanwhileCore

final class RecentSignalStoreTests: XCTestCase {
    func testStoresNewestSignalsWithinLimit() throws {
        let suiteName = "RecentSignalStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = RecentSignalStore(defaults: defaults, key: "signals", limit: 2)
        let start = Date(timeIntervalSince1970: 1_000)

        store.record(RecentSignal(kind: .reviewSurfaced, title: "Review #1", detail: "a/repo", date: start))
        store.record(RecentSignal(kind: .ciFailed, title: "CI failure", detail: "b/repo", date: start.addingTimeInterval(1)))
        store.record(RecentSignal(kind: .agentNeedsYou, title: "Codex needs you", detail: "/tmp", date: start.addingTimeInterval(2)))

        XCTAssertEqual(store.signals.map(\.title), ["Codex needs you", "CI failure"])
    }

    func testCoalescesImmediateDuplicateSignals() throws {
        let suiteName = "RecentSignalStoreTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        defer { defaults.removePersistentDomain(forName: suiteName) }
        let store = RecentSignalStore(defaults: defaults, key: "signals")
        let start = Date(timeIntervalSince1970: 2_000)
        let signal = RecentSignal(
            kind: .reviewSurfaced,
            title: "Review #78 surfaced",
            detail: "acme/repo",
            date: start
        )

        store.record(signal)
        store.record(
            RecentSignal(
                kind: signal.kind,
                title: signal.title,
                detail: signal.detail,
                date: start.addingTimeInterval(30)
            )
        )

        XCTAssertEqual(store.signals, [signal])
    }
}
