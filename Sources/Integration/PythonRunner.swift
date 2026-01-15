import Foundation

public enum PythonRunnerError: Error, LocalizedError {
    case pythonNotFound
    case scriptExecutionFailed(String)
    case outputFileNotFound
    case parsingFailed(String)
    
    public var errorDescription: String? {
        switch self {
        case .pythonNotFound: return "Python 3 executable not found in standard paths."
        case .scriptExecutionFailed(let msg): return "Script failed: \(msg)"
        case .outputFileNotFound: return "The script did not generate the expected output file."
        case .parsingFailed(let msg): return "Failed to parse script output: \(msg)"
        }
    }
}

public class PythonRunner {
    
    public static func runScript(at scriptURL: URL, with capture: MotionCapture) async throws -> MotionCapture {
        // 1. Setup Temporary Workspace
        let tempDir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true)
        
        defer {
            try? FileManager.default.removeItem(at: tempDir)
        }
        
        let inputFile = tempDir.appendingPathComponent("input_markers.csv")
        let outputFile = tempDir.appendingPathComponent("output_markers.csv")
        
        // 2. Export Data
        logDebug("🐍 PythonRunner: Exporting data to \(inputFile.path)")
        let csvData = DataExporter.exportMarkersToCSV(capture: capture)
        try csvData.write(to: inputFile, atomically: true, encoding: .utf8)
        
        // 3. Find Python
        let pythonPath = findPython()
        guard let python = pythonPath else {
            throw PythonRunnerError.pythonNotFound
        }
        
        // 4. Run Process
        logDebug("🐍 PythonRunner: Executing \(scriptURL.lastPathComponent)")
        let process = Process()
        process.executableURL = URL(fileURLWithPath: python)
        
        // Arguments: SCRIPT_PATH INPUT_CSV OUTPUT_CSV
        process.arguments = [
            scriptURL.path,
            inputFile.path,
            outputFile.path
        ]
        
        let pipe = Pipe()
         process.standardOutput = pipe
         process.standardError = pipe
         
         try process.run()
         process.waitUntilExit()
         
         let data = pipe.fileHandleForReading.readDataToEndOfFile()
         let output = String(data: data, encoding: .utf8) ?? ""
         
         if process.terminationStatus != 0 {
             logDebug("🐍 Script Error: \(output)")
             throw PythonRunnerError.scriptExecutionFailed(output)
         }
        
        logDebug("🐍 Script Output: \(output)")
        
        // 5. Parse Output
        if FileManager.default.fileExists(atPath: outputFile.path) {
            logDebug("🐍 PythonRunner: Parsing output...")
            // Parse CSV back to MarkerData
            let newMarkers = try parseCSVValues(url: outputFile, originalRate: capture.markers.frameRate)
            
            // Create new capture with updated markers
            // Preserve Metadata, Analogs, Events
            let newCapture = MotionCapture(
                metadata: CaptureMetadata(
                    filename: capture.metadata.filename + " (Processed)",
                    subject: capture.metadata.subject,
                    description: "Processed by \(scriptURL.lastPathComponent)",
                    captureDate: Date(),
                    manufacturer: "Python Script",
                    softwareVersion: "1.0"
                ),
                markers: newMarkers,
                analogs: capture.analogs,
                events: capture.events,
                segments: capture.segments,
                calculatedAngles: capture.calculatedAngles
            )
            return newCapture
            
        } else {
            throw PythonRunnerError.outputFileNotFound
        }
    }
    
    private static func findPython() -> String? {
        let paths = [
            "/usr/bin/python3",
            "/usr/local/bin/python3",
            "/opt/homebrew/bin/python3", // Apple Silicon Homebrew
            "/usr/bin/python"
        ]
        
        for path in paths {
            if FileManager.default.fileExists(atPath: path) {
                return path
            }
        }
        
        // Try 'env' lookup as fallback (might not work well in sandbox)
        return nil
    }
    
    /// Basic CSV Parser compatible with DataExporter format
    private static func parseCSVValues(url: URL, originalRate: Double) throws -> MarkerData {
        let content = try String(contentsOf: url)
        var lines = content.components(separatedBy: .newlines).filter { !$0.isEmpty }
        
        guard let headerLine = lines.first else {
            throw PythonRunnerError.parsingFailed("Empty file")
        }
        
        // Parse Header: Frame,Time,Mk1_X,Mk1_Y,Mk1_Z,...
        let headers = headerLine.components(separatedBy: ",")
        guard headers.count > 2 else { throw PythonRunnerError.parsingFailed("Invalid header") }
        
        // Extract Labels
        // Format is Label_X, Label_Y, Label_Z
        var labels: [String] = []
        var i = 2
        while i < headers.count {
            let col = headers[i]
            if col.hasSuffix("_X") {
                let label = String(col.dropLast(2))
                labels.append(label)
                i += 3
            } else {
                i += 1
            }
        }
        
        lines.removeFirst() // Drop header
        
        var positions: [[SIMD3<Float>?]] = []
        
        for line in lines {
            let cols = line.components(separatedBy: ",")
            var frameData: [SIMD3<Float>?] = []
            
            // Skip Frame, Time (indices 0, 1)
            var colIdx = 2
            
            for _ in labels {
                if colIdx + 2 < cols.count {
                    let x = Float(cols[colIdx])
                    let y = Float(cols[colIdx+1])
                    let z = Float(cols[colIdx+2])
                    
                    if let x = x, let y = y, let z = z {
                        frameData.append(SIMD3<Float>(x, y, z))
                    } else {
                        frameData.append(nil)
                    }
                    colIdx += 3
                } else {
                    frameData.append(nil)
                }
            }
            positions.append(frameData)
        }
        
        return MarkerData(labels: labels, frameRate: originalRate, positions: positions)
    }
}
