import XCTest
@testable import BioMotionPro

final class SkeletonTests: XCTestCase {
    
    func testAutoDetectSkeleton() throws {
        // Plug-in-Gait style markers (using full set to ensure >80% match)
        let markers = SkeletonModel.plugInGaitOrderedLabels
        let model = try XCTUnwrap(SkeletonModel.autoDetect(from: markers))
        
        // Should detect PlugInGait or at least return a valid model
        XCTAssertFalse(model.bones.isEmpty)
    }
    
    func testJointIndices() {
        let model = SkeletonModel.plugInGait
        // Check standard model has expected joints
        XCTAssertTrue(model.bones.contains { $0.bodyPart == .pelvis })
    }
}
