import Foundation

public struct RepositorySelectionSnapshot: Equatable, Sendable {
    public var includesAllRepositories: Bool
    public var selectedRepositories: Set<String>

    public init(
        includesAllRepositories: Bool,
        selectedRepositories: Set<String>
    ) {
        self.includesAllRepositories = includesAllRepositories
        self.selectedRepositories = selectedRepositories
    }
}

public final class RepositoryPreferences: @unchecked Sendable {
    private enum Key {
        static let includesAll = "Meanwhile.repositories.includesAll"
        static let selected = "Meanwhile.repositories.selected"
    }

    private let lock = NSLock()
    private let defaults: UserDefaults
    private var state: RepositorySelectionSnapshot

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        let includesAll = defaults.object(forKey: Key.includesAll) == nil
            ? true
            : defaults.bool(forKey: Key.includesAll)
        state = RepositorySelectionSnapshot(
            includesAllRepositories: includesAll,
            selectedRepositories: Set(defaults.stringArray(forKey: Key.selected) ?? [])
        )
    }

    public var snapshot: RepositorySelectionSnapshot {
        lock.lock()
        defer { lock.unlock() }
        return state
    }

    public func allows(repository: String) -> Bool {
        let current = snapshot
        return current.includesAllRepositories
            || current.selectedRepositories.contains(repository)
    }

    public func setIncludesAllRepositories(_ includesAll: Bool) {
        update { $0.includesAllRepositories = includesAll }
    }

    public func setRepository(_ repository: String, isSelected: Bool) {
        update { state in
            if isSelected {
                state.selectedRepositories.insert(repository)
            } else {
                state.selectedRepositories.remove(repository)
            }
        }
    }

    public func setSelectedRepositories(_ repositories: Set<String>) {
        update { $0.selectedRepositories = repositories }
    }

    private func update(_ body: (inout RepositorySelectionSnapshot) -> Void) {
        lock.lock()
        defer { lock.unlock() }
        body(&state)
        defaults.set(state.includesAllRepositories, forKey: Key.includesAll)
        defaults.set(state.selectedRepositories.sorted(), forKey: Key.selected)
    }
}
