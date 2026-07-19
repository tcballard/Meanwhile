import MeanwhileCore
import SwiftUI

struct SettingsSectionHeader: View {
    let title: String
    var trailing: String? = nil
    var trailingTint: Color = Color(nsColor: .tertiaryLabelColor)
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
                    .foregroundStyle(trailingTint)
            }
            if showsProgress {
                ProgressView()
                    .controlSize(.small)
                    .accessibilityLabel("\(title) in progress")
            }
        }
    }
}

struct CollapsibleSettingsSection<Content: View>: View {
    let title: String
    var trailing: String? = nil
    var trailingTint: Color = Color(nsColor: .tertiaryLabelColor)
    @Binding var isExpanded: Bool
    var showsProgress = false
    private let content: Content

    init(
        title: String,
        trailing: String? = nil,
        trailingTint: Color = Color(nsColor: .tertiaryLabelColor),
        isExpanded: Binding<Bool>,
        showsProgress: Bool = false,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.trailing = trailing
        self.trailingTint = trailingTint
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
                trailingTint: trailingTint,
                showsProgress: showsProgress
            )
        }
    }
}

struct SettingsInlineMessage: View {
    let message: String
    let systemImage: String
    let tint: Color

    init(_ message: String, systemImage: String, tint: Color) {
        self.message = message
        self.systemImage = systemImage
        self.tint = tint
    }

    var body: some View {
        Label(message, systemImage: systemImage)
            .font(.caption)
            .foregroundStyle(tint)
            .padding(.leading, 142)
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
