import XCTest
@testable import ReviewKit

final class VersionTests: XCTestCase {
    
    func testAddition() {
        
        let versionA = ReviewRequestController.Version(major: 1, minor: 0, patch: 0)
        let versionB = ReviewRequestController.Version(major: 2, minor: 1, patch: 4)
        
        let added = versionA + versionB
        XCTAssertEqual(added.major, 3)
        XCTAssertEqual(added.minor, 1)
        XCTAssertEqual(added.patch, 4)
    }
    
    func testSubtraction() {
        
        let versionA = ReviewRequestController.Version(major: 1, minor: 3, patch: 2)
        let versionB = ReviewRequestController.Version(major: 2, minor: 5, patch: 4)
        
        let subtracted = versionB - versionA
        XCTAssertEqual(subtracted.major, 1)
        XCTAssertEqual(subtracted.minor, 2)
        XCTAssertEqual(subtracted.patch, 2)
    }
    
    func testOverlow() {
        
        let versionA = ReviewRequestController.Version(major: 3, minor: 8, patch: 7)
        let versionB = ReviewRequestController.Version(major: 2, minor: 5, patch: 4)
        
        let subtracted = versionB - versionA
        XCTAssertEqual(subtracted.major, 0)
        XCTAssertEqual(subtracted.minor, 0)
        XCTAssertEqual(subtracted.patch, 0)
    }
    
    func testZero() {
        let zeroVersion = ReviewRequestController.Version.zero
        XCTAssertEqual(zeroVersion.major, 0)
        XCTAssertEqual(zeroVersion.minor, 0)
        XCTAssertEqual(zeroVersion.patch, 0)
    }
    
    func testInitial() {
        let initialVersion = ReviewRequestController.Version.initial
        XCTAssertEqual(initialVersion.major, 1)
        XCTAssertEqual(initialVersion.minor, 0)
        XCTAssertEqual(initialVersion.patch, 0)
    }
    
    func testEquality() {
        
        XCTAssertEqual(ReviewRequestController.Version(major: 1, minor: 2, patch: 3), ReviewRequestController.Version(major: 1, minor: 2, patch: 3))
        XCTAssertNotEqual(ReviewRequestController.Version(major: 2, minor: 2, patch: 3), ReviewRequestController.Version(major: 1, minor: 2, patch: 3))
        XCTAssertNotEqual(ReviewRequestController.Version(major: 1, minor: 3, patch: 3), ReviewRequestController.Version(major: 1, minor: 2, patch: 3))
        XCTAssertNotEqual(ReviewRequestController.Version(major: 1, minor: 2, patch: 4), ReviewRequestController.Version(major: 1, minor: 2, patch: 3))
    }
    
    func testComparison() {
        
        XCTAssertLessThan(ReviewRequestController.Version(major: 0, minor: 2, patch: 3), ReviewRequestController.Version(major: 1, minor: 2, patch: 3))
        XCTAssertLessThan(ReviewRequestController.Version(major: 1, minor: 1, patch: 3), ReviewRequestController.Version(major: 1, minor: 2, patch: 3))
        XCTAssertLessThan(ReviewRequestController.Version(major: 1, minor: 2, patch: 2), ReviewRequestController.Version(major: 1, minor: 2, patch: 3))
        XCTAssertGreaterThanOrEqual(ReviewRequestController.Version(major: 1, minor: 4, patch: 0), ReviewRequestController.Version(major: 1, minor: 4, patch: 0))
    }

    static var allTests = [
        ("testAddition", testAddition),
        ("testSubtraction", testSubtraction),
        ("testOverlow", testOverlow),
        ("testZero", testZero),
        ("testInitial", testInitial),
        ("testEquality", testEquality),
        ("testComparison", testComparison)
    ]
}
