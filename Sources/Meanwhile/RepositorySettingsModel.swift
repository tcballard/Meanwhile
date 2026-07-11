import Foundation
import MeanwhileCore

@MainActor
final class RepositorySettingsModel: ObservableObject {
    @Published private(set) var includesAllRepositories: Bool
    @Published private(set) var selectedRepositories: Set<String>
    @Published private(set) var availableRepositories: [String] = []
    @Published private(set) var isLoading = false
    @Published private(set) var errorMessage: String?

    private let preferences: RepositoryPreferences
    private let catalog: GitHubRepositoryCatalog
    private let selectionDidChange: () -> Void
    private var hasLoaded = false

    init(
        preferences: RepositoryPreferences,
        catalog: GitHubRepositoryCatalog = GitHubRepositoryCatalog(),
        selectionDidChange: @escaping () -> Void
    ) {
        self.preferences = preferences
        self.catalog = catalog
        self.selectionDidChange = selectionDidChange
        let snapshot = preferences.snapshot
        includesAllRepositories = snapshot.includesAllRepositories
        selectedRepositories = snapshot.selectedRepositories
    }

    func loadRepositories(force: Bool = false) {
        guard !isLoading, force || !hasLoaded else { return }
        isLoading = true
        errorMessage = nil

        let catalog = self.catalog
        Task.detached {
            do {
                let repositories = try catalog.repositories()
                await MainActor.run { [weak self] in
                    guard let self else { return }
                    availableRepositories = Array(
                        Set(repositories).union(selectedRepositories)
                    ).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
                    hasLoaded = true
                    isLoading = false
                }
            } catch {
                await MainActor.run { [weak self] in
                    self?.errorMessage = error.localizedDescription
                    self?.isLoading = false
                }
            }
        }
    }

    func setIncludesAllRepositories(_ includesAll: Bool) {
        if !includesAll, selectedRepositories.isEmpty {
            selectedRepositories = Set(availableRepositories)
            preferences.setSelectedRepositories(selectedRepositories)
        }
        includesAllRepositories = includesAll
        preferences.setIncludesAllRepositories(includesAll)
        selectionDidChange()
    }

    func isSelected(_ repository: String) -> Bool {
        includesAllRepositories || selectedRepositories.contains(repository)
    }

    func setRepository(_ repository: String, isSelected: Bool) {
        if isSelected {
            selectedRepositories.insert(repository)
        } else {
            selectedRepositories.remove(repository)
        }
        preferences.setRepository(repository, isSelected: isSelected)
        selectionDidChange()
    }
}
