import Foundation
import simd

// MARK: - Core Motion Capture Data Model

/// Complete motion capture acquisition data
public struct MotionCapture: Sendable {
    public let metadata: CaptureMetadata
    public let markers: MarkerData
    public let analogs: AnalogData
    public let events: [MotionEvent]
    public let segments: [Segment]?
    
    // Analyses
    public var calculatedAngles: [String: JointAngleSeries]?
    
    public var frameCount: Int { markers.frameCount }
    public var duration: Double { Double(markers.frameCount) / markers.frameRate }
    
    public init(metadata: CaptureMetadata, markers: MarkerData, analogs: AnalogData, events: [MotionEvent] = [], segments: [Segment]? = nil, calculatedAngles: [String: JointAngleSeries]? = nil) {
        self.metadata = metadata
        self.markers = markers
        self.analogs = analogs
        self.events = events
        self.segments = segments
        self.calculatedAngles = calculatedAngles
    }
}
 
/// Structure to hold a calculated angle series
public struct JointAngleSeries: Codable, Sendable {
    public let name: String
    public let unit: String // "deg" or "rad"
    public let values: [Float?] // One value per frame, nil if missing
    
    public init(name: String, unit: String = "deg", values: [Float?]) {
        self.name = name
        self.unit = unit
        self.values = values
    }
}

/// Metadata about the capture session
public struct CaptureMetadata: Sendable {
    public let filename: String
    public let subject: String?
    public let description: String?
    public let captureDate: Date?
    public let manufacturer: String?
    public let softwareVersion: String?
    
    public init(
        filename: String,
        subject: String? = nil,
        description: String? = nil,
        captureDate: Date? = nil,
        manufacturer: String? = nil,
        softwareVersion: String? = nil
    ) {
        self.filename = filename
        self.subject = subject
        self.description = description
        self.captureDate = captureDate
        self.manufacturer = manufacturer
        self.softwareVersion = softwareVersion
    }
}

// MARK: - Marker Data

/// 3D marker trajectory data
public struct MarkerData: Sendable {
    public let labels: [String]
    public let frameRate: Double
    public let positions: [[SIMD3<Float>?]]  // [frame][marker], nil = occluded
    public let residuals: [[Float?]]?        // Optional residual values per frame/marker
    
    public var frameCount: Int { positions.count }
    public var markerCount: Int { labels.count }
    
    /// Get position of a specific marker at a frame
    public func position(marker: Int, frame: Int) -> SIMD3<Float>? {
        guard frame >= 0, frame < frameCount,
              marker >= 0, marker < markerCount else { return nil }
        return positions[frame][marker]
    }
    
    /// Get position by label (exact or fuzzy)
    public func position(label: String, frame: Int, fuzzy: Bool = false) -> SIMD3<Float>? {
        if let idx = markerIndex(for: label) {
            return position(marker: idx, frame: frame)
        }
        
        if fuzzy {
            // Try Case Insensitive
            if let idx = labels.firstIndex(where: { $0.caseInsensitiveCompare(label) == .orderedSame }) {
                return position(marker: idx, frame: frame)
            }
            // Try removing spaces/underscores
            let cleanLabel = label.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "_", with: "")
            if let idx = labels.firstIndex(where: {
                $0.replacingOccurrences(of: " ", with: "").replacingOccurrences(of: "_", with: "").caseInsensitiveCompare(cleanLabel) == .orderedSame
            }) {
                return position(marker: idx, frame: frame)
            }
        }
        return nil
    }
    
    /// Get all marker positions for a specific frame
    public func positions(at frame: Int) -> [SIMD3<Float>?] {
        guard frame >= 0, frame < frameCount else { return [] }
        return positions[frame]
    }
    
    /// Get trajectory for a specific marker across all frames
    public func trajectory(for marker: Int) -> [SIMD3<Float>?] {
        guard marker >= 0, marker < markerCount else { return [] }
        return positions.map { $0[marker] }
    }
    
    /// Get marker index by label
    public func markerIndex(for label: String) -> Int? {
        labels.firstIndex(of: label)
    }
    
    public init(labels: [String], frameRate: Double, positions: [[SIMD3<Float>?]], residuals: [[Float?]]? = nil) {
        self.labels = labels
        self.frameRate = frameRate
        self.positions = positions
        self.residuals = residuals
    }
}

// MARK: - Analog Data

/// Multi-channel analog signal data (force plates, EMG, etc.)
public struct AnalogData: Sendable {
    public let channels: [AnalogChannel]
    public let sampleRate: Double
    
    public var channelCount: Int { channels.count }
    public var sampleCount: Int { channels.first?.data.count ?? 0 }
    public var duration: Double { Double(sampleCount) / sampleRate }
    
    /// Get channel by label
    public func channel(labeled: String) -> AnalogChannel? {
        channels.first { $0.label == labeled }
    }
    
    public init(channels: [AnalogChannel], sampleRate: Double) {
        self.channels = channels
        self.sampleRate = sampleRate
    }
    
    /// Empty analog data
    public static var empty: AnalogData {
        AnalogData(channels: [], sampleRate: 1000)
    }
}

/// Single analog channel
public struct AnalogChannel: Identifiable, Sendable {
    public let id: UUID
    public let label: String
    public let unit: String
    public let data: [Float]
    public let scale: Float
    public let offset: Float
    
    public var scaledData: [Float] {
        data.map { $0 * scale + offset }
    }
    
    public init(
        id: UUID = UUID(),
        label: String,
        unit: String = "",
        data: [Float],
        scale: Float = 1.0,
        offset: Float = 0.0
    ) {
        self.id = id
        self.label = label
        self.unit = unit
        self.data = data
        self.scale = scale
        self.offset = offset
    }
}

// MARK: - Events

/// Motion event (e.g., foot strike, toe off)
public struct MotionEvent: Identifiable, Sendable {
    public let id: UUID
    public let label: String
    public let time: Double       // Time in seconds
    public let frame: Int         // Frame number
    public let context: String?   // e.g., "Left", "Right", "General"
    public let iconName: String   // SF Symbol name
    
    public init(
        id: UUID = UUID(),
        label: String,
        time: Double,
        frame: Int,
        context: String? = nil,
        iconName: String = "flag.fill"
    ) {
        self.id = id
        self.label = label
        self.time = time
        self.frame = frame
        self.context = context
        self.iconName = iconName
    }
}

/// Predefined event types for gait analysis
public enum GaitEventType: String, CaseIterable, Sendable {
    case heelStrike = "Heel Strike"
    case toeOff = "Toe Off"
    case footFlat = "Foot Flat"
    case midSwing = "Mid Swing"
    
    public var iconName: String {
        switch self {
        case .heelStrike: return "arrow.down.to.line"
        case .toeOff: return "arrow.up.to.line"
        case .footFlat: return "square.fill"
        case .midSwing: return "arrow.forward"
        }
    }
}

// MARK: - Skeleton / Segments

/// Skeleton segment definition
public struct Segment: Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let parentIndex: Int?  // nil for root
    public let markers: [String]  // Marker labels attached to this segment
    public let color: SegmentColor
    
    public init(
        id: UUID = UUID(),
        name: String,
        parentIndex: Int? = nil,
        markers: [String] = [],
        color: SegmentColor = .default
    ) {
        self.id = id
        self.name = name
        self.parentIndex = parentIndex
        self.markers = markers
        self.color = color
    }
}

/// Color for skeleton segment rendering
public struct SegmentColor: Sendable {
    public let red: Float
    public let green: Float
    public let blue: Float
    public let alpha: Float
    
    public static let `default` = SegmentColor(red: 0.3, green: 0.6, blue: 1.0, alpha: 1.0)
    public static let left = SegmentColor(red: 1.0, green: 0.4, blue: 0.4, alpha: 1.0)
    public static let right = SegmentColor(red: 0.4, green: 0.4, blue: 1.0, alpha: 1.0)
}

// MARK: - Force Plate Data

/// Processed force plate data
public struct ForcePlateData: Sendable {
    public let plateIndex: Int
    public let corners: [SIMD3<Float>]  // 4 corners in global coordinates
    public let forces: [SIMD3<Float>]   // Ground reaction force vectors
    public let moments: [SIMD3<Float>]  // Moments about COP
    public let cop: [SIMD3<Float>?]     // Center of pressure, nil when unloaded
    public let sampleRate: Double
    
    public init(
        plateIndex: Int,
        corners: [SIMD3<Float>],
        forces: [SIMD3<Float>],
        moments: [SIMD3<Float>],
        cop: [SIMD3<Float>?],
        sampleRate: Double
    ) {
        self.plateIndex = plateIndex
        self.corners = corners
        self.forces = forces
        self.moments = moments
        self.cop = cop
        self.sampleRate = sampleRate
    }
}

/// Force plate configuration from C3D
public struct ForcePlateConfig: Sendable {
    public let type: Int              // C3D force plate type (1-4)
    public let corners: [SIMD3<Float>]
    public let origin: SIMD3<Float>
    public let channelIndices: [Int]  // Indices into analog channels
    
    public init(type: Int, corners: [SIMD3<Float>], origin: SIMD3<Float>, channelIndices: [Int]) {
        self.type = type
        self.corners = corners
        self.origin = origin
        self.channelIndices = channelIndices
    }
}

// MARK: - Joint Kinematics

/// Joint angle data
public struct JointAngleData: Sendable {
    public let jointName: String
    public let angles: [SIMD3<Float>]  // Euler angles (X, Y, Z) per frame
    public let velocities: [SIMD3<Float>]?
    public let accelerations: [SIMD3<Float>]?
    public let rotationOrder: RotationOrder
    
    public init(
        jointName: String,
        angles: [SIMD3<Float>],
        velocities: [SIMD3<Float>]? = nil,
        accelerations: [SIMD3<Float>]? = nil,
        rotationOrder: RotationOrder = .xyz
    ) {
        self.jointName = jointName
        self.angles = angles
        self.velocities = velocities
        self.accelerations = accelerations
        self.rotationOrder = rotationOrder
    }
}

/// Euler angle rotation order
public enum RotationOrder: String, Sendable {
    case xyz, xzy, yxz, yzx, zxy, zyx
}

// MARK: - Protocol for Data Parsers

/// Protocol for file format parsers
public protocol DataParser {
    static var supportedExtensions: [String] { get }
    
    func parse(from url: URL) async throws -> MotionCapture
    func write(_ capture: MotionCapture, to url: URL) async throws
}

/// Errors during parsing
public enum ParseError: Error, LocalizedError {
    case fileNotFound(URL)
    case invalidFormat(String)
    case unsupportedVersion(String)
    case corruptedData(String)
    case missingRequiredData(String)
    
    public var errorDescription: String? {
        switch self {
        case .fileNotFound(let url):
            return "File not found: \(url.path)"
        case .invalidFormat(let message):
            return "Invalid file format: \(message)"
        case .unsupportedVersion(let version):
            return "Unsupported file version: \(version)"
        case .corruptedData(let message):
            return "Corrupted data: \(message)"
        case .missingRequiredData(let field):
            return "Missing required data: \(field)"
        }
    }
}

// MARK: - Extensions

extension MarkerData {
    // Other extensions can go here
}


import Foundation

/// Export motion capture data to various formats
public struct DataExporter {
    
    // MARK: - CSV Export
    
    /// Export marker data to CSV format
    public static func exportMarkersToCSV(capture: MotionCapture) -> String {
        var csv = "Frame,Time"
        
        // Header: Frame, Time, Marker1_X, Marker1_Y, Marker1_Z, ...
        for label in capture.markers.labels {
            csv += ",\(label)_X,\(label)_Y,\(label)_Z"
        }
        csv += "\n"
        
        // Data rows
        let frameRate = capture.markers.frameRate
        for frame in 0..<capture.markers.frameCount {
            let time = Double(frame) / frameRate
            csv += "\(frame),\(String(format: "%.4f", time))"
            
            let positions = capture.markers.positions(at: frame)
            for pos in positions {
                if let p = pos {
                    csv += ",\(String(format: "%.4f", p.x)),\(String(format: "%.4f", p.y)),\(String(format: "%.4f", p.z))"
                } else {
                    csv += ",,,"; // Empty for missing data
                }
            }
            csv += "\n"
        }
        
        return csv
    }
    
    /// Export analog data to CSV format
    public static func exportAnalogsToCSV(capture: MotionCapture) -> String {
        guard !capture.analogs.channels.isEmpty else {
            return "No analog data"
        }
        
        var csv = "Sample,Time"
        
        // Header
        for channel in capture.analogs.channels {
            csv += ",\(channel.label)"
        }
        csv += "\n"
        
        // Find max sample count
        let maxSamples = capture.analogs.channels.map { $0.data.count }.max() ?? 0
        let sampleRate = capture.analogs.sampleRate
        
        // Data rows
        for sample in 0..<maxSamples {
            let time = Double(sample) / sampleRate
            csv += "\(sample),\(String(format: "%.6f", time))"
            
            for channel in capture.analogs.channels {
                if sample < channel.data.count {
                    csv += ",\(String(format: "%.6f", channel.data[sample]))"
                } else {
                    csv += ","
                }
            }
            csv += "\n"
        }
        
        return csv
    }
    
    /// Save string to file
    public static func saveToFile(_ content: String, url: URL) throws {
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
}

// MARK: - Marker Gap Filling

extension MarkerData {
    /// Fill gaps in marker data using linear interpolation
    public func withFilledGaps(maxGapSize: Int = 10) -> MarkerData {
        var filledPositions = self.positions
        
        for markerIdx in 0..<markerCount {
            var gapStart: Int? = nil
            
            for frame in 0..<frameCount {
                let hasData = filledPositions[frame][markerIdx] != nil
                
                if !hasData && gapStart == nil {
                    gapStart = frame
                } else if hasData && gapStart != nil {
                    let gapEnd = frame
                    let gapSize = gapEnd - gapStart!
                    
                    // Only fill small gaps
                    if gapSize <= maxGapSize {
                        // Find before/after positions
                        let beforeFrame = gapStart! - 1
                        let afterFrame = gapEnd
                        
                        if beforeFrame >= 0,
                           let before = filledPositions[beforeFrame][markerIdx],
                           let after = filledPositions[afterFrame][markerIdx] {
                            // Linear interpolation
                            for i in gapStart!..<gapEnd {
                                let t = Float(i - beforeFrame) / Float(gapEnd - beforeFrame)
                                let interpolated = before + (after - before) * t
                                filledPositions[i][markerIdx] = interpolated
                            }
                        }
                    }
                    gapStart = nil
                }
            }
        }
        
        return MarkerData(
            labels: self.labels,
            frameRate: self.frameRate,
            positions: filledPositions,
            residuals: self.residuals
        )
    }
}

// MARK: - Report Generator

public struct ReportGenerator {
    
    /// Generate HTML report for capture
    public static func generateHTMLReport(capture: MotionCapture) -> String {
        let duration = Double(capture.frameCount) / capture.markers.frameRate
        
        return """
        <!DOCTYPE html>
        <html>
        <head>
            <title>BioMotionPro Report - \(capture.metadata.filename)</title>
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; margin: 40px; background: #1a1a1a; color: #fff; }
                h1 { color: #4fc3f7; }
                h2 { color: #81c784; border-bottom: 1px solid #333; padding-bottom: 8px; }
                table { border-collapse: collapse; width: 100%; margin: 20px 0; }
                th, td { border: 1px solid #333; padding: 12px; text-align: left; }
                th { background: #2d2d2d; color: #4fc3f7; }
                tr:nth-child(even) { background: #252525; }
                .stat { font-size: 24px; font-weight: bold; color: #4fc3f7; }
                .grid { display: grid; grid-template-columns: repeat(4, 1fr); gap: 20px; margin: 20px 0; }
                .card { background: #2d2d2d; padding: 20px; border-radius: 8px; }
                .card-title { color: #888; font-size: 12px; text-transform: uppercase; }
            </style>
        </head>
        <body>
            <h1>📊 Motion Capture Report</h1>
            <p>Generated: \(DateFormatter.localizedString(from: Date(), dateStyle: .full, timeStyle: .medium))</p>
            
            <h2>📁 File Information</h2>
            <div class="grid">
                <div class="card">
                    <div class="card-title">Filename</div>
                    <div class="stat" style="font-size: 16px;">\(capture.metadata.filename)</div>
                </div>
                <div class="card">
                    <div class="card-title">Duration</div>
                    <div class="stat">\(String(format: "%.2f", duration))s</div>
                </div>
                <div class="card">
                    <div class="card-title">Frame Rate</div>
                    <div class="stat">\(Int(capture.markers.frameRate)) Hz</div>
                </div>
                <div class="card">
                    <div class="card-title">Total Frames</div>
                    <div class="stat">\(capture.frameCount)</div>
                </div>
            </div>
            
            <h2>📍 Marker Data</h2>
            <div class="grid">
                <div class="card">
                    <div class="card-title">Marker Count</div>
                    <div class="stat">\(capture.markers.markerCount)</div>
                </div>
            </div>
            
            <table>
                <tr><th>#</th><th>Marker Label</th></tr>
                \(capture.markers.labels.enumerated().map { "<tr><td>\($0.offset + 1)</td><td>\($0.element)</td></tr>" }.joined())
            </table>
            
            \(capture.analogs.channels.isEmpty ? "" : """
            <h2>📈 Analog Channels</h2>
            <div class="grid">
                <div class="card">
                    <div class="card-title">Channel Count</div>
                    <div class="stat">\(capture.analogs.channels.count)</div>
                </div>
                <div class="card">
                    <div class="card-title">Sample Rate</div>
                    <div class="stat">\(Int(capture.analogs.sampleRate)) Hz</div>
                </div>
            </div>
            
            <table>
                <tr><th>#</th><th>Channel</th><th>Unit</th><th>Samples</th></tr>
                \(capture.analogs.channels.enumerated().map { "<tr><td>\($0.offset + 1)</td><td>\($0.element.label)</td><td>\($0.element.unit)</td><td>\($0.element.data.count)</td></tr>" }.joined())
            </table>
            """)
            
            \(generateKinematicsSection(capture))
            
            <footer style="margin-top: 40px; color: #666; font-size: 12px;">
                Generated by BioMotionPro
            </footer>
        </body>
        </html>
        """
    }
    
    private static func generateKinematicsSection(_ capture: MotionCapture) -> String {
        guard let angles = capture.calculatedAngles, !angles.isEmpty else { return "" }
        
        var rows = ""
        for (name, series) in angles.sorted(by: { $0.key < $1.key }) {
            let valid = series.values.compactMap { $0 }
            let min = valid.min() ?? 0
            let max = valid.max() ?? 0
            let mean = valid.isEmpty ? 0 : valid.reduce(0, +) / Float(valid.count)
            
            rows += """
            <tr>
                <td>\(name)</td>
                <td>\(String(format: "%.1f", min))°</td>
                <td>\(String(format: "%.1f", max))°</td>
                <td>\(String(format: "%.1f", mean))°</td>
            </tr>
            """
        }
        
        return """
        <h2>📐 Kinematics Analysis</h2>
        <table>
            <tr><th>Joint Angle</th><th>Min</th><th>Max</th><th>Mean</th></tr>
            \(rows)
        </table>
        """
    }
}
