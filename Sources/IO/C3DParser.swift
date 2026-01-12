import Foundation
import simd

/// C3D file format parser
/// Reference: https://www.c3d.org/HTML/default.htm
public actor C3DParser: DataParser {
    public static let supportedExtensions = ["c3d"]
    
    public init() {}
    
    // MARK: - Parsing
    
    public func parse(from url: URL) async throws -> MotionCapture {
        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ParseError.fileNotFound(url)
        }
        
        let data = try Data(contentsOf: url)
        return try parseC3D(data: data, filename: url.lastPathComponent)
    }
    
    public func write(_ capture: MotionCapture, to url: URL) async throws {
        // TODO: Implement C3D writing
        fatalError("C3D writing not yet implemented")
    }
    
    // MARK: - Internal Parsing
    
    private func parseC3D(data: Data, filename: String) throws -> MotionCapture {
        guard data.count >= 512 else {
            throw ParseError.invalidFormat("File too small to be a valid C3D file")
        }
        
        // Read header (first 512 bytes)
        let header = try parseHeader(data: data)
        
        // Read parameters
        let parameters = try parseParameters(data: data, header: header)
        
        // Read point data
        let markers = try parsePointData(data: data, header: header, parameters: parameters)
        
        // Read analog data
        let analogs = try parseAnalogData(data: data, header: header, parameters: parameters)
        
        // Read events
        let events = parseEvents(parameters: parameters, frameRate: header.frameRate)
        
        // Build metadata
        let metadata = CaptureMetadata(
            filename: filename,
            subject: parameters.subject,
            description: parameters.description,
            captureDate: nil,
            manufacturer: parameters.manufacturer,
            softwareVersion: nil
        )
        
        return MotionCapture(
            metadata: metadata,
            markers: markers,
            analogs: analogs,
            events: events,
            segments: nil
        )
    }
    
    // MARK: - Header Parsing
    
    private struct C3DHeader {
        let parameterBlock: Int
        let pointCount: Int
        let analogChannels: Int
        let firstFrame: Int
        let lastFrame: Int
        let maxInterpolationGap: Int
        let scaleFactor: Float
        let dataStart: Int
        let analogSamplesPerFrame: Int
        let frameRate: Float
        let processorType: ProcessorType
        
        var isFloat: Bool { scaleFactor < 0 }
        var frameCount: Int { lastFrame - firstFrame + 1 }
        
        enum ProcessorType: UInt8 {
            case intel = 1
            case dec = 2
            case sgi = 3
            
            var isLittleEndian: Bool { self == .intel }
        }
    }
    
    private func parseHeader(data: Data) throws -> C3DHeader {
        guard data.count >= 512 else {
            throw ParseError.invalidFormat("File too small")
        }
        
        return try data.withUnsafeBytes { buffer in
            guard let base = buffer.baseAddress else { throw ParseError.corruptedData("Memory access failed") }
            
            // Byte 0: Param block
            let parameterBlock = Int(base.load(fromByteOffset: 0, as: UInt8.self))
            
            // Byte 1: Magic 0x50
            let magic = base.load(fromByteOffset: 1, as: UInt8.self)
            guard magic == 0x50 else {
                throw ParseError.invalidFormat("Invalid C3D magic byte: \(String(format: "%02X", magic))")
            }
            
            // Determine processor type from parameter section
            // Standard C3D: 84=Intel (LE), 85=DEC (LE+), 86=SGI (BE)
            let procOffset = (parameterBlock - 1) * 512 + 3
            var processorType: C3DHeader.ProcessorType = .intel
            
            if procOffset < data.count {
                let procValue = base.load(fromByteOffset: procOffset, as: UInt8.self)
                switch procValue {
                case 84: processorType = .intel
                case 85: processorType = .dec
                case 86: processorType = .sgi
                default: 
                    // Fallback to heuristic or default
                    // Existing logic clamped 1...3, but 84 is standard.
                    // If unknown, assume Intel (safest bet for modern files)
                    processorType = .intel
                    logDebug("⚠️ Unknown processor type: \(procValue). Defaulting to Intel (LE).")
                }
            }
            
            // Helper to read 16-bit
            func readInt16(at offset: Int) -> Int16 {
                let low = Int16(base.load(fromByteOffset: offset, as: UInt8.self))
                let high = Int16(base.load(fromByteOffset: offset + 1, as: UInt8.self))
                return processorType.isLittleEndian ? (high << 8) | low : (low << 8) | high
            }
            
            func readUInt16(at offset: Int) -> UInt16 {
                UInt16(bitPattern: readInt16(at: offset))
            }
            
            func readFloat(at offset: Int) -> Float {
                // Safe unaligned read: Copy bytes to local array then load
                let b0 = base.load(fromByteOffset: offset, as: UInt8.self)
                let b1 = base.load(fromByteOffset: offset + 1, as: UInt8.self)
                let b2 = base.load(fromByteOffset: offset + 2, as: UInt8.self)
                let b3 = base.load(fromByteOffset: offset + 3, as: UInt8.self)
                
                let bytes = processorType.isLittleEndian
                    ? [b0, b1, b2, b3]
                    : [b3, b2, b1, b0]
                
                return bytes.withUnsafeBytes { $0.load(as: Float.self) }
            }
            
            // Correct Header Offsets
            let pointCount = Int(readInt16(at: 2))         // Word 2
            let analogTotal = Int(readInt16(at: 4))        // Word 3
            let firstFrame = Int(readInt16(at: 6))         // Word 4
            let lastFrame = Int(readInt16(at: 8))          // Word 5
            let maxGap = Int(readInt16(at: 10))            // Word 6
            let scaleFactor = readFloat(at: 12)            // Word 7-8 (Bytes 12-15)
            let dataStart = Int(readInt16(at: 16))         // Word 9 (Bytes 16-17)
            let analogSamples = Int(readInt16(at: 18))     // Word 10 (Bytes 18-19)
            let frameRate = readFloat(at: 20)              // Word 11-12 (Bytes 20-23)
            
            logDebug("📋 Parsed Header: Points=\(pointCount), Scale=\(scaleFactor), Rate=\(frameRate), ProcType=\(processorType)")
            // Wait, offset 20 is Word 11? 
            // Word 1: 0,1. Word 2: 2,3. ... Word 10: 18,19. Word 11: 20,21.
            // My previous code read float at 20. But offset 18 is Word 10 (Analog Samples).
            // Header spec:
            // Word 10: Analog samples per frame (Integer).
            // Word 11: Frame Rate (Float). Offset 20.
            
            // Let's check previous code line 136:
            // analogSamplesPerFrame: Int(readUInt16(at: 18))
            // frameRate: readFloat(at: 20)
            
            // My replacement above:
            // let analogSamples = Int(readInt16(at: 16)) -> Offset 16 is Word 9 (Data Start)?
            // Word 1: 0. Word 2: 2. Word 9: 16. Correct.
            // Word 10: 18.
            // Word 11: 20.
            
            // RE-VERIFY OFFSETS:
            // Word 1 (Byte 0,1): Param Block + Magic
            // Word 2 (Byte 2,3): Point Count
            // Word 3 (Byte 4,5): Analog count
            // Word 4 (Byte 6,7): First Frame
            // Word 5 (Byte 8,9): Last Frame
            // Word 6 (Byte 10,11): Max Gap
            // Word 7-8 (Byte 12,13,14,15): Scale
            // Word 9 (Byte 16,17): Data Start
            // Word 10 (Byte 18,19): Analog Samples
            // Word 11-12 (Byte 20,21,22,23): Frame Rate
            
            let frameRateReal = readFloat(at: 20)
            let analogSamplesReal = Int(readInt16(at: 18))
            let dataStartReal = Int(readInt16(at: 16))
            
            logDebug("📋 Parsed Header: Points=\(pointCount), Scale=\(scaleFactor), Rate=\(frameRateReal), ProcType=\(processorType)")
            
            return C3DHeader(
                parameterBlock: parameterBlock,
                pointCount: pointCount,
                analogChannels: analogSamplesReal > 0 ? analogTotal / analogSamplesReal : 0,
                firstFrame: firstFrame,
                lastFrame: lastFrame,
                maxInterpolationGap: maxGap,
                scaleFactor: scaleFactor,
                dataStart: dataStartReal,
                analogSamplesPerFrame: analogSamplesReal,
                frameRate: frameRateReal,
                processorType: processorType
            )
        }
    }
    
    // MARK: - Parameter Parsing
    
    private struct C3DParameters {
        var pointLabels: [String] = []
        var pointDescriptions: [String] = []
        var analogLabels: [String] = []
        var analogUnits: [String] = []
        var analogScale: [Float] = []
        var analogOffset: [Int16] = []
        var subject: String?
        var description: String?
        var manufacturer: String?
        var eventLabels: [String] = []
        var eventTimes: [Float] = []
        var eventContexts: [String] = []
    }
    
    private func parseParameters(data: Data, header: C3DHeader) throws -> C3DParameters {
        var params = C3DParameters()
        
        let startByte = (header.parameterBlock - 1) * 512
        guard data.count > startByte + 4 else {
            throw ParseError.corruptedData("Parameter block start beyond file end")
        }
        
        // --- Pass 1: Build Group Map ---
        var groupMap: [Int: String] = [:]
        var offset = startByte + 4
        
        while offset < data.count - 1 {
            let recordStart = offset
            let nameLength = Int(Int8(bitPattern: data[offset]))
            if nameLength == 0 { break }
            
            let actualLength = abs(nameLength)
            let groupId = Int(Int8(bitPattern: data[offset + 1]))
            
            // Check boundaries
            guard offset + 2 + actualLength <= data.count else { break }
            let nameData = data[(offset + 2)..<(offset + 2 + actualLength)]
            let name = String(data: nameData, encoding: .ascii)?.trimmingCharacters(in: .whitespaces).uppercased() ?? ""
            
            let nextOffsetPtr = offset + 2 + actualLength
            guard nextOffsetPtr + 2 <= data.count else { break }
            let nextOffset = Int(readInt16LE(data, at: nextOffsetPtr))
            
            // If Group Record (ID < 0)
            if groupId < 0 {
                let id = abs(groupId)
                groupMap[id] = name
            }
            
            if nextOffset == 0 { break }
            offset = recordStart + nextOffset
        }
        
        // --- Pass 2: Parse Parameters ---
        offset = startByte + 4 // Reset
        
        while offset < data.count - 1 {
            let recordStart = offset
            let nameLength = Int(Int8(bitPattern: data[offset]))
            if nameLength == 0 { break }
            
            let actualLength = abs(nameLength)
            let groupId = Int(Int8(bitPattern: data[offset + 1]))
            let id = abs(groupId)
            let groupName = groupMap[id] ?? "UNKNOWN"
            
            let nameData = data[(offset + 2)..<(offset + 2 + actualLength)]
            let name = String(data: nameData, encoding: .ascii)?.trimmingCharacters(in: .whitespaces).uppercased() ?? ""
            
            let nextOffsetPtr = offset + 2 + actualLength
            let nextOffset = Int(readInt16LE(data, at: nextOffsetPtr))
            
            // If Parameter Record (ID > 0)
            if groupId > 0 {
                let dataStart = nextOffsetPtr + 2
                let dataEnd = recordStart + nextOffset
                
                if dataStart + 2 <= dataEnd {
                    let dataType = Int8(bitPattern: data[dataStart])
                    let numDimensions = Int(data[dataStart + 1])
                    
                    var dimPtr = dataStart + 2
                    var dimensions: [Int] = []
                    for _ in 0..<numDimensions {
                        if dimPtr + 1 <= dataEnd {
                            dimensions.append(Int(data[dimPtr]))
                            dimPtr += 1
                        }
                    }
                    
                    // --- Value Readers ---
                    func readStrings() -> [String]? {
                        guard dataType == -1 && dimensions.count >= 2 else { return nil }
                        let chars = dimensions[0]
                        let count = dimensions[1]
                        var results: [String] = []
                        for i in 0..<count {
                            let s = dimPtr + i * chars
                            let e = s + chars
                            if e <= dataEnd {
                                if let str = String(data: data[s..<e], encoding: .ascii) {
                                    results.append(str.replacingOccurrences(of: "\0", with: "").trimmingCharacters(in: .whitespacesAndNewlines).trimmingCharacters(in: .controlCharacters))
                                }
                            }
                        }
                        return results
                    }
                    
                    func readFloats() -> [Float]? {
                        guard dataType == 4 || dataType == 2 else { return nil }
                        let total = dimensions.reduce(1, *)
                        var vals: [Float] = []
                        var p = dimPtr
                        for _ in 0..<total {
                             if p + (dataType == 4 ? 4 : 2) <= dataEnd {
                                 if dataType == 4 {
                                     vals.append(readFloatLE(data, at: p))
                                     p += 4
                                 } else {
                                     vals.append(Float(readInt16LE(data, at: p)))
                                     p += 2
                                 }
                             }
                        }
                        return vals
                    }
                    
                    // --- Logic ---
                    if groupName == "POINT" && name == "LABELS" {
                        if let labels = readStrings() {
                            params.pointLabels = labels
                            logDebug("✅ Found Point Labels: \(labels.count)")
                        }
                    } else if groupName == "ANALOG" && name == "LABELS" {
                        if let labels = readStrings() {
                            params.analogLabels = labels
                        }
                    } else if groupName == "ANALOG" && name == "SCALE" {
                        if let vals = readFloats() { params.analogScale = vals }
                    } else if groupName == "EVENT" {
                        if name == "LABELS", let labels = readStrings() {
                            params.eventLabels = labels
                        } else if name == "CONTEXTS", let contexts = readStrings() {
                            params.eventContexts = contexts
                        } else if name == "TIMES", let vals = readFloats() {
                            // TIMES is usually [2, N]
                            if dimensions.count == 2 && dimensions[0] == 2 {
                                // Take 1st of every pair
                                var times: [Float] = []
                                for i in 0..<dimensions[1] {
                                    if i * 2 < vals.count { times.append(vals[i*2]) }
                                }
                                params.eventTimes = times
                            } else {
                                params.eventTimes = vals
                            }
                            logDebug("🚩 Found Event Times: \(params.eventTimes.count)")
                        }
                    } else if name == "SUBJECT" {
                        // Sometimes in SUBJECT group, sometimes global? usually SUBJECT:LABEL or similar?
                        // Just checking param name 'SUBJECT' widely or specific group?
                        // Standard is Group PROCESSING or similar. Let's just catch "SUBJECT" param if possible, or "LABEL" in SUBJECT group.
                    }
                }
            }
            
            if nextOffset == 0 { break }
            offset = recordStart + nextOffset
        }

        // Defaults
        if params.pointLabels.isEmpty {
            params.pointLabels = (0..<header.pointCount).map { "MARKER\($0 + 1)" }
        }
        if params.analogLabels.isEmpty {
            params.analogLabels = (0..<header.analogChannels).map { "ANALOG\($0 + 1)" }
        }
        
        return params
    }
    
    // MARK: - Point Data Parsing
    
    private func parsePointData(data: Data, header: C3DHeader, parameters: C3DParameters) throws -> MarkerData {
        let startByte = (header.dataStart - 1) * 512
        guard startByte < data.count else {
            throw ParseError.corruptedData("Data block start beyond file end")
        }
        
        // C3D spec: Point data is mostly X,Y,Z (4 bytes each) + Residual (4 bytes)
        // If integer, it's 2 bytes each * scaleFactor
        let isFloat = header.isFloat
        let pointSize = isFloat ? 4 : 2
        let bytesPerPoint = pointSize * 4  // X, Y, Z, residual
        let analogSize = isFloat ? 4 : 2
        let analogsPerFrame = header.analogChannels * header.analogSamplesPerFrame
        let bytesPerFrame = header.pointCount * bytesPerPoint + analogsPerFrame * analogSize
        
        let scaleFactor = abs(header.scaleFactor)
        
        logDebug("📂 C3D Parser: Loading \(header.pointCount) markers, \(header.frameCount) frames. Float: \(isFloat), Scale: \(scaleFactor)")
        logDebug("🏷️ Labels: \(parameters.pointLabels)")
        
        // Pre-allocate arrays to avoid reallocation overhead
        // Accessing the raw pointer is 100x faster than data.subdata or data[index] in a loop
        return try data.withUnsafeBytes { buffer -> MarkerData in
            guard let basePtr = buffer.baseAddress else {
                throw ParseError.corruptedData("Unable to access data buffer")
            }
            
            var positions: [[SIMD3<Float>?]] = []
            var residuals: [[Float?]] = []
            positions.reserveCapacity(header.frameCount)
            residuals.reserveCapacity(header.frameCount)
            
            var validPointsFound = 0
            
            for frame in 0..<header.frameCount {
                let frameStart = startByte + frame * bytesPerFrame
                
                var framePositions: [SIMD3<Float>?] = []
                var frameResiduals: [Float?] = []
                framePositions.reserveCapacity(header.pointCount)
                frameResiduals.reserveCapacity(header.pointCount)
                
                for point in 0..<header.pointCount {
                    let pointStart = frameStart + point * bytesPerPoint
                    if pointStart + bytesPerPoint > data.count {
                        framePositions.append(nil)
                        frameResiduals.append(nil)
                        continue
                    }
                    
                    let x: Float
                    let y: Float
                    let z: Float
                    let residual: Float
                    
                    if isFloat {
                        // Assuming Little Endian (Intel) for typical C3D
                        // TODO: Handle big endian specific files if needed
                        x = basePtr.load(fromByteOffset: pointStart, as: Float.self)
                        y = basePtr.load(fromByteOffset: pointStart + 4, as: Float.self)
                        z = basePtr.load(fromByteOffset: pointStart + 8, as: Float.self)
                        let resVal = basePtr.load(fromByteOffset: pointStart + 12, as: Float.self)
                        // In float format, residual/camera info is cast to float
                        // Usually negative means invalid, but sometimes it's encoded differently
                        residual = resVal
                    } else {
                        // Integer format
                        let iX = basePtr.load(fromByteOffset: pointStart, as: Int16.self)
                        let iY = basePtr.load(fromByteOffset: pointStart + 2, as: Int16.self)
                        let iZ = basePtr.load(fromByteOffset: pointStart + 4, as: Int16.self)
                        let iRes = basePtr.load(fromByteOffset: pointStart + 6, as: Int16.self)
                        
                        x = Float(iX) * scaleFactor
                        y = Float(iY) * scaleFactor
                        z = Float(iZ) * scaleFactor
                        residual = Float(iRes) // Integer residual has specific bit flags
                    }
                    
                    // Validation
                    // If residual < 0, point is invalid/occluded
                    // Also filter strict (0,0,0) if suspicious
                    if residual < 0 || (x == 0 && y == 0 && z == 0) {
                        framePositions.append(nil)
                        frameResiduals.append(nil)
                    } else {
                        framePositions.append(SIMD3<Float>(x, y, z))
                        frameResiduals.append(residual)
                        
                        // Debug logging for first few points of first valid frame
                        if validPointsFound < 5 {
                            logDebug("📍 Point[\(point)] Frame[\(frame)]: (\(x), \(y), \(z))")
                            validPointsFound += 1
                        }
                    }
                }
                
                positions.append(framePositions)
                residuals.append(frameResiduals)
            }
            
            if validPointsFound == 0 {
                logDebug("⚠️ WARNING: No valid points found in C3D file!")
            }
            
            return MarkerData(
                labels: parameters.pointLabels,
                frameRate: Double(header.frameRate),
                positions: positions,
                residuals: residuals
            )
        }
    }
    
    // MARK: - Analog Data Parsing
    
    private func parseAnalogData(data: Data, header: C3DHeader, parameters: C3DParameters) throws -> AnalogData {
        guard header.analogChannels > 0 else {
            return AnalogData.empty
        }
        
        let pointSize = header.isFloat ? 4 : 2
        let bytesPerPoint = pointSize * 4
        let pointDataSize = header.pointCount * bytesPerPoint
        let analogSize = header.isFloat ? 4 : 2
        let analogsPerFrame = header.analogChannels * header.analogSamplesPerFrame
        let bytesPerFrame = pointDataSize + analogsPerFrame * analogSize
        let startByte = (header.dataStart - 1) * 512
        
        // Bulk read using unsafe pointers
        return data.withUnsafeBytes { buffer -> AnalogData in
            guard let basePtr = buffer.baseAddress else { return AnalogData.empty }
            
            var channelData: [[Float]] = Array(repeating: [], count: header.analogChannels)
            // Pre-allocate
            let totalUsage = header.frameCount * header.analogSamplesPerFrame
            for i in 0..<header.analogChannels {
                channelData[i].reserveCapacity(totalUsage)
            }
            
            for frame in 0..<header.frameCount {
                let frameStart = startByte + frame * bytesPerFrame + pointDataSize
                
                for sample in 0..<header.analogSamplesPerFrame {
                    for channel in 0..<header.analogChannels {
                        let sampleOffset = frameStart + (sample * header.analogChannels + channel) * analogSize
                        if sampleOffset + analogSize > data.count { continue }
                        
                        let value: Float
                        if header.isFloat {
                            value = basePtr.load(fromByteOffset: sampleOffset, as: Float.self)
                        } else {
                            let iVal = basePtr.load(fromByteOffset: sampleOffset, as: Int16.self)
                            value = Float(iVal)
                        }
                        
                        channelData[channel].append(value)
                    }
                }
            }
            
            // Build channel objects
            var channels: [AnalogChannel] = []
            for (index, samples) in channelData.enumerated() {
                let label = index < parameters.analogLabels.count
                    ? parameters.analogLabels[index]
                    : "ANALOG\(index + 1)"
                
                let scale = index < parameters.analogScale.count
                    ? parameters.analogScale[index]
                    : 1.0
                
                channels.append(AnalogChannel(
                    label: label,
                    unit: "",
                    data: samples,
                    scale: scale,
                    offset: 0
                ))
            }
            
            let sampleRate = Double(header.frameRate) * Double(header.analogSamplesPerFrame)
            return AnalogData(channels: channels, sampleRate: sampleRate)
        }
    }
    
    // MARK: - Event Parsing
    
    private func parseEvents(parameters: C3DParameters, frameRate: Float) -> [MotionEvent] {
        var events: [MotionEvent] = []
        
        for (index, time) in parameters.eventTimes.enumerated() {
            let label = index < parameters.eventLabels.count
                ? parameters.eventLabels[index]
                : "Event \(index + 1)"
            
            let context = index < parameters.eventContexts.count
                ? parameters.eventContexts[index]
                : nil
            
            let frame = Int(time * frameRate)
            
            events.append(MotionEvent(
                label: label,
                time: Double(time),
                frame: frame,
                context: context
            ))
        }
        
        return events.sorted { $0.time < $1.time }
    }
    
    // MARK: - Binary Reading Helpers
    
    private func readInt16LE(_ data: Data, at offset: Int) -> Int16 {
        guard offset + 1 < data.count else { return 0 }
        return Int16(data[offset]) | (Int16(data[offset + 1]) << 8)
    }
    
    private func readFloatLE(_ data: Data, at offset: Int) -> Float {
        guard offset + 3 < data.count else { return 0 }
        let bytes = [data[offset], data[offset+1], data[offset+2], data[offset+3]]
        return bytes.withUnsafeBytes { $0.load(as: Float.self) }
    }
}

// MARK: - Extensions

extension UInt8 {
    func clamped(to range: ClosedRange<UInt8>) -> UInt8 {
        Swift.min(Swift.max(self, range.lowerBound), range.upperBound)
    }
}
