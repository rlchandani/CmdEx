import SwiftUI

// MARK: - Settings Design System Helpers

extension Image {
    /// Standard settings row icon: secondary gray, 20pt frame, centered.
    func settingsIcon() -> some View {
        self
            .foregroundStyle(.secondary)
            .frame(width: 20, alignment: .center)
    }
}

extension Text {
    /// Standard settings caption/subtext: caption size, secondary color.
    func settingsCaption() -> some View {
        self.font(.caption).foregroundStyle(.secondary)
    }
}
