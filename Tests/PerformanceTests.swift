import XCTest
@testable import BioMotionPro

final class PerformanceTests: XCTestCase {
    
    func testMathPerformance() {
        // Measure vector math performance (simulating heavy frame updates)
        self.measure {
            var sum = SIMD3<Float>(0, 0, 0)
            for i in 0..<100_000 {
                let v = SIMD3<Float>(Float(i), Float(i)*2, Float(i)/2)
                let r = v * 0.5 + SIMD3<Float>(1, 1, 1)
                sum += r
            }
        }
    }
    
    func testSkeletonUpdatePerformance() {
        // Measure cost of updating skeleton bones per frame
        // Create a mock skeleton with 50 bones
        let bones = (0..<50).map { i in 
            BoneConnection("M\(i)", "M\(i+1)") 
        }
        let model = SkeletonModel(name: "PerfSkeleton", bones: bones)
        
        // Mock positions
        var positions = [SIMD3<Float>?](repeating: SIMD3<Float>(0,0,0), count: 60)
        
        self.measure {
            for _ in 0..<1000 {
                // Simulate one frame update: calculating bone transforms
                for bone in model.bones {
                    // Logic similar to SceneRenderer loop
                    // Just simulated here since we can't easily access SceneRenderer from tests without metal device
                    _ = bone.bodyPart
                }
            }
        }
    }
}
