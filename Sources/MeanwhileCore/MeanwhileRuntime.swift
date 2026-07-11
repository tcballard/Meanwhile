import Foundation
import OSLog
import Peripheral

public final class MeanwhileRuntime: @unchecked Sendable {
    public typealias PresentationHandler = @Sendable (MeanwhilePresentation) -> Void

    private let logger = Logger(subsystem: "Meanwhile", category: "Runtime")
    private let sessionQueue: DispatchQueue
    private let sourceQueue: DispatchQueue
    private let eventStore: AgentEventStore
    private let reviewSource: GitHubReviewSource
    private let ciSource: GitHubCISource
    private let engine: MeanwhileEngine
    private let configuration: MeanwhileConfiguration
    private let statuslineStore: StatuslineSnapshotStore
    private let presentationHandler: PresentationHandler
    private let sessionTimer: PollTimer
    private let sourceTimer: PollTimer
    private let stateLock = NSLock()
    private var state = State()

    private struct State {
        var sessions: [AgentSessionState] = []
        var reviews: [ReviewItem] = []
        var failingCI: [FailingCIItem] = []
        var currentItem: WorkItem?
        var lastThinkingDate: Date?
        var sourcePollInFlight = false
        var stopped = false
    }

    public init(
        eventStore: AgentEventStore = AgentEventStore(),
        reviewSource: GitHubReviewSource = GitHubReviewSource(),
        ciSource: GitHubCISource = GitHubCISource(),
        configuration: MeanwhileConfiguration = MeanwhileConfiguration.load(),
        dispositions: ItemDispositionStore = ItemDispositionStore(),
        statuslineStore: StatuslineSnapshotStore = StatuslineSnapshotStore(),
        presentationHandler: @escaping PresentationHandler
    ) {
        let sessionQueue = DispatchQueue(label: "Meanwhile.AgentEvents", qos: .utility)
        let sourceQueue = DispatchQueue(label: "Meanwhile.TaskSources", qos: .utility)
        self.sessionQueue = sessionQueue
        self.sourceQueue = sourceQueue
        self.eventStore = eventStore
        self.reviewSource = reviewSource
        self.ciSource = ciSource
        self.configuration = configuration
        engine = MeanwhileEngine(configuration: configuration, dispositions: dispositions)
        self.statuslineStore = statuslineStore
        self.presentationHandler = presentationHandler
        sessionTimer = PollTimer(interval: 0.5, queue: sessionQueue)
        sourceTimer = PollTimer(interval: 60, queue: sourceQueue)
    }

    public func start() {
        withState { $0.stopped = false }
        sessionTimer.start(fireImmediately: true) { [weak self] in
            self?.pollSessions()
        }
        sourceTimer.start { [weak self] in
            self?.requestSourcePoll()
        }
    }

    public func stop() {
        withState { $0.stopped = true }
        sessionTimer.cancel()
        sourceTimer.cancel()
        try? statuslineStore.write(nil)
    }

    public func repositorySelectionDidChange() {
        sourceQueue.async { [weak self] in
            guard let self else { return }
            withState {
                $0.reviews = self.reviewSource.cachedReviews
                $0.failingCI = self.ciSource.cachedItems
            }
            present()
        }
    }

    public func snoozeCurrent(now: Date = Date()) {
        guard let item = withState({ $0.currentItem }) else { return }
        engine.snooze(item, now: now)
        present(now: now)
    }

    public func dismissCurrent(now: Date = Date()) {
        guard let item = withState({ $0.currentItem }) else { return }
        engine.dismiss(item)
        present(now: now)
    }

    private func pollSessions(now: Date = Date()) {
        let sessions = eventStore.sessions(
            now: now,
            staleAfter: configuration.sessionStaleSeconds,
            activeStaleAfter: configuration.activeSessionStaleSeconds
        )
        let shouldPoll = withState { state -> Bool in
            guard !state.stopped else { return false }
            state.sessions = sessions
            if sessions.contains(where: { $0.phase == .thinking }) {
                state.lastThinkingDate = now
                return true
            }
            return false
        }
        present(now: now)
        if shouldPoll { requestSourcePoll(now: now) }
    }

    private func requestSourcePoll(now: Date = Date()) {
        let shouldStart = withState { state -> Bool in
            guard !state.stopped, !state.sourcePollInFlight else { return false }
            state.sourcePollInFlight = true
            return true
        }
        guard shouldStart else { return }
        sourceQueue.async { [weak self] in
            self?.pollSources(now: now)
        }
    }

    private func pollSources(now: Date) {
        defer { withState { $0.sourcePollInFlight = false } }
        let allowed = withState { state -> Bool in
            guard !state.stopped, let lastThinkingDate = state.lastThinkingDate else {
                return false
            }
            return now.timeIntervalSince(lastThinkingDate) <= 600
        }
        guard allowed else { return }

        if configuration.enableReviews {
            do {
                let reviews = try reviewSource.reviewsIfDue(pollingAllowed: true, now: now)
                withState { $0.reviews = reviews }
            } catch {
                logger.error("Review poll failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        if configuration.enableFailingCI {
            do {
                let items = try ciSource.itemsIfDue(pollingAllowed: true, now: now)
                withState { $0.failingCI = items }
            } catch {
                logger.error("CI poll failed: \(error.localizedDescription, privacy: .public)")
            }
        }
        present(now: now)
    }

    private func present(now: Date = Date()) {
        let snapshot = withState { ($0.stopped, $0.sessions, $0.reviews, $0.failingCI) }
        guard !snapshot.0 else { return }
        let presentation = engine.presentation(
            sessions: snapshot.1,
            reviews: snapshot.2,
            failingCI: snapshot.3,
            now: now
        )
        withState { $0.currentItem = presentation.item }
        let statusline = presentation.item.map {
            StatuslineSnapshot(text: MenuBarPresenter.statuslineText(item: $0), updatedAt: now)
        }
        try? statuslineStore.write(statusline)
        presentationHandler(presentation)
    }

    private func withState<Value>(_ body: (inout State) -> Value) -> Value {
        stateLock.lock()
        defer { stateLock.unlock() }
        return body(&state)
    }
}
