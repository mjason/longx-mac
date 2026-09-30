import SwiftUI

// Keep system materials and accessibility behavior, with a fallback on macOS 14–15.
extension View {
    @ViewBuilder
    func longXGlassButton(prominent: Bool = false) -> some View {
        if #available(macOS 26.0, *) {
            if prominent { self.buttonStyle(.glassProminent) }
            else { self.buttonStyle(.glass) }
        } else {
            if prominent { self.buttonStyle(.borderedProminent) }
            else { self.buttonStyle(.bordered) }
        }
    }

    @ViewBuilder
    func longXBackgroundExtension() -> some View {
        if #available(macOS 26.0, *) { self.backgroundExtensionEffect() }
        else { self }
    }

    @ViewBuilder
    func longXGlassPanel() -> some View {
        if #available(macOS 26.0, *) {
            self.glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        } else {
            self.background(.regularMaterial, in: RoundedRectangle(cornerRadius: 16))
        }
    }
}
