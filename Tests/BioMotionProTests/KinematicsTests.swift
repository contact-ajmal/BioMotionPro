import XCTest
import simd
@testable import BioMotionPro

final class KinematicsTests: XCTestCase {
    
    func testKneeFlexion() throws {
        // 1. Setup Data for 3 Frames (0: Straight 180, 1: 90 deg, 2: 45 deg)
        let frameCount = 3
        let labels = ["LHip", "LKnee", "LAnkle"]
        
        // Frame 0: Straight Line (Vertical Y)
        // Hip(0,1,0), Knee(0,0.5,0), Ankle(0,0,0)
        // BA = (0, 0.5, 0), BC = (0, -0.5, 0) -> Angle 180
        
        // Frame 1: 90 Degrees
        // Hip(0,1,0), Knee(0,0.5,0), Ankle(0.5,0.5,0)
        // BA = (0, 0.5, 0), BC = (0.5, 0, 0) -> Angle 90
        
        // Frame 2: 45 Degrees (approx)
        // Hip(0,1,0), Knee(0,0,0), Ankle(0.707, 0.707, 0)
        // BA = (0, 1, 0), BC = (0.707, 0.707, 0)
        // Dot = 0.707. Acos(0.707) = 45 deg.
        
        let p0: [SIMD3<Float>?] = [SIMD3(0,1,0), SIMD3(0,0.5,0), SIMD3(0,0,0)]
        let p1: [SIMD3<Float>?] = [SIMD3(0,1,0), SIMD3(0,0.5,0), SIMD3(0.5,0.5,0)]
        let p2: [SIMD3<Float>?] = [SIMD3(0,1,0), SIMD3(0,0,0), SIMD3(0.7071, 0.7071, 0)]
        
        var positions: [[SIMD3<Float>?]] = []
        positions.append(p0)
        positions.append(p1)
        positions.append(p2)
        
        // Transpose to [Frame][Marker]
        // p0 is [Marker], need [[Frame0_M0, Frame0_M1...], [Frame1...]]
        // Actually my p0, p1, p2 definitions above are Frame-based logic but stored as marker lists for that frame.
        // Wait, p0 is Frame 0 positions for [Hip, Knee, Ankle].
        // DataModels expects [[M0, M1, M2], [M0, M1, M2]...]
        
        let markerData = MarkerData(
            labels: labels,
            frameRate: 60.0,
            positions: positions
        )
        
        let capture = MotionCapture(
            metadata: CaptureMetadata(filename: "Test", sampleRate: 60),
            markers: markerData,
            analogs: AnalogData(channels: [], sampleRate: 0)
        )
        
        // 2. Run Solver
        let results = KinematicsSolver.calculateAngles(capture: capture)
        
        // 3. Verify
        guard let kneeAngle = results["Left Knee Flexion"] else {
            XCTFail("Result missing Left Knee Flexion")
            return
        }
        
        XCTAssertEqual(kneeAngle.values.count, 3)
        
        // Frame 0: 180 degrees
        XCTAssertEqual(kneeAngle.values[0]!, 180.0, accuracy: 0.1)
        
        // Frame 1: 90 degrees
        XCTAssertEqual(kneeAngle.values[1]!, 90.0, accuracy: 0.1)
        
        // Frame 2: 45 degrees
        XCTAssertEqual(kneeAngle.values[2]!, 45.0, accuracy: 0.1)
    }
}

// Dummy initializers for test
extension MotionCapture {
    init(metadata: CaptureMetadata, markers: MarkerData, analogs: AnalogData) {
        self.init(metadata: metadata, markers: markers, analogs: analogs, events: [], segments: nil, calculatedAngles: nil)
    }
}

extension CaptureMetadata {
    init(filename: String, sampleRate: Float) {
        self.init(filename: filename, subject: nil, description: nil, captureDate: Date(), manufacturer: nil, softwareVersion: nil)
    }
}
