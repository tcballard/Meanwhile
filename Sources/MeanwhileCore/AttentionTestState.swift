import Foundation

public struct AttentionTestState: Equatable, Sendable {
    public enum Transition: Equatable, Sendable {
        case none
        case started(generation: UInt64)
        case finished
        case preempted
    }

    public private(set) var generation: UInt64 = 0
    public private(set) var isActive = false

    public init() {}

    public mutating func start(realAttentionIsActive: Bool) -> Transition {
        guard !realAttentionIsActive, !isActive else { return .none }
        generation &+= 1
        isActive = true
        return .started(generation: generation)
    }

    public mutating func observeRealAttention(isActive: Bool) -> Transition {
        guard isActive, self.isActive else { return .none }
        self.isActive = false
        return .preempted
    }

    public mutating func finish(generation: UInt64) -> Transition {
        guard isActive, generation == self.generation else { return .none }
        isActive = false
        return .finished
    }

    public mutating func cancel() -> Transition {
        guard isActive else { return .none }
        isActive = false
        return .finished
    }
}
