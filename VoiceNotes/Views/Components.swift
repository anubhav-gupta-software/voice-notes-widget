import SwiftUI

struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Theme.card, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }
}

struct FillButton: View {
    var title: String
    var systemImage: String?
    var color: Color = Theme.coral
    var action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
            }
            .font(.system(.body, design: .rounded).weight(.semibold))
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(color, in: Capsule())
            .foregroundStyle(.white)
        }
        .buttonStyle(PressStyle())
    }
}

struct PressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.72 : 1)
            .scaleEffect(configuration.isPressed ? 0.98 : 1)
    }
}

struct StatusBanner: View {
    var text: String

    var body: some View {
        Text(text)
            .font(.system(.subheadline, design: .rounded))
            .foregroundStyle(Theme.paper)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Theme.ink, in: Capsule())
            .frame(maxWidth: .infinity, alignment: .center)
            .accessibilityLabel(text)
    }
}

struct PaperScreen<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(Theme.paper.ignoresSafeArea())
    }
}
