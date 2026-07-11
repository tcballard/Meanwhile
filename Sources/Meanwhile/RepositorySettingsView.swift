import SwiftUI

struct RepositorySettingsView: View {
    @ObservedObject var model: RepositorySettingsModel
    @State private var searchText = ""

    private var filteredRepositories: [String] {
        guard !searchText.isEmpty else { return model.availableRepositories }
        return model.availableRepositories.filter {
            $0.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text("GitHub repositories")
                    .font(.title2.weight(.semibold))
                Text("Choose where Meanwhile can surface reviews and failing CI.")
                    .foregroundStyle(.secondary)
            }

            Toggle(
                "Include all accessible repositories",
                isOn: Binding(
                    get: { model.includesAllRepositories },
                    set: model.setIncludesAllRepositories
                )
            )
            .toggleStyle(.checkbox)

            Divider()

            HStack {
                TextField("Filter repositories", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                Button {
                    model.loadRepositories(force: true)
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh repositories")
                .disabled(model.isLoading)
            }

            repositoryList

            if !model.includesAllRepositories && model.selectedRepositories.isEmpty {
                Label("No repositories are connected.", systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
        }
        .padding(20)
        .frame(width: 460, height: 420)
        .task {
            model.loadRepositories()
        }
    }

    @ViewBuilder
    private var repositoryList: some View {
        if model.isLoading && model.availableRepositories.isEmpty {
            VStack(spacing: 8) {
                ProgressView()
                Text("Loading repositories from GitHub…")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if let errorMessage = model.errorMessage,
                  model.availableRepositories.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Couldn’t load repositories")
                    .font(.headline)
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Try Again") {
                    model.loadRepositories(force: true)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 9) {
                    ForEach(filteredRepositories, id: \.self) { repository in
                        Toggle(
                            repository,
                            isOn: Binding(
                                get: { model.isSelected(repository) },
                                set: { model.setRepository(repository, isSelected: $0) }
                            )
                        )
                        .toggleStyle(.checkbox)
                        .disabled(model.includesAllRepositories)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .overlay {
                if filteredRepositories.isEmpty {
                    Text("No matching repositories")
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}
