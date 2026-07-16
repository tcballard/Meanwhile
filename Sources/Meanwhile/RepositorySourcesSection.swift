import SwiftUI

struct RepositorySourcesSection: View {
    @Binding var searchText: String
    @Binding var includesAllRepositories: Bool
    let availableRepositories: [String]
    let filteredRepositories: [String]
    let isLoading: Bool
    let errorMessage: String?
    let refresh: () -> Void
    let isSelected: (String) -> Bool
    let setRepository: (String, Bool) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 11) {
            Toggle("Include all accessible repositories", isOn: $includesAllRepositories)
                .toggleStyle(.checkbox)

            Text("Turn this off to surface review and CI work only from selected repositories.")
                .font(.caption)
                .foregroundStyle(.secondary)

            HStack(spacing: 8) {
                TextField("Filter repositories", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                Button(action: refresh) {
                    Image(systemName: "arrow.clockwise")
                }
                .help("Refresh repositories")
                .disabled(isLoading)
            }

            repositoryList
        }
    }

    @ViewBuilder
    private var repositoryList: some View {
        if isLoading && availableRepositories.isEmpty {
            VStack(spacing: 8) {
                ProgressView()
                Text("Loading repositories from GitHub")
                    .font(.callout.weight(.medium))
                Text("Meanwhile uses the GitHub CLI session already on this Mac.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, minHeight: 150)
        } else if let errorMessage, availableRepositories.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Couldn’t load repositories")
                    .font(.headline)
                Text(errorMessage)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Try Again", action: refresh)
            }
            .frame(maxWidth: .infinity, minHeight: 150, alignment: .topLeading)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(filteredRepositories, id: \.self) { repository in
                        RepositoryRow(
                            repository: repository,
                            includesAllRepositories: includesAllRepositories,
                            isSelected: Binding(
                                get: { isSelected(repository) },
                                set: { setRepository(repository, $0) }
                            )
                        )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(10)
            }
            .frame(maxWidth: .infinity, minHeight: 150, maxHeight: 210)
            .background(.quaternary.opacity(0.16), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
            .overlay {
                if filteredRepositories.isEmpty {
                    ContentUnavailableView(
                        "No matching repositories",
                        systemImage: "magnifyingglass",
                        description: Text("Try a different filter or refresh GitHub.")
                    )
                    .foregroundStyle(.secondary)
                }
            }
        }
    }
}

private struct RepositoryRow: View {
    let repository: String
    let includesAllRepositories: Bool
    @Binding var isSelected: Bool

    var body: some View {
        if includesAllRepositories {
            HStack(spacing: 8) {
                Image(systemName: "checkmark.circle.fill")
                    .font(.callout)
                    .foregroundStyle(.secondary)
                Text(repository)
                    .foregroundStyle(.primary)
                Spacer()
            }
            .font(.callout)
            .padding(.vertical, 1)
            .accessibilityElement(children: .combine)
            .accessibilityLabel("\(repository), included")
        } else {
            Toggle(repository, isOn: $isSelected)
                .toggleStyle(.checkbox)
        }
    }
}
