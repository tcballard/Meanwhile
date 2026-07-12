import Foundation
import XCTest
@testable import MeanwhileCore

final class MenuBarPresenterTests: XCTestCase {
    func testUsesDistinctIconsForEachAgentPhase() {
        XCTAssertEqual(MenuBarPresenter.iconName(phase: .idle), "rectangle.stack")
        XCTAssertEqual(MenuBarPresenter.iconName(phase: .thinking), "rectangle.stack.fill")
        XCTAssertEqual(MenuBarPresenter.iconName(phase: .needsYou), "exclamationmark.bubble.fill")
    }

    func testFormatsEachItemKindCompactly() {
        XCTAssertNil(MenuBarPresenter.statusText(item: nil))
        XCTAssertEqual(MenuBarPresenter.statusText(item: item(.needsYou, title: "Claude needs you")), "Needs you")
        XCTAssertEqual(MenuBarPresenter.statusText(item: item(.failingCI, title: "CI failed on #4")), "CI!")
        XCTAssertEqual(MenuBarPresenter.statusText(item: item(.review, title: "Review #78")), "#78")
    }

    private func item(_ kind: WorkItemKind, title: String) -> WorkItem {
        WorkItem(
            id: UUID().uuidString,
            kind: kind,
            title: title,
            detail: "acme/repo",
            createdAt: Date(timeIntervalSince1970: 1)
        )
    }
}
