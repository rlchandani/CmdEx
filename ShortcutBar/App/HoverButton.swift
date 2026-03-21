import ShortcutBarCore
import SwiftUI

/// A button with macOS-native menu hover highlight (rounded accent background).
struct HoverButton<Content: View>: View {
    let action: () -> Void
    @ViewBuilder let label: () -> Content
    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                label()
            }
            .foregroundStyle(isHovered ? .white : .primary)
            .padding(.horizontal, SBConstants.rowPaddingH)
            .padding(.vertical, 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 4)
                    .fill(isHovered ? Color.accentColor : Color.clear)
            )
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .padding(.horizontal, 4)
    }
}
