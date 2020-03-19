import XCTest
@testable import ReviewKit

final class ClosedRangeClampTests: XCTestCase {
    
    func testClampsToUpper() {
        let range = -100...100
        XCTAssertEqual(range.clamp(2120), 100)
    }
    func testClampsToLower() {
        let range = -100...100
        XCTAssertEqual(range.clamp(-200), -100)
    }

    func testDoesntClampIfIncludes() {
        let range = -100...100
        XCTAssertEqual(range.clamp(40), 40)
    }

    static var allTests = [
        ("testClampsToUpper", testClampsToUpper),
        ("testClampsToLower", testClampsToLower),
        ("testDoesntClampIfIncludes", testDoesntClampIfIncludes)
    ]
}

