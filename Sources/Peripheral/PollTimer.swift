import Foundation

/// A cancellable repeating timer whose callback always runs off the main queue.
public final class PollTimer: @unchecked Sendable {
    private let interval: TimeInterval
    private let leeway: DispatchTimeInterval
    private let queue: DispatchQueue
    private let lock = NSLock()
    private var source: DispatchSourceTimer?

    public init(
        interval: TimeInterval,
        leeway: DispatchTimeInterval = .milliseconds(100),
        queue: DispatchQueue? = nil
    ) {
        precondition(interval > 0, "PollTimer interval must be greater than zero")
        self.interval = interval
        self.leeway = leeway
        self.queue = queue ?? DispatchQueue(
            label: "Peripheral.PollTimer",
            qos: .utility
        )
    }

    deinit {
        cancel()
    }

    public func start(
        fireImmediately: Bool = false,
        handler: @escaping @Sendable () -> Void
    ) {
        lock.lock()
        defer { lock.unlock() }

        source?.cancel()

        let timer = DispatchSource.makeTimerSource(queue: queue)
        let deadline: DispatchTime = fireImmediately ? .now() : .now() + interval
        timer.schedule(deadline: deadline, repeating: interval, leeway: leeway)
        timer.setEventHandler(handler: handler)
        source = timer
        timer.resume()
    }

    public func cancel() {
        lock.lock()
        let timer = source
        source = nil
        lock.unlock()
        timer?.cancel()
    }
}
