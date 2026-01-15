import Foundation
import simd

/// Predefined skeleton models for common marker sets
public struct SkeletonModel: Sendable {
    public let name: String
    public let bones: [BoneConnection]
    public let markerLabels: Set<String>
    
    public init(name: String, bones: [BoneConnection]) {
        self.name = name
        self.bones = bones
        self.markerLabels = Set(bones.flatMap { [$0.startMarker, $0.endMarker] })
    }
    
    /// Check if the model is compatible with the given marker labels
    public func isCompatible(with labels: [String]) -> Bool {
        let labelSet = Set(labels)
        // Require at least 80% of skeleton markers to be present
        let matchCount = markerLabels.intersection(labelSet).count
        let percentage = Double(matchCount) / Double(markerLabels.count)
        print("🔍 isCompatible(\(name)): \(matchCount)/\(markerLabels.count) = \(String(format: "%.0f", percentage * 100))% (need 80%)")
        print("   Model markers: \(markerLabels.sorted())")
        print("   File markers: \(labelSet.sorted())")
        return percentage >= 0.8
    }
    
    /// Build a skeleton dynamically based on marker distances
    /// Connects all markers that are close enough to form bones
    public static func buildFromDistances(
        positions: [SIMD3<Float>?],
        labels: [String],
        maxBoneLength: Float = 500.0  // Max distance between connected markers (mm)
    ) -> SkeletonModel {
        var validMarkers: [(index: Int, pos: SIMD3<Float>, label: String)] = []
        
        for (i, pos) in positions.enumerated() {
            if let p = pos, p.x.isFinite && p.y.isFinite && p.z.isFinite {
                let label = (i < labels.count ? labels[i] : nil) ?? "M\(i)"
                validMarkers.append((i, p, label))
            }
        }
        
        guard validMarkers.count >= 2 else {
            return SkeletonModel(name: "Empty", bones: [])
        }
        
        // Calculate height range for body part coloring
        let maxY = validMarkers.map { $0.pos.y }.max() ?? 0
        let minY = validMarkers.map { $0.pos.y }.min() ?? 0
        let range = maxY - minY
        
        var bones: [BoneConnection] = []
        var addedPairs = Set<String>()
        
        // Add connections for each marker to its nearest neighbors
        for i in 0..<validMarkers.count {
            // Find distances to all other markers
            var distances: [(j: Int, dist: Float)] = []
            for j in 0..<validMarkers.count {
                if j != i {
                    let dist = simd_length(validMarkers[i].pos - validMarkers[j].pos)
                    if dist <= maxBoneLength {
                        distances.append((j, dist))
                    }
                }
            }
            
            // Sort by distance and take nearest 3 neighbors
            distances.sort { $0.dist < $1.dist }
            
            for (j, _) in distances.prefix(3) {
                let pairKey = i < j ? "\(i)-\(j)" : "\(j)-\(i)"
                if !addedPairs.contains(pairKey) {
                    addedPairs.insert(pairKey)
                    
                    // Determine body part by Y position
                    let avgY = (validMarkers[i].pos.y + validMarkers[j].pos.y) / 2
                    
                    let part: BodyPart
                    if avgY > minY + range * 0.75 {
                        part = .head
                    } else if avgY > minY + range * 0.5 {
                        part = .spine
                    } else if avgY > minY + range * 0.25 {
                        part = .pelvis
                    } else {
                        part = .other
                    }
                    
                    bones.append(BoneConnection(validMarkers[i].label, validMarkers[j].label, part: part))
                }
            }
        }
        
        print("🔗 Distance-based skeleton: \(bones.count) bones from \(validMarkers.count) markers")
        return SkeletonModel(name: "Auto-Distance", bones: bones)
    }
    
    /// Create a simple skeleton that connects all markers sequentially (0→1→2→...→N)
    public static func connectAllSequentially(labels: [String]) -> SkeletonModel {
        var bones: [BoneConnection] = []
        
        for i in 0..<(labels.count - 1) {
            bones.append(BoneConnection(labels[i], labels[i + 1], part: .other))
        }
        
        return SkeletonModel(name: "Simple Lines", bones: bones)
    }
    
    /// Create a skeleton from a configuration object
    public static func createFromConfiguration(_ config: SkeletonConfiguration) -> SkeletonModel {
        let bones = config.bones.map { boneConfig -> BoneConnection in
            let part = BodyPart(rawValue: boneConfig.bodyPart ?? "other") ?? .other
            return BoneConnection(boneConfig.from, boneConfig.to, part: part)
        }
        return SkeletonModel(name: config.name, bones: bones)
    }
}

/// JSON-serializable skeleton configuration for import/export
public struct SkeletonConfiguration: Codable {
    public let name: String
    public let coordinateSystem: String  // "Y-up" or "Z-up"
    public let bones: [BoneConfig]
    
    public struct BoneConfig: Codable {
        public let from: String
        public let to: String
        public let bodyPart: String?
        
        public init(from: String, to: String, bodyPart: String? = nil) {
            self.from = from
            self.to = to
            self.bodyPart = bodyPart
        }
    }
    
    public init(name: String, coordinateSystem: String, bones: [BoneConfig]) {
        self.name = name
        self.coordinateSystem = coordinateSystem
        self.bones = bones
    }
    
    /// Parse skeleton configuration from XML data
    /// Expected format:
    /// <skeleton name="My Skeleton" coordinateSystem="Z-up">
    ///   <bone from="MARKER1" to="MARKER2" bodyPart="spine"/>
    /// </skeleton>
    public static func parseFromXML(_ data: Data) throws -> SkeletonConfiguration {
        let parser = SkeletonXMLParser()
        let xmlParser = XMLParser(data: data)
        xmlParser.delegate = parser
        
        if xmlParser.parse() {
            return SkeletonConfiguration(
                name: parser.skeletonName ?? "Custom Skeleton",
                coordinateSystem: parser.coordinateSystem ?? "Y-up",
                bones: parser.bones
            )
        } else {
            throw NSError(domain: "SkeletonConfiguration", code: 1, 
                          userInfo: [NSLocalizedDescriptionKey: "Failed to parse XML file"])
        }
    }
}

// XML Parser delegate for skeleton configuration
private class SkeletonXMLParser: NSObject, XMLParserDelegate {
    var skeletonName: String?
    var coordinateSystem: String?
    var bones: [SkeletonConfiguration.BoneConfig] = []
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, 
                namespaceURI: String?, qualifiedName qName: String?, 
                attributes attributeDict: [String : String] = [:]) {
        
        if elementName.lowercased() == "skeleton" {
            skeletonName = attributeDict["name"]
            coordinateSystem = attributeDict["coordinateSystem"] ?? attributeDict["coordinatesystem"]
        } else if elementName.lowercased() == "bone" {
            if let from = attributeDict["from"], let to = attributeDict["to"] {
                let bodyPart = attributeDict["bodyPart"] ?? attributeDict["bodypart"]
                bones.append(SkeletonConfiguration.BoneConfig(from: from, to: to, bodyPart: bodyPart))
            }
        }
    }
}

/// Connection between two markers forming a bone
public struct BoneConnection: Sendable {
    public let startMarker: String
    public let endMarker: String
    public let bodyPart: BodyPart
    
    public init(_ start: String, _ end: String, part: BodyPart = .other) {
        self.startMarker = start
        self.endMarker = end
        self.bodyPart = part
    }
}

/// Body parts for color coding
public enum BodyPart: String, Sendable {
    case head
    case spine
    case leftArm
    case rightArm
    case leftLeg
    case rightLeg
    case pelvis
    case other
    
    public var color: SIMD4<Float> {
        switch self {
        case .head: return SIMD4(1.0, 0.9, 0.6, 1.0)       // Yellow
        case .spine: return SIMD4(0.4, 0.8, 0.4, 1.0)     // Green
        case .leftArm: return SIMD4(1.0, 0.4, 0.4, 1.0)   // Red
        case .rightArm: return SIMD4(0.4, 0.4, 1.0, 1.0)  // Blue
        case .leftLeg: return SIMD4(1.0, 0.5, 0.3, 1.0)   // Orange
        case .rightLeg: return SIMD4(0.3, 0.7, 1.0, 1.0)  // Light blue
        case .pelvis: return SIMD4(0.7, 0.5, 0.8, 1.0)    // Purple
        case .other: return SIMD4(0.6, 0.6, 0.6, 1.0)     // Gray
        }
    }
}

// MARK: - Predefined Models

extension SkeletonModel {
    
    /// Plug-in Gait marker set (Vicon)
    public static let plugInGait = SkeletonModel(
        name: "Plug-in Gait",
        bones: [
            // Head
            BoneConnection("LFHD", "RFHD", part: .head),
            BoneConnection("LFHD", "LBHD", part: .head),
            BoneConnection("RFHD", "RBHD", part: .head),
            BoneConnection("LBHD", "RBHD", part: .head),
            
            // Spine
            BoneConnection("C7", "T10", part: .spine),
            BoneConnection("T10", "CLAV", part: .spine),
            BoneConnection("CLAV", "STRN", part: .spine),
            
            // Left arm
            BoneConnection("LSHO", "LELB", part: .leftArm),
            BoneConnection("LELB", "LWRA", part: .leftArm),
            BoneConnection("LELB", "LWRB", part: .leftArm),
            BoneConnection("LWRA", "LWRB", part: .leftArm),
            BoneConnection("LWRA", "LFIN", part: .leftArm),
            
            // Right arm
            BoneConnection("RSHO", "RELB", part: .rightArm),
            BoneConnection("RELB", "RWRA", part: .rightArm),
            BoneConnection("RELB", "RWRB", part: .rightArm),
            BoneConnection("RWRA", "RWRB", part: .rightArm),
            BoneConnection("RWRA", "RFIN", part: .rightArm),
            
            // Torso
            BoneConnection("LSHO", "CLAV", part: .spine),
            BoneConnection("RSHO", "CLAV", part: .spine),
            BoneConnection("LSHO", "RSHO", part: .spine),
            
            // Pelvis
            BoneConnection("LASI", "RASI", part: .pelvis),
            BoneConnection("LPSI", "RPSI", part: .pelvis),
            BoneConnection("LASI", "LPSI", part: .pelvis),
            BoneConnection("RASI", "RPSI", part: .pelvis),
            
            // Left leg
            BoneConnection("LASI", "LTHI", part: .leftLeg),
            BoneConnection("LTHI", "LKNE", part: .leftLeg),
            BoneConnection("LKNE", "LTIB", part: .leftLeg),
            BoneConnection("LTIB", "LANK", part: .leftLeg),
            BoneConnection("LANK", "LHEE", part: .leftLeg),
            BoneConnection("LANK", "LTOE", part: .leftLeg),
            BoneConnection("LHEE", "LTOE", part: .leftLeg),
            
            // Right leg
            BoneConnection("RASI", "RTHI", part: .rightLeg),
            BoneConnection("RTHI", "RKNE", part: .rightLeg),
            BoneConnection("RKNE", "RTIB", part: .rightLeg),
            BoneConnection("RTIB", "RANK", part: .rightLeg),
            BoneConnection("RANK", "RHEE", part: .rightLeg),
            BoneConnection("RANK", "RTOE", part: .rightLeg),
            BoneConnection("RHEE", "RTOE", part: .rightLeg),
            BoneConnection("RHEE", "RTOE", part: .rightLeg),
        ]
    )
    
    /// Standard ordered labels for Plug-in Gait (39 Markers)
    /// Used for recovering labels when C3D has generic names
    public static let plugInGaitOrderedLabels = [
        "LFHD", "RFHD", "LBHD", "RBHD",
        "C7", "T10", "CLAV", "STRN",
        "RBUN", // Right Back Upper (Scapula?) - often skipped or different
        "RSHO", "RELB", "RWRA", "RWRB", "RFIN",
        "LSHO", "LELB", "LWRA", "LWRB", "LFIN",
        "RASI", "LASI", "RPSI", "LPSI",
        "RTHI", "RKNE", "RTIB", "RANK", "RHEE", "RTOE",
        "LTHI", "LKNE", "LTIB", "LANK", "LHEE", "LTOE"
        // Note: exact order varies by lab (e.g. Vicon vs Qualisys vs Custom)
        // This is a "Best Guess" for Vicon default
    ]
    
    /// Helen Hayes marker set (simplified)
    public static let helenHayes = SkeletonModel(
        name: "Helen Hayes",
        bones: [
            // Pelvis
            BoneConnection("SACR", "LASI", part: .pelvis),
            BoneConnection("SACR", "RASI", part: .pelvis),
            BoneConnection("LASI", "RASI", part: .pelvis),
            
            // Left leg
            BoneConnection("LASI", "LKNE", part: .leftLeg),
            BoneConnection("LKNE", "LANK", part: .leftLeg),
            BoneConnection("LANK", "LHEE", part: .leftLeg),
            BoneConnection("LANK", "LTOE", part: .leftLeg),
            
            // Right leg
            BoneConnection("RASI", "RKNE", part: .rightLeg),
            BoneConnection("RKNE", "RANK", part: .rightLeg),
            BoneConnection("RANK", "RHEE", part: .rightLeg),
            BoneConnection("RANK", "RTOE", part: .rightLeg),
        ]
    )
    
    /// Generic lower body skeleton (works with various marker sets)
    public static let lowerBody = SkeletonModel(
        name: "Lower Body",
        bones: [
            BoneConnection("LPSI", "RPSI", part: .pelvis),
            BoneConnection("LASI", "RASI", part: .pelvis),
            BoneConnection("LASI", "LPSI", part: .pelvis),
            BoneConnection("RASI", "RPSI", part: .pelvis),
            
            BoneConnection("LASI", "LKNE", part: .leftLeg),
            BoneConnection("LKNE", "LANK", part: .leftLeg),
            BoneConnection("LANK", "LTOE", part: .leftLeg),
            
            BoneConnection("RASI", "RKNE", part: .rightLeg),
            BoneConnection("RKNE", "RANK", part: .rightLeg),
            BoneConnection("RANK", "RTOE", part: .rightLeg),
        ]
    )
    
    /// Full Body Minimal (16 markers) - for sample/test data
    /// Markers: LASI, RASI, LPSI, RPSI, LKNE, RKNE, LANK, RANK, LTOE, RTOE, LHEE, RHEE, LSHO, RSHO, LELB, RELB
    public static let fullBodyMinimal = SkeletonModel(
        name: "Full Body Minimal",
        bones: [
            // Pelvis (box)
            BoneConnection("LASI", "RASI", part: .pelvis),
            BoneConnection("LPSI", "RPSI", part: .pelvis),
            BoneConnection("LASI", "LPSI", part: .pelvis),
            BoneConnection("RASI", "RPSI", part: .pelvis),
            
            // Shoulders
            BoneConnection("LSHO", "RSHO", part: .spine),
            
            // Left Arm
            BoneConnection("LSHO", "LELB", part: .leftArm),
            
            // Right Arm
            BoneConnection("RSHO", "RELB", part: .rightArm),
            
            // Connect shoulders to pelvis (spine approximation)
            BoneConnection("LSHO", "LASI", part: .spine),
            BoneConnection("RSHO", "RASI", part: .spine),
            
            // Left Leg
            BoneConnection("LASI", "LKNE", part: .leftLeg),
            BoneConnection("LKNE", "LANK", part: .leftLeg),
            BoneConnection("LANK", "LTOE", part: .leftLeg),
            BoneConnection("LANK", "LHEE", part: .leftLeg),
            BoneConnection("LHEE", "LTOE", part: .leftLeg),
            
            // Right Leg
            BoneConnection("RASI", "RKNE", part: .rightLeg),
            BoneConnection("RKNE", "RANK", part: .rightLeg),
            BoneConnection("RANK", "RTOE", part: .rightLeg),
            BoneConnection("RANK", "RHEE", part: .rightLeg),
            BoneConnection("RHEE", "RTOE", part: .rightLeg),
        ]
    )
    
    /// Pitching 29-Marker Set (Vicon/ASMI style)
    public static let pitching29 = SkeletonModel(
        name: "Pitching (29 Markers)",
        bones: [
            // Head
            BoneConnection("Nose", "REye", part: .head),
            BoneConnection("Nose", "LEye", part: .head),
            BoneConnection("REye", "REar", part: .head),
            BoneConnection("LEye", "LEar", part: .head),
            BoneConnection("Nose", "Neck", part: .head),
            
            // Torso
            BoneConnection("Neck", "MidHip", part: .spine),
            BoneConnection("Neck", "RShoulder", part: .spine),
            BoneConnection("Neck", "LShoulder", part: .spine),
            BoneConnection("RShoulder", "LShoulder", part: .spine),
            
            // Pelvis
            BoneConnection("MidHip", "RHip", part: .pelvis),
            BoneConnection("MidHip", "LHip", part: .pelvis),
            BoneConnection("RHip", "LHip", part: .pelvis),
            
            // Right Arm
            BoneConnection("RShoulder", "RElbow", part: .rightArm),
            BoneConnection("RElbow", "RWrist", part: .rightArm),
            BoneConnection("RWrist", "RThumb", part: .rightArm),
            BoneConnection("RWrist", "RPinky", part: .rightArm),
            
            // Left Arm
            BoneConnection("LShoulder", "LElbow", part: .leftArm),
            BoneConnection("LElbow", "LWrist", part: .leftArm),
            BoneConnection("LWrist", "LThumb", part: .leftArm),
            BoneConnection("LWrist", "LPinky", part: .leftArm),
            
            // Right Leg
            BoneConnection("RHip", "RKnee", part: .rightLeg),
            BoneConnection("RKnee", "RAnkle", part: .rightLeg),
            BoneConnection("RAnkle", "RHeel", part: .rightLeg),
            BoneConnection("RAnkle", "RBigToe", part: .rightLeg),
            BoneConnection("RBigToe", "RSmallToe", part: .rightLeg),
            
            // Left Leg
            BoneConnection("LHip", "LKnee", part: .leftLeg),
            BoneConnection("LKnee", "LAnkle", part: .leftLeg),
            BoneConnection("LAnkle", "LHeel", part: .leftLeg),
            BoneConnection("LAnkle", "LBigToe", part: .leftLeg),
            BoneConnection("LBigToe", "LSmallToe", part: .leftLeg),
            BoneConnection("LBigToe", "LSmallToe", part: .leftLeg),
        ]
    )
    
    /// Standard ordered labels for Pitching (29 Markers)
    public static let pitching29OrderedLabels = [
        "Nose", "REye", "LEye", "REar", "LEar",
        "Neck", "MidHip",
        "RShoulder", "LShoulder",
        "RElbow", "LElbow",
        "RWrist", "LWrist",
        "RThumb", "LThumb", "RPinky", "LPinky",
        "RHip", "LHip",
        "RKnee", "LKnee",
        "RAnkle", "LAnkle",
        "RHeel", "LHeel",
        "RBigToe", "LBigToe", "RSmallToe", "LSmallToe"
    ]
    
    /// Alternative: COCO/BlazePose ordering (MediaPipe style) - 29 markers
    /// Order: Nose, Eyes (L/R), Ears (L/R), Shoulders (L/R), Elbows (L/R), Wrists (L/R), 
    ///        Hips (L/R), Knees (L/R), Ankles (L/R), then extras
    public static let pitching29CocoLabels = [
        "Nose",                           // 0
        "LEye", "REye",                   // 1, 2
        "LEar", "REar",                   // 3, 4
        "LShoulder", "RShoulder",         // 5, 6
        "LElbow", "RElbow",               // 7, 8
        "LWrist", "RWrist",               // 9, 10
        "LHip", "RHip",                   // 11, 12
        "LKnee", "RKnee",                 // 13, 14
        "LAnkle", "RAnkle",               // 15, 16
        "LBigToe", "RBigToe",             // 17, 18 (or LHeel/RHeel in some)
        "LSmallToe", "RSmallToe",         // 19, 20
        "LHeel", "RHeel",                 // 21, 22
        "Neck",                           // 23
        "LThumb", "RThumb",               // 24, 25
        "LPinky", "RPinky",               // 26, 27
        "MidHip"                          // 28
    ]
    
    /// Try to auto-detect the best skeleton model for given markers
    public static func autoDetect(from labels: [String]) -> SkeletonModel? {
        // Updated search order to prioritize specific sports models
        let models: [SkeletonModel] = [.plugInGait, .helenHayes, .pitching29, .fullBodyMinimal, .lowerBody]
        
        // Return the first compatible model (ordered by completeness)
        for model in models {
            if model.isCompatible(with: labels) {
                return model
            }
        }
        
        // Fallback: If we have exactly 29 markers (Vicon Pitching) but parsing failed (labels are MARKER1...), force it.
        // This handles cases where C3D parameter parsing issues prevent label extraction.
        if labels.count == 29 && labels.first?.hasPrefix("MARKER") == true {
             return .pitching29
        }
        
        return nil
    }
    
    /// Automatically identify markers based on their spatial positions
    /// Returns an array of new labels in the same order as the input positions
    public static func identifyMarkersBySpatialPosition(
        positions: [SIMD3<Float>?],
        targetLabels: [String] = pitching29OrderedLabels
    ) -> [String] {
        guard positions.count == targetLabels.count else {
            print("⚠️ Marker count mismatch: \(positions.count) vs \(targetLabels.count)")
            return targetLabels
        }
        
        // Create indexed markers with valid positions
        var indexedMarkers: [(index: Int, pos: SIMD3<Float>)] = []
        for (i, pos) in positions.enumerated() {
            if let p = pos, p.x.isFinite && p.y.isFinite && p.z.isFinite {
                indexedMarkers.append((i, p))
            }
        }
        
        guard indexedMarkers.count >= 20 else {
            print("⚠️ Not enough valid markers for spatial identification")
            return targetLabels
        }
        
        // Sort by Y (height) - highest first
        let byHeight = indexedMarkers.sorted { $0.pos.y > $1.pos.y }
        
        // Calculate body center (X midpoint)
        let avgX = indexedMarkers.map { $0.pos.x }.reduce(0, +) / Float(indexedMarkers.count)
        
        var result = Array(repeating: "Unknown", count: positions.count)
        var assigned = Set<Int>()
        
        // Helper to find nearest unassigned marker to a position
        func findNearest(to target: SIMD3<Float>, from candidates: [(index: Int, pos: SIMD3<Float>)]) -> Int? {
            var best: (index: Int, dist: Float)? = nil
            for m in candidates {
                guard !assigned.contains(m.index) else { continue }
                let dist = simd_length(m.pos - target)
                if best == nil || dist < best!.dist {
                    best = (m.index, dist)
                }
            }
            return best?.index
        }
        
        // Identify head region (top 5 markers by height)
        let headRegion = Array(byHeight.prefix(5))
        
        // Nose: highest and most centered
        if let nose = headRegion.min(by: { abs($0.pos.x - avgX) < abs($1.pos.x - avgX) }) {
            result[nose.index] = "Nose"
            assigned.insert(nose.index)
        }
        
        // Eyes & Ears: near nose level, left/right
        let eyeEarCandidates = headRegion.filter { !assigned.contains($0.index) }
        let leftHead = eyeEarCandidates.filter { $0.pos.x < avgX }.sorted { $0.pos.y > $1.pos.y }
        let rightHead = eyeEarCandidates.filter { $0.pos.x >= avgX }.sorted { $0.pos.y > $1.pos.y }
        
        if let le = leftHead.first { result[le.index] = "LEye"; assigned.insert(le.index) }
        if let re = rightHead.first { result[re.index] = "REye"; assigned.insert(re.index) }
        if leftHead.count > 1 { result[leftHead[1].index] = "LEar"; assigned.insert(leftHead[1].index) }
        if rightHead.count > 1 { result[rightHead[1].index] = "REar"; assigned.insert(rightHead[1].index) }
        
        // Neck: just below head, centered
        let neckCandidates = byHeight.dropFirst(5).prefix(5).filter { !assigned.contains($0.index) }
        if let neck = neckCandidates.min(by: { abs($0.pos.x - avgX) < abs($1.pos.x - avgX) }) {
            result[neck.index] = "Neck"
            assigned.insert(neck.index)
        }
        
        // Shoulders: near neck level, left/right
        let shoulderCandidates = byHeight.dropFirst(5).prefix(8).filter { !assigned.contains($0.index) }
        let leftShoulder = shoulderCandidates.filter { $0.pos.x < avgX }.max { $0.pos.y < $1.pos.y }
        let rightShoulder = shoulderCandidates.filter { $0.pos.x >= avgX }.max { $0.pos.y < $1.pos.y }
        
        if let ls = leftShoulder { result[ls.index] = "LShoulder"; assigned.insert(ls.index) }
        if let rs = rightShoulder { result[rs.index] = "RShoulder"; assigned.insert(rs.index) }
        
        // MidHip: lower body, centered
        let hipRegion = byHeight.dropFirst(15).prefix(10).filter { !assigned.contains($0.index) }
        if let midHip = hipRegion.min(by: { abs($0.pos.x - avgX) < abs($1.pos.x - avgX) }) {
            result[midHip.index] = "MidHip"
            assigned.insert(midHip.index)
        }
        
        // Hips: near MidHip, left/right
        let leftHip = hipRegion.filter { $0.pos.x < avgX && !assigned.contains($0.index) }.first
        let rightHip = hipRegion.filter { $0.pos.x >= avgX && !assigned.contains($0.index) }.first
        
        if let lh = leftHip { result[lh.index] = "LHip"; assigned.insert(lh.index) }
        if let rh = rightHip { result[rh.index] = "RHip"; assigned.insert(rh.index) }
        
        // Arms: between shoulders and hips
        let armRegion = byHeight.dropFirst(8).prefix(12).filter { !assigned.contains($0.index) }
        let leftArm = armRegion.filter { $0.pos.x < avgX }.sorted { $0.pos.y > $1.pos.y }
        let rightArm = armRegion.filter { $0.pos.x >= avgX }.sorted { $0.pos.y > $1.pos.y }
        
        if leftArm.count >= 1 { result[leftArm[0].index] = "LElbow"; assigned.insert(leftArm[0].index) }
        if rightArm.count >= 1 { result[rightArm[0].index] = "RElbow"; assigned.insert(rightArm[0].index) }
        if leftArm.count >= 2 { result[leftArm[1].index] = "LWrist"; assigned.insert(leftArm[1].index) }
        if rightArm.count >= 2 { result[rightArm[1].index] = "RWrist"; assigned.insert(rightArm[1].index) }
        
        // Hands (remaining arm markers)
        if leftArm.count >= 3 { result[leftArm[2].index] = "LThumb"; assigned.insert(leftArm[2].index) }
        if rightArm.count >= 3 { result[rightArm[2].index] = "RThumb"; assigned.insert(rightArm[2].index) }
        if leftArm.count >= 4 { result[leftArm[3].index] = "LPinky"; assigned.insert(leftArm[3].index) }
        if rightArm.count >= 4 { result[rightArm[3].index] = "RPinky"; assigned.insert(rightArm[3].index) }
        
        // Legs: below hips
        let legRegion = byHeight.suffix(14).filter { !assigned.contains($0.index) }
        let leftLeg = legRegion.filter { $0.pos.x < avgX }.sorted { $0.pos.y > $1.pos.y }
        let rightLeg = legRegion.filter { $0.pos.x >= avgX }.sorted { $0.pos.y > $1.pos.y }
        
        if leftLeg.count >= 1 { result[leftLeg[0].index] = "LKnee"; assigned.insert(leftLeg[0].index) }
        if rightLeg.count >= 1 { result[rightLeg[0].index] = "RKnee"; assigned.insert(rightLeg[0].index) }
        if leftLeg.count >= 2 { result[leftLeg[1].index] = "LAnkle"; assigned.insert(leftLeg[1].index) }
        if rightLeg.count >= 2 { result[rightLeg[1].index] = "RAnkle"; assigned.insert(rightLeg[1].index) }
        if leftLeg.count >= 3 { result[leftLeg[2].index] = "LHeel"; assigned.insert(leftLeg[2].index) }
        if rightLeg.count >= 3 { result[rightLeg[2].index] = "RHeel"; assigned.insert(rightLeg[2].index) }
        if leftLeg.count >= 4 { result[leftLeg[3].index] = "LBigToe"; assigned.insert(leftLeg[3].index) }
        if rightLeg.count >= 4 { result[rightLeg[3].index] = "RBigToe"; assigned.insert(rightLeg[3].index) }
        if leftLeg.count >= 5 { result[leftLeg[4].index] = "LSmallToe"; assigned.insert(leftLeg[4].index) }
        if rightLeg.count >= 5 { result[rightLeg[4].index] = "RSmallToe"; assigned.insert(rightLeg[4].index) }
        
        print("🧠 Spatial identification complete: assigned \(assigned.count)/\(positions.count) markers")
        return result
    }
}

// MARK: - Force Vector Visualization Data

/// Data for visualizing ground reaction forces
public struct ForceVectorData: Sendable {
    public let origin: SIMD3<Float>     // Center of pressure
    public let force: SIMD3<Float>      // Force vector (N)
    public let moment: SIMD3<Float>?    // Moment vector (Nm), optional
    public let plateIndex: Int
    
    public init(origin: SIMD3<Float>, force: SIMD3<Float>, moment: SIMD3<Float>? = nil, plateIndex: Int = 0) {
        self.origin = origin
        self.force = force
        self.moment = moment
        self.plateIndex = plateIndex
    }
    
    /// Scale factor for visualization (converts N to display units)
    public var displayEndPoint: SIMD3<Float> {
        // Scale: 1000N = 1m in display
        let scale: Float = 0.001
        return origin + force * scale
    }
}

// MARK: - Marker Trail Data

/// Trail showing marker trajectory over recent frames
public struct MarkerTrail: Sendable {
    public let markerLabel: String
    public let positions: [SIMD3<Float>]
    public let ages: [Float]  // 0 = current, 1 = oldest
    
    public init(markerLabel: String, positions: [SIMD3<Float>], ages: [Float]) {
        self.markerLabel = markerLabel
        self.positions = positions
        self.ages = ages
    }
}

/// Build marker trails from motion capture data
public func buildMarkerTrails(
    capture: MotionCapture,
    currentFrame: Int,
    trailLength: Int = 30,
    markerLabels: [String]? = nil
) -> [MarkerTrail] {
    let labels = markerLabels ?? capture.markers.labels
    var trails: [MarkerTrail] = []
    
    for label in labels {
        guard let markerIdx = capture.markers.markerIndex(for: label) else { continue }
        
        var positions: [SIMD3<Float>] = []
        var ages: [Float] = []
        
        let startFrame = max(0, currentFrame - trailLength)
        let frameRange = startFrame...currentFrame
        
        for frame in frameRange {
            if let pos = capture.markers.position(marker: markerIdx, frame: frame) {
                positions.append(pos / 1000.0)  // Convert mm to m
                ages.append(Float(currentFrame - frame) / Float(trailLength))
            }
        }
        
        if !positions.isEmpty {
            trails.append(MarkerTrail(
                markerLabel: label,
                positions: positions,
                ages: ages
            ))
        }
    }
    
    return trails
}
