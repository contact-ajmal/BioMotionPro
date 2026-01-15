import SwiftUI
import simd

// MARK: - Marker Shape

/// Supported marker shapes for visualization
public enum MarkerShape: String, Codable, CaseIterable, Sendable {
    case sphere
    case cube
    case diamond
    case cross
    case ring
    
    public var displayName: String {
        switch self {
        case .sphere: return "Sphere"
        case .cube: return "Cube"
        case .diamond: return "Diamond"
        case .cross: return "Cross"
        case .ring: return "Ring"
        }
    }
    
    public var iconName: String {
        switch self {
        case .sphere: return "circle.fill"
        case .cube: return "square.fill"
        case .diamond: return "diamond.fill"
        case .cross: return "plus"
        case .ring: return "circle"
        }
    }
}

// MARK: - Marker Style

/// Visual style for a single marker
public struct MarkerStyle: Codable, Equatable, Sendable {
    public var shape: MarkerShape
    public var color: CodableColor
    public var size: Float  // Scale factor (1.0 = default)
    public var showLabel: Bool
    public var labelColor: CodableColor
    
    public init(
        shape: MarkerShape = .sphere,
        color: CodableColor = CodableColor(hex: "FFD93D"),
        size: Float = 1.0,
        showLabel: Bool = true,
        labelColor: CodableColor = CodableColor(hex: "FFFFFF")
    ) {
        self.shape = shape
        self.color = color
        self.size = size
        self.showLabel = showLabel
        self.labelColor = labelColor
    }
    
    public static let `default` = MarkerStyle()
}

// MARK: - Marker Style Configuration

/// Configuration mapping marker labels to custom styles
public struct MarkerStyleConfig: Codable, Sendable {
    public var name: String
    public var description: String
    public var markerStyles: [String: MarkerStyle]
    public var defaultStyle: MarkerStyle
    
    public init(
        name: String = "Default",
        description: String = "Default marker styling",
        markerStyles: [String: MarkerStyle] = [:],
        defaultStyle: MarkerStyle = .default
    ) {
        self.name = name
        self.description = description
        self.markerStyles = markerStyles
        self.defaultStyle = defaultStyle
    }
    
    /// Get style for a specific marker (with fallback to default)
    public func style(for label: String) -> MarkerStyle {
        markerStyles[label] ?? defaultStyle
    }
}

// MARK: - Preset Configurations

extension MarkerStyleConfig {
    /// Anatomical markers (left/right color coding)
    public static let anatomical = MarkerStyleConfig(
        name: "Anatomical",
        description: "Left/Right color coding with anatomical markers",
        markerStyles: [:],
        defaultStyle: .default
    )
    
    /// High contrast for clinical settings
    public static let highContrast = MarkerStyleConfig(
        name: "High Contrast",
        description: "Large markers with high visibility",
        markerStyles: [:],
        defaultStyle: MarkerStyle(
            shape: .sphere,
            color: CodableColor(hex: "00FF00"),
            size: 1.5,
            showLabel: true,
            labelColor: CodableColor(hex: "FFFFFF")
        )
    )
    
    /// Minimal style for clean presentations
    public static let minimal = MarkerStyleConfig(
        name: "Minimal",
        description: "Small markers without labels",
        markerStyles: [:],
        defaultStyle: MarkerStyle(
            shape: .sphere,
            color: CodableColor(hex: "888888"),
            size: 0.6,
            showLabel: false,
            labelColor: CodableColor(hex: "AAAAAA")
        )
    )
    
    public static let presets: [MarkerStyleConfig] = [.anatomical, .highContrast, .minimal]
}

// MARK: - Marker Style Manager

/// Manages marker style configurations
@MainActor
public class MarkerStyleManager: ObservableObject {
    public static let shared = MarkerStyleManager()
    
    @Published public var currentConfig: MarkerStyleConfig = MarkerStyleConfig()
    @Published public var customConfigs: [MarkerStyleConfig] = []
    
    private let userDefaultsKey = "BioMotionPro.MarkerStyleConfig"
    private let customConfigsKey = "BioMotionPro.CustomMarkerStyleConfigs"
    
    private init() {
        loadSavedConfig()
        loadCustomConfigs()
    }
    
    /// All available configurations
    public var allConfigs: [MarkerStyleConfig] {
        [MarkerStyleConfig()] + MarkerStyleConfig.presets + customConfigs
    }
    
    /// Apply a configuration
    public func apply(_ config: MarkerStyleConfig) {
        currentConfig = config
        saveCurrentConfig()
        
        NotificationCenter.default.post(name: .markerStyleDidChange, object: config)
    }
    
    /// Set style for a specific marker
    public func setStyle(_ style: MarkerStyle, forMarker label: String) {
        currentConfig.markerStyles[label] = style
        saveCurrentConfig()
        
        NotificationCenter.default.post(name: .markerStyleDidChange, object: currentConfig)
    }
    
    /// Reset marker to default style
    public func resetStyle(forMarker label: String) {
        currentConfig.markerStyles.removeValue(forKey: label)
        saveCurrentConfig()
        
        NotificationCenter.default.post(name: .markerStyleDidChange, object: currentConfig)
    }
    
    /// Save a custom configuration
    public func saveCustomConfig(_ config: MarkerStyleConfig) {
        if let idx = customConfigs.firstIndex(where: { $0.name == config.name }) {
            customConfigs[idx] = config
        } else {
            customConfigs.append(config)
        }
        saveCustomConfigs()
    }
    
    /// Delete a custom configuration
    public func deleteCustomConfig(_ config: MarkerStyleConfig) {
        customConfigs.removeAll { $0.name == config.name }
        saveCustomConfigs()
    }
    
    // MARK: - Persistence
    
    private func loadSavedConfig() {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey),
              let config = try? JSONDecoder().decode(MarkerStyleConfig.self, from: data) else {
            return
        }
        currentConfig = config
    }
    
    private func saveCurrentConfig() {
        guard let data = try? JSONEncoder().encode(currentConfig) else { return }
        UserDefaults.standard.set(data, forKey: userDefaultsKey)
    }
    
    private func loadCustomConfigs() {
        guard let data = UserDefaults.standard.data(forKey: customConfigsKey),
              let configs = try? JSONDecoder().decode([MarkerStyleConfig].self, from: data) else {
            return
        }
        customConfigs = configs
    }
    
    private func saveCustomConfigs() {
        guard let data = try? JSONEncoder().encode(customConfigs) else { return }
        UserDefaults.standard.set(data, forKey: customConfigsKey)
    }
    
    /// Export configuration to JSON file
    public func exportConfig(_ config: MarkerStyleConfig, to url: URL) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(config)
        try data.write(to: url)
    }
    
    /// Import configuration from JSON file
    public func importConfig(from url: URL) throws -> MarkerStyleConfig {
        let data = try Data(contentsOf: url)
        let config = try JSONDecoder().decode(MarkerStyleConfig.self, from: data)
        saveCustomConfig(config)
        return config
    }
}

// MARK: - Notifications

extension Notification.Name {
    static let markerStyleDidChange = Notification.Name("BioMotionPro.MarkerStyleDidChange")
}
