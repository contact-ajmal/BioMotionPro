import SwiftUI
import simd

// MARK: - Theme Definition

/// Represents a complete visual theme for the application
public struct Theme: Codable, Identifiable, Equatable, Sendable {
    public var id: String { name }
    
    public let name: String
    public let description: String
    
    // Scene colors
    public let backgroundColor: CodableColor
    public let gridColor: CodableColor
    public let axisXColor: CodableColor
    public let axisYColor: CodableColor
    public let axisZColor: CodableColor
    
    // Marker colors
    public let markerDefaultColor: CodableColor
    public let markerSelectedColor: CodableColor
    public let markerOccludedColor: CodableColor
    
    // Skeleton colors (per body part)
    public let skeletonHeadColor: CodableColor
    public let skeletonSpineColor: CodableColor
    public let skeletonPelvisColor: CodableColor
    public let skeletonLeftArmColor: CodableColor
    public let skeletonRightArmColor: CodableColor
    public let skeletonLeftLegColor: CodableColor
    public let skeletonRightLegColor: CodableColor
    
    // UI colors
    public let accentColor: CodableColor
    public let textPrimaryColor: CodableColor
    public let textSecondaryColor: CodableColor
    
    // Computed SIMD colors for rendering
    public var backgroundSIMD: SIMD4<Float> { backgroundColor.simd }
    public var gridSIMD: SIMD4<Float> { gridColor.simd }
    public var markerDefaultSIMD: SIMD4<Float> { markerDefaultColor.simd }
    public var markerSelectedSIMD: SIMD4<Float> { markerSelectedColor.simd }
}

// MARK: - Codable Color Wrapper

/// Color wrapper that can be encoded/decoded from JSON
public struct CodableColor: Codable, Equatable, Sendable {
    public let red: Double
    public let green: Double
    public let blue: Double
    public let alpha: Double
    
    public init(red: Double, green: Double, blue: Double, alpha: Double = 1.0) {
        self.red = red
        self.green = green
        self.blue = blue
        self.alpha = alpha
    }
    
    public init(_ color: Color) {
        // Convert SwiftUI Color to components
        let nsColor = NSColor(color)
        self.red = Double(nsColor.redComponent)
        self.green = Double(nsColor.greenComponent)
        self.blue = Double(nsColor.blueComponent)
        self.alpha = Double(nsColor.alphaComponent)
    }
    
    public init(hex: String) {
        var hexSanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        hexSanitized = hexSanitized.replacingOccurrences(of: "#", with: "")
        
        var rgb: UInt64 = 0
        Scanner(string: hexSanitized).scanHexInt64(&rgb)
        
        self.red = Double((rgb & 0xFF0000) >> 16) / 255.0
        self.green = Double((rgb & 0x00FF00) >> 8) / 255.0
        self.blue = Double(rgb & 0x0000FF) / 255.0
        self.alpha = 1.0
    }
    
    public var color: Color {
        Color(red: red, green: green, blue: blue, opacity: alpha)
    }
    
    public var nsColor: NSColor {
        NSColor(red: red, green: green, blue: blue, alpha: alpha)
    }
    
    public var simd: SIMD4<Float> {
        SIMD4<Float>(Float(red), Float(green), Float(blue), Float(alpha))
    }
}

// MARK: - Preset Themes

extension Theme {
    /// Dark theme (default) - Professional dark mode
    public static let dark = Theme(
        name: "Dark",
        description: "Professional dark mode for low-light environments",
        backgroundColor: CodableColor(hex: "1A1A2E"),
        gridColor: CodableColor(red: 0.3, green: 0.3, blue: 0.3, alpha: 0.5),
        axisXColor: CodableColor(hex: "FF6B6B"),
        axisYColor: CodableColor(hex: "4ECDC4"),
        axisZColor: CodableColor(hex: "45B7D1"),
        markerDefaultColor: CodableColor(hex: "FFD93D"),
        markerSelectedColor: CodableColor(hex: "FF6B6B"),
        markerOccludedColor: CodableColor(red: 0.5, green: 0.5, blue: 0.5, alpha: 0.3),
        skeletonHeadColor: CodableColor(hex: "E0E0E0"),
        skeletonSpineColor: CodableColor(hex: "90CAF9"),
        skeletonPelvisColor: CodableColor(hex: "CE93D8"),
        skeletonLeftArmColor: CodableColor(hex: "81C784"),
        skeletonRightArmColor: CodableColor(hex: "FFB74D"),
        skeletonLeftLegColor: CodableColor(hex: "4FC3F7"),
        skeletonRightLegColor: CodableColor(hex: "F06292"),
        accentColor: CodableColor(hex: "6C63FF"),
        textPrimaryColor: CodableColor(hex: "FFFFFF"),
        textSecondaryColor: CodableColor(hex: "B0B0B0")
    )
    
    /// Light theme - Clean bright mode
    public static let light = Theme(
        name: "Light",
        description: "Clean bright mode for well-lit environments",
        backgroundColor: CodableColor(hex: "F5F5F5"),
        gridColor: CodableColor(red: 0.6, green: 0.6, blue: 0.6, alpha: 0.5),
        axisXColor: CodableColor(hex: "D32F2F"),
        axisYColor: CodableColor(hex: "388E3C"),
        axisZColor: CodableColor(hex: "1976D2"),
        markerDefaultColor: CodableColor(hex: "FF9800"),
        markerSelectedColor: CodableColor(hex: "E91E63"),
        markerOccludedColor: CodableColor(red: 0.7, green: 0.7, blue: 0.7, alpha: 0.3),
        skeletonHeadColor: CodableColor(hex: "424242"),
        skeletonSpineColor: CodableColor(hex: "1565C0"),
        skeletonPelvisColor: CodableColor(hex: "7B1FA2"),
        skeletonLeftArmColor: CodableColor(hex: "2E7D32"),
        skeletonRightArmColor: CodableColor(hex: "F57C00"),
        skeletonLeftLegColor: CodableColor(hex: "0288D1"),
        skeletonRightLegColor: CodableColor(hex: "C2185B"),
        accentColor: CodableColor(hex: "6200EE"),
        textPrimaryColor: CodableColor(hex: "212121"),
        textSecondaryColor: CodableColor(hex: "757575")
    )
    
    /// Clinical theme - Medical/research context
    public static let clinical = Theme(
        name: "Clinical",
        description: "Neutral tones for medical and research settings",
        backgroundColor: CodableColor(hex: "FAFAFA"),
        gridColor: CodableColor(red: 0.8, green: 0.8, blue: 0.85, alpha: 0.5),
        axisXColor: CodableColor(hex: "B71C1C"),
        axisYColor: CodableColor(hex: "1B5E20"),
        axisZColor: CodableColor(hex: "0D47A1"),
        markerDefaultColor: CodableColor(hex: "0077B6"),
        markerSelectedColor: CodableColor(hex: "00B4D8"),
        markerOccludedColor: CodableColor(red: 0.8, green: 0.8, blue: 0.8, alpha: 0.3),
        skeletonHeadColor: CodableColor(hex: "37474F"),
        skeletonSpineColor: CodableColor(hex: "455A64"),
        skeletonPelvisColor: CodableColor(hex: "546E7A"),
        skeletonLeftArmColor: CodableColor(hex: "607D8B"),
        skeletonRightArmColor: CodableColor(hex: "78909C"),
        skeletonLeftLegColor: CodableColor(hex: "90A4AE"),
        skeletonRightLegColor: CodableColor(hex: "B0BEC5"),
        accentColor: CodableColor(hex: "0077B6"),
        textPrimaryColor: CodableColor(hex: "263238"),
        textSecondaryColor: CodableColor(hex: "546E7A")
    )
    
    /// Sports theme - Energetic colors for athletics
    public static let sports = Theme(
        name: "Sports",
        description: "High-energy colors for sports performance analysis",
        backgroundColor: CodableColor(hex: "0F0F0F"),
        gridColor: CodableColor(red: 0.2, green: 0.3, blue: 0.2, alpha: 0.5),
        axisXColor: CodableColor(hex: "FF1744"),
        axisYColor: CodableColor(hex: "00E676"),
        axisZColor: CodableColor(hex: "00B0FF"),
        markerDefaultColor: CodableColor(hex: "FFEA00"),
        markerSelectedColor: CodableColor(hex: "FF1744"),
        markerOccludedColor: CodableColor(red: 0.4, green: 0.4, blue: 0.4, alpha: 0.3),
        skeletonHeadColor: CodableColor(hex: "FFFFFF"),
        skeletonSpineColor: CodableColor(hex: "00E676"),
        skeletonPelvisColor: CodableColor(hex: "FFEA00"),
        skeletonLeftArmColor: CodableColor(hex: "00B0FF"),
        skeletonRightArmColor: CodableColor(hex: "FF1744"),
        skeletonLeftLegColor: CodableColor(hex: "00E5FF"),
        skeletonRightLegColor: CodableColor(hex: "FF9100"),
        accentColor: CodableColor(hex: "00E676"),
        textPrimaryColor: CodableColor(hex: "FFFFFF"),
        textSecondaryColor: CodableColor(hex: "B0B0B0")
    )
    
    /// All preset themes
    public static let presets: [Theme] = [.dark, .light, .clinical, .sports]
}

// MARK: - Theme Manager

/// Manages theme loading, saving, and application
@MainActor
public class ThemeManager: ObservableObject {
    public static let shared = ThemeManager()
    
    @Published public var currentTheme: Theme = .dark
    @Published public var customThemes: [Theme] = []
    
    private let userDefaultsKey = "BioMotionPro.CurrentTheme"
    private let customThemesKey = "BioMotionPro.CustomThemes"
    
    private init() {
        loadSavedTheme()
        loadCustomThemes()
    }
    
    /// All available themes (presets + custom)
    public var allThemes: [Theme] {
        Theme.presets + customThemes
    }
    
    /// Apply a theme
    public func apply(_ theme: Theme) {
        currentTheme = theme
        saveCurrentTheme()
        
        // Post notification for views to update
        NotificationCenter.default.post(name: .themeDidChange, object: theme)
    }
    
    /// Save a custom theme
    public func saveCustomTheme(_ theme: Theme) {
        if let idx = customThemes.firstIndex(where: { $0.name == theme.name }) {
            customThemes[idx] = theme
        } else {
            customThemes.append(theme)
        }
        saveCustomThemes()
    }
    
    /// Delete a custom theme
    public func deleteCustomTheme(_ theme: Theme) {
        customThemes.removeAll { $0.name == theme.name }
        saveCustomThemes()
    }
    
    // MARK: - Persistence
    
    private func loadSavedTheme() {
        guard let themeName = UserDefaults.standard.string(forKey: userDefaultsKey),
              let theme = allThemes.first(where: { $0.name == themeName }) else {
            return
        }
        currentTheme = theme
    }
    
    private func saveCurrentTheme() {
        UserDefaults.standard.set(currentTheme.name, forKey: userDefaultsKey)
    }
    
    private func loadCustomThemes() {
        guard let data = UserDefaults.standard.data(forKey: customThemesKey),
              let themes = try? JSONDecoder().decode([Theme].self, from: data) else {
            return
        }
        customThemes = themes
    }
    
    private func saveCustomThemes() {
        guard let data = try? JSONEncoder().encode(customThemes) else { return }
        UserDefaults.standard.set(data, forKey: customThemesKey)
    }
    
    /// Export theme to JSON file
    public func exportTheme(_ theme: Theme, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(theme)
        try data.write(to: url)
    }
    
    /// Import theme from JSON file
    public func importTheme(from url: URL) throws -> Theme {
        let data = try Data(contentsOf: url)
        let theme = try JSONDecoder().decode(Theme.self, from: data)
        saveCustomTheme(theme)
        return theme
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let themeDidChange = Notification.Name("BioMotionPro.ThemeDidChange")
}

// MARK: - BodyPart Theme Colors Extension

extension BodyPart {
    /// Get the color for this body part from a theme
    public func color(from theme: Theme) -> SIMD4<Float> {
        switch self {
        case .head: return theme.skeletonHeadColor.simd
        case .spine: return theme.skeletonSpineColor.simd
        case .pelvis: return theme.skeletonPelvisColor.simd
        case .leftArm: return theme.skeletonLeftArmColor.simd
        case .rightArm: return theme.skeletonRightArmColor.simd
        case .leftLeg: return theme.skeletonLeftLegColor.simd
        case .rightLeg: return theme.skeletonRightLegColor.simd
        case .other: return theme.skeletonSpineColor.simd
        }
    }
}
