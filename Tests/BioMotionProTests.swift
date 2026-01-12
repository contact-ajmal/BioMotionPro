import XCTest
@testable import BioMotionPro

final class C3DParserTests: XCTestCase {
    
    let parser = C3DParser()
    
    func testParserSupportsC3DExtension() {
        XCTAssertEqual(C3DParser.supportedExtensions, ["c3d"])
    }
    
    func testParserThrowsOnMissingFile() async {
        let url = URL(fileURLWithPath: "/nonexistent/file.c3d")
        
        do {
            _ = try await parser.parse(from: url)
            XCTFail("Should have thrown an error")
        } catch let error as ParseError {
            switch error {
            case .fileNotFound:
                break // Expected
            default:
                XCTFail("Wrong error type: \(error)")
            }
        } catch {
            XCTFail("Wrong error type: \(error)")
        }
    }
}

final class BiomechanicsEngineTests: XCTestCase {
    
    let engine = BiomechanicsEngine()
    
    func testButterworthLowpassFilter() async {
        // Generate a test signal: low frequency + high frequency
        let sampleRate = 100.0
        var signal = [Float](repeating: 0, count: 100)
        
        for i in 0..<100 {
            let t = Float(i) / Float(sampleRate)
            // 2 Hz component (should pass)
            // + 30 Hz component (should be filtered out by 10 Hz cutoff)
            signal[i] = sin(2 * .pi * 2 * t) + 0.5 * sin(2 * .pi * 30 * t)
        }
        
        let filtered = await engine.butterworthLowpass(
            data: signal,
            sampleRate: sampleRate,
            cutoffFrequency: 10
        )
        
        XCTAssertEqual(filtered.count, signal.count)
        
        // High frequency component should be attenuated
        let originalVariance = signal.map { $0 * $0 }.reduce(0, +) / Float(signal.count)
        let filteredVariance = filtered.map { $0 * $0 }.reduce(0, +) / Float(filtered.count)
        
        // Filtered signal should have lower variance (high freq removed)
        // Ideal variance is ~0.5 (from 2Hz) vs ~0.625 (from 2Hz + 30Hz)
        // 0.625 * 0.8 = 0.5. We use 0.85 to allow for non-ideal filter roll-off/transients
        XCTAssertLessThan(filteredVariance, originalVariance * 0.85)
    }
    
    func testJointAngleComputation() async {
        // Test with a 90-degree angle
        let proximal = SIMD3<Float>(0, 0, 0)
        let center = SIMD3<Float>(1, 0, 0)
        let distal = SIMD3<Float>(1, 1, 0)
        
        let angle = await engine.computeAngle(proximal: proximal, center: center, distal: distal)
        
        XCTAssertEqual(angle, 90, accuracy: 0.1)
    }
    
    func testGaitEventDetection() async {
        // Simulate GRF data with two stance phases
        var grf = [Float](repeating: 0, count: 1000)
        
        // First stance: samples 100-400
        for i in 100..<400 {
            grf[i] = 500  // 500N during stance
        }
        
        // Second stance: samples 600-900
        for i in 600..<900 {
            grf[i] = 500
        }
        
        let events = await engine.detectGaitEventsFromGRF(
            verticalForce: grf,
            sampleRate: 1000,
            threshold: 20
        )
        
        XCTAssertEqual(events.count, 4)  // 2 heel strikes + 2 toe offs
        
        let heelStrikes = events.filter { $0.type == .heelStrike }
        let toeOffs = events.filter { $0.type == .toeOff }
        
        XCTAssertEqual(heelStrikes.count, 2)
        XCTAssertEqual(toeOffs.count, 2)
    }
}

final class MarkerDataTests: XCTestCase {
    
    func testMarkerDataBasics() {
        let positions: [[SIMD3<Float>?]] = [
            [SIMD3(0, 0, 0), SIMD3(1, 0, 0)],
            [SIMD3(0, 1, 0), SIMD3(1, 1, 0)],
            [nil, SIMD3(1, 2, 0)]
        ]
        
        let markers = MarkerData(
            labels: ["M1", "M2"],
            frameRate: 100,
            positions: positions
        )
        
        XCTAssertEqual(markers.frameCount, 3)
        XCTAssertEqual(markers.markerCount, 2)
        XCTAssertEqual(markers.markerIndex(for: "M1"), 0)
        XCTAssertEqual(markers.markerIndex(for: "M2"), 1)
        XCTAssertNil(markers.markerIndex(for: "M3"))
        
        // Test position access
        XCTAssertEqual(markers.position(marker: 0, frame: 0), SIMD3(0, 0, 0))
        XCTAssertNil(markers.position(marker: 0, frame: 2))  // Occluded
        
        // Test trajectory
        let trajectory = markers.trajectory(for: 1)
        XCTAssertEqual(trajectory.count, 3)
        XCTAssertEqual(trajectory[0], SIMD3(1, 0, 0))
        XCTAssertEqual(trajectory[1], SIMD3(1, 1, 0))
        XCTAssertEqual(trajectory[2], SIMD3(1, 2, 0))
    }
}
