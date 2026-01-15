import Foundation
import simd

/// Solves for joint angles based on marker positions
public class KinematicsSolver {
    
    /// Calculate standard biomechanical angles for a given capture
    /// Returns a dictionary of Angle Name -> Series
    public static func calculateAngles(capture: MotionCapture, skeleton: SkeletonModel? = nil) -> [String: JointAngleSeries] {
        var results: [String: JointAngleSeries] = [:]
        let frameCount = capture.frameCount
        
        // Helper to get position of a marker by fuzzy name
        func getPos(_ name: String, frame: Int) -> SIMD3<Float>? {
            return capture.markers.position(label: name, frame: frame, fuzzy: true)
        }
        
        // 1. KNEE ANGLES (Flexion/Extension)
        // Requires: Hip, Knee, Ankle
        let kneeAngles = calculateKneeAngles(capture: capture, frameCount: frameCount)
        results.merge(kneeAngles) { (_, new) in new }
        
        // 2. ELBOW ANGLES (Flexion/Extension)
        // Requires: Shoulder, Elbow, Wrist
        let elbowAngles = calculateElbowAngles(capture: capture, frameCount: frameCount)
        results.merge(elbowAngles) { (_, new) in new }
        
        return results
    }
    
    private static func calculateKneeAngles(capture: MotionCapture, frameCount: Int) -> [String: JointAngleSeries] {
        var leftKneeValues = [Float?](repeating: nil, count: frameCount)
        var rightKneeValues = [Float?](repeating: nil, count: frameCount)
        
        // Marker names to attempt
        let lHip = ["LHip", "LASI", "L_IAS", "L.Hip"]
        let lKnee = ["LKnee", "LKNE", "L_Knee", "L.Knee"]
        let lAnkle = ["LAnkle", "LANK", "L_Ankle", "LMAL", "L.Ankle"]
        
        let rHip = ["RHip", "RASI", "R_IAS", "R.Hip"]
        let rKnee = ["RKnee", "RKNE", "R_Knee", "R.Knee"]
        let rAnkle = ["RAnkle", "RANK", "R_Ankle", "RMAL", "R.Ankle"]
        
        for f in 0..<frameCount {
            // LEFT
            if let h = findOne(lHip, frame: f, capture: capture),
               let k = findOne(lKnee, frame: f, capture: capture),
               let a = findOne(lAnkle, frame: f, capture: capture) {
                leftKneeValues[f] = calculateInteriorAngle(a: h, b: k, c: a)
            }
            
            // RIGHT
            if let h = findOne(rHip, frame: f, capture: capture),
               let k = findOne(rKnee, frame: f, capture: capture),
               let a = findOne(rAnkle, frame: f, capture: capture) {
                rightKneeValues[f] = calculateInteriorAngle(a: h, b: k, c: a)
            }
        }
        
        return [
            "Left Knee Flexion": JointAngleSeries(name: "Left Knee Flexion", values: leftKneeValues),
            "Right Knee Flexion": JointAngleSeries(name: "Right Knee Flexion", values: rightKneeValues)
        ]
    }
    
    private static func calculateElbowAngles(capture: MotionCapture, frameCount: Int) -> [String: JointAngleSeries] {
        var leftValues = [Float?](repeating: nil, count: frameCount)
        var rightValues = [Float?](repeating: nil, count: frameCount)
        
        // Marker names
        let lSho = ["LShoulder", "LSHO", "L_Acromion"]
        let lElb = ["LElbow", "LELB", "L_Elbow"]
        let lWri = ["LWrist", "LWRA", "L_Wrist_Rad"]
        
        let rSho = ["RShoulder", "RSHO", "R_Acromion"]
        let rElb = ["RElbow", "RELB", "R_Elbow"]
        let rWri = ["RWrist", "RWRA", "R_Wrist_Rad"]
        
        for f in 0..<frameCount {
            if let s = findOne(lSho, frame: f, capture: capture),
               let e = findOne(lElb, frame: f, capture: capture),
               let w = findOne(lWri, frame: f, capture: capture) {
                leftValues[f] = calculateInteriorAngle(a: s, b: e, c: w)
            }
            
            if let s = findOne(rSho, frame: f, capture: capture),
               let e = findOne(rElb, frame: f, capture: capture),
               let w = findOne(rWri, frame: f, capture: capture) {
                rightValues[f] = calculateInteriorAngle(a: s, b: e, c: w)
            }
        }
        
        return [
            "Left Elbow Flexion": JointAngleSeries(name: "Left Elbow Flexion", values: leftValues),
            "Right Elbow Flexion": JointAngleSeries(name: "Right Elbow Flexion", values: rightValues)
        ]
    }
    
    // Helper to find first valid marker from a list of aliases
    private static func findOne(_ names: [String], frame: Int, capture: MotionCapture) -> SIMD3<Float>? {
        for name in names {
            if let pos = capture.markers.position(label: name, frame: frame, fuzzy: true) {
                return pos
            }
        }
        return nil
    }
    
    /// Calculates the angle at point B formed by segments AB and BC
    /// Returns 0...180 degrees. 180 = Straight line. <180 = Flexion.
    private static func calculateInteriorAngle(a: SIMD3<Float>, b: SIMD3<Float>, c: SIMD3<Float>) -> Float {
        let ba = a - b
        let bc = c - b
        
        let dot = simd_dot(ba, bc)
        let lenBA = simd_length(ba)
        let lenBC = simd_length(bc)
        
        guard lenBA > 0.001, lenBC > 0.001 else { return 0 }
        
        let cosAngle = dot / (lenBA * lenBC)
        let clamped = max(-1, min(1, cosAngle))
        let rad = acos(clamped)
        
        // Convert to degrees
        // Usually, 180 is "full extension" (straight leg).
        // Biomechanists often define flexion as 180 - calculated, or just calculated.
        // We will return the interior angle (0-180). User can interpret.
        // For knee: 180 = straight, 90 = bent.
        return rad * (180.0 / Float.pi)
    }
}
