import SwiftUI

/// Centralized application theme definition
struct AppTheme {
    // Professional Dark Palette
    static let background = Color(nsColor: NSColor(red: 0.10, green: 0.10, blue: 0.12, alpha: 1.0)) // #1A1A1F
    static let surface = Color(nsColor: NSColor(red: 0.16, green: 0.16, blue: 0.18, alpha: 1.0))    // #29292E
    static let surfaceHighlight = Color(nsColor: NSColor(red: 0.22, green: 0.22, blue: 0.24, alpha: 1.0))
    
    static let accent = Color.blue
    static let textPrimary = Color.white.opacity(0.95)
    static let textSecondary = Color.white.opacity(0.60)
    
    static let cornerRadius: CGFloat = 8.0
}

/// A dedicated visual style for floating controls in the 3D view
struct GlassControlStyle: ViewModifier {
    func body(content: Content) -> some View {
        content
            .background(.regularMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .shadow(color: .black.opacity(0.2), radius: 10, x: 0, y: 4)
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
            )
    }
}

extension View {
    func glassControl() -> some View {
        modifier(GlassControlStyle())
    }
}
