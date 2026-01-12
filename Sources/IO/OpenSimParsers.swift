import Foundation
import simd

/// Parser for OpenSim TRC (Track Row Column) marker files
public actor TRCParser: DataParser {
    public static let supportedExtensions = ["trc"]
    
    public init() {}
    
    public func parse(from url: URL) async throws -> MotionCapture {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ParseError.fileNotFound(url)
        }
        
        let content = try String(contentsOf: url, encoding: .utf8)
        return try parseTRC(content: content, filename: url.lastPathComponent)
    }
    
    public func write(_ capture: MotionCapture, to url: URL) async throws {
        let content = generateTRC(capture: capture)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    
    // MARK: - Parsing
    
    private func parseTRC(content: String, filename: String) throws -> MotionCapture {
        let lines = content.components(separatedBy: .newlines)
        guard lines.count >= 6 else {
            throw ParseError.invalidFormat("TRC file too short")
        }
        
        // Line 1: PathFileType (ignored)
        // Line 2: DataRate, CameraRate, NumFrames, NumMarkers, Units, OrigDataRate, OrigDataStartFrame, OrigNumFrames
        // Line 3: Empty or header
        // Line 4: Frame#, Time, Marker1(X,Y,Z), Marker2(X,Y,Z), ...
        // Line 5: (blank or more header)
        // Line 6+: Data
        
        // Parse header line (line 2)
        let headerParts = lines[1].components(separatedBy: "\t").map { $0.trimmingCharacters(in: .whitespaces) }
        
        var frameRate: Double = 100.0
        var numMarkers: Int = 0
        var units: String = "mm"
        
        if headerParts.count >= 2 {
            frameRate = Double(headerParts[0]) ?? 100.0
        }
        if headerParts.count >= 4 {
            numMarkers = Int(headerParts[3]) ?? 0
        }
        if headerParts.count >= 5 {
            units = headerParts[4]
        }
        
        // Parse marker labels (line 4)
        let labelLine = lines[3].components(separatedBy: "\t")
        var markerLabels: [String] = []
        
        // Skip Frame#, Time columns
        var i = 2
        while i < labelLine.count {
            let label = labelLine[i].trimmingCharacters(in: .whitespaces)
            if !label.isEmpty {
                markerLabels.append(label)
            }
            i += 3  // Skip X, Y, Z columns for each marker
        }
        
        // If no labels parsed, generate default names
        if markerLabels.isEmpty && numMarkers > 0 {
            markerLabels = (1...numMarkers).map { "Marker\($0)" }
        }
        
        // Parse data (starting from line 6)
        var positions: [[SIMD3<Float>?]] = []
        
        for lineIndex in 5..<lines.count {
            let line = lines[lineIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            if line.isEmpty { continue }
            
            let parts = line.components(separatedBy: "\t")
            guard parts.count >= 2 else { continue }
            
            // Parse marker positions (starting after Frame#, Time)
            var framePositions: [SIMD3<Float>?] = []
            var col = 2
            
            for _ in 0..<markerLabels.count {
                if col + 2 < parts.count {
                    let xStr = parts[col].trimmingCharacters(in: .whitespaces)
                    let yStr = parts[col + 1].trimmingCharacters(in: .whitespaces)
                    let zStr = parts[col + 2].trimmingCharacters(in: .whitespaces)
                    
                    if let x = Float(xStr), let y = Float(yStr), let z = Float(zStr) {
                        // Check for NaN/invalid markers
                        if x.isNaN || y.isNaN || z.isNaN || (x == 0 && y == 0 && z == 0) {
                            framePositions.append(nil)
                        } else {
                            // Convert to mm if necessary
                            let scale: Float = units.lowercased() == "m" ? 1000.0 : 1.0
                            framePositions.append(SIMD3(x, y, z) * scale)
                        }
                    } else {
                        framePositions.append(nil)
                    }
                } else {
                    framePositions.append(nil)
                }
                col += 3
            }
            
            if !framePositions.isEmpty {
                positions.append(framePositions)
            }
        }
        
        let markers = MarkerData(
            labels: markerLabels,
            frameRate: frameRate,
            positions: positions
        )
        
        let metadata = CaptureMetadata(
            filename: filename,
            description: "Imported from TRC"
        )
        
        return MotionCapture(
            metadata: metadata,
            markers: markers,
            analogs: AnalogData.empty,
            events: [],
            segments: nil
        )
    }
    
    // MARK: - Writing
    
    private func generateTRC(capture: MotionCapture) -> String {
        var lines: [String] = []
        
        let numMarkers = capture.markers.markerCount
        let numFrames = capture.markers.frameCount
        let frameRate = capture.markers.frameRate
        
        // Header lines
        lines.append("PathFileType\t4\t(X/Y/Z)\t\(capture.metadata.filename)")
        lines.append("\(frameRate)\t\(frameRate)\t\(numFrames)\t\(numMarkers)\tmm\t\(frameRate)\t1\t\(numFrames)")
        lines.append("")
        
        // Marker labels
        var labelLine = ["Frame#", "Time"]
        for label in capture.markers.labels {
            labelLine.append(label)
            labelLine.append("")
            labelLine.append("")
        }
        lines.append(labelLine.joined(separator: "\t"))
        
        // Coordinate labels
        var coordLine = ["", ""]
        for i in 1...numMarkers {
            coordLine.append("X\(i)")
            coordLine.append("Y\(i)")
            coordLine.append("Z\(i)")
        }
        lines.append(coordLine.joined(separator: "\t"))
        lines.append("")
        
        // Data lines
        for frame in 0..<numFrames {
            let time = Double(frame) / frameRate
            var dataLine = ["\(frame + 1)", String(format: "%.6f", time)]
            
            for marker in 0..<numMarkers {
                if let pos = capture.markers.position(marker: marker, frame: frame) {
                    dataLine.append(String(format: "%.4f", pos.x))
                    dataLine.append(String(format: "%.4f", pos.y))
                    dataLine.append(String(format: "%.4f", pos.z))
                } else {
                    dataLine.append("")
                    dataLine.append("")
                    dataLine.append("")
                }
            }
            
            lines.append(dataLine.joined(separator: "\t"))
        }
        
        return lines.joined(separator: "\n")
    }
}

/// Parser for OpenSim MOT (Motion) files (forces/moments/positions)
public actor MOTParser: DataParser {
    public static let supportedExtensions = ["mot", "sto"]
    
    public init() {}
    
    public func parse(from url: URL) async throws -> MotionCapture {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ParseError.fileNotFound(url)
        }
        
        let content = try String(contentsOf: url, encoding: .utf8)
        return try parseMOT(content: content, filename: url.lastPathComponent)
    }
    
    public func write(_ capture: MotionCapture, to url: URL) async throws {
        let content = generateMOT(capture: capture)
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    
    // MARK: - Parsing
    
    private func parseMOT(content: String, filename: String) throws -> MotionCapture {
        let lines = content.components(separatedBy: .newlines)
        
        var inData = false
        var columnLabels: [String] = []
        var dataRows: [[Float]] = []
        var nRows = 0
        var nColumns = 0
        
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            
            if trimmed.isEmpty { continue }
            
            // Parse header key-value pairs
            if trimmed.hasPrefix("nRows=") {
                nRows = Int(trimmed.replacingOccurrences(of: "nRows=", with: "")) ?? 0
            } else if trimmed.hasPrefix("nColumns=") {
                nColumns = Int(trimmed.replacingOccurrences(of: "nColumns=", with: "")) ?? 0
            } else if trimmed == "endheader" {
                inData = true
                continue
            }
            
            if inData {
                // First data line after header = column labels
                if columnLabels.isEmpty {
                    columnLabels = trimmed.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                    continue
                }
                
                // Data rows
                let values = trimmed.components(separatedBy: .whitespaces)
                    .filter { !$0.isEmpty }
                    .compactMap { Float($0) }
                
                if values.count > 0 {
                    dataRows.append(values)
                }
            }
        }
        
        guard !columnLabels.isEmpty, !dataRows.isEmpty else {
            throw ParseError.invalidFormat("No data found in MOT file")
        }
        
        // First column is typically "time"
        // Other columns are analog channels
        var sampleRate: Double = 1000.0
        if dataRows.count >= 2 {
            let dt = Double(dataRows[1][0] - dataRows[0][0])
            if dt > 0 {
                sampleRate = 1.0 / dt
            }
        }
        
        // Build analog channels (skip time column)
        var channels: [AnalogChannel] = []
        for (idx, label) in columnLabels.enumerated() {
            if idx == 0 { continue }  // Skip time
            
            var channelData: [Float] = []
            for row in dataRows {
                if idx < row.count {
                    channelData.append(row[idx])
                }
            }
            
            channels.append(AnalogChannel(
                label: label,
                unit: inferUnit(from: label),
                data: channelData
            ))
        }
        
        let metadata = CaptureMetadata(
            filename: filename,
            description: "Imported from MOT/STO"
        )
        
        // Create a minimal marker data structure (1 frame) since MOT doesn't have markers
        let markers = MarkerData(
            labels: [],
            frameRate: sampleRate,
            positions: []
        )
        
        return MotionCapture(
            metadata: metadata,
            markers: markers,
            analogs: AnalogData(channels: channels, sampleRate: sampleRate),
            events: [],
            segments: nil
        )
    }
    
    private func inferUnit(from label: String) -> String {
        let lower = label.lowercased()
        if lower.contains("force") || lower.contains("_f") {
            return "N"
        } else if lower.contains("moment") || lower.contains("_m") {
            return "Nm"
        } else if lower.contains("angle") {
            return "deg"
        } else if lower.contains("velocity") {
            return "deg/s"
        }
        return ""
    }
    
    // MARK: - Writing
    
    private func generateMOT(capture: MotionCapture) -> String {
        var lines: [String] = []
        
        let nRows = capture.analogs.sampleCount
        let nColumns = capture.analogs.channelCount + 1  // +1 for time
        
        // Header
        lines.append(capture.metadata.filename)
        lines.append("version=1")
        lines.append("nRows=\(nRows)")
        lines.append("nColumns=\(nColumns)")
        lines.append("inDegrees=yes")
        lines.append("endheader")
        
        // Column labels
        var labels = ["time"]
        labels.append(contentsOf: capture.analogs.channels.map { $0.label })
        lines.append(labels.joined(separator: "\t"))
        
        // Data
        for sample in 0..<nRows {
            let time = Double(sample) / capture.analogs.sampleRate
            var row = [String(format: "%.6f", time)]
            
            for channel in capture.analogs.channels {
                if sample < channel.data.count {
                    row.append(String(format: "%.6f", channel.scaledData[sample]))
                } else {
                    row.append("0")
                }
            }
            
            lines.append(row.joined(separator: "\t"))
        }
        
        return lines.joined(separator: "\n")
    }
}
