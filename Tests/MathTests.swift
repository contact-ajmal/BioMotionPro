import XCTest
import simd
@testable import BioMotionPro

final class MathTests: XCTestCase {
    
    func testQuaternionFromEuler() {
        // Test 90 degree rotation around X
        let angleX = Float.pi / 2
        let q = simd_quatf(angle: angleX, axis: SIMD3(1, 0, 0))
        
        // Expected: w=cos(45), x=sin(45), y=0, z=0
        let expectedVal = cos(angleX / 2)
        XCTAssertEqual(q.real, expectedVal, accuracy: 0.001)
        XCTAssertEqual(q.imag.x, expectedVal, accuracy: 0.001)
        XCTAssertEqual(q.imag.y, 0, accuracy: 0.001)
        XCTAssertEqual(q.imag.z, 0, accuracy: 0.001)
    }
    
    func testMatrixDoesNotThrow() {
        // Basic check that we can create matrices
        let identity = matrix_identity_float4x4
        XCTAssertEqual(identity.columns.0.x, 1)
        XCTAssertEqual(identity.columns.1.y, 1)
    }
}
