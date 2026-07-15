import MeanwhileCore
import SwiftUI

struct SettingsSectionHeader: View {
    let title: String
    var trailing: String? = nil
    var showsProgress = false

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
            if let trailing {
                Text(trailing)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            if showsProgress {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }
}

struct CollapsibleSettingsSection<Content: View>: View {
    let title: String
    var trailing: String? = nil
    @Binding var isExpanded: Bool
    var showsProgress = false
    private let content: Content

    init(
        title: String,
        trailing: String? = nil,
        isExpanded: Binding<Bool>,
        showsProgress: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.trailing = trailing
        _isExpanded = isExpanded
        self.showsProgress = showsProgress
        self.content = content()
    }

    var body: some View {
        DisclosureGroup(isExpanded: $isExpanded) {
            content
                .padding(.top, 10)
        } label: {
            SettingsSectionHeader(
                title: title,
                trailing: trailing,
                showsProgress: showsProgress
            )
        }
    }
}

func providerDisplayName(_ provider: AgentProvider) -> String {
    switch provider {
    case .claude: return "Claude"
    case .codex: return "Codex"
    case .unknown: return "Agent"
    }
}

func relativeDateString(_ date: Date, relativeTo reference: Date) -> String {
    if date >= reference { return "now" }
    let formatter = RelativeDateTimeFormatter()
    formatter.unitsStyle = .abbreviated
    return formatter.localizedString(for: date, relativeTo: reference)
}
