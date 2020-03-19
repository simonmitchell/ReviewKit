import XCTest
@testable import ReviewKit

final class TimeoutTests: XCTestCase {
    
    func testTimeoutOrReturnsTrueIfOnlyTimeIntervalPassed() {
        
        let timeout = ReviewRequestController.Timeout(sessions: 10, duration: 2000, operation: .or)
        XCTAssertTrue(timeout.hasElapsedFor(sessions: 5, duration: 2001))
    }

    func testTimeoutOrReturnsTrueIfOnlySessionsPassed() {
        
        let timeout = ReviewRequestController.Timeout(sessions: 10, duration: 2000, operation: .or)
        XCTAssertTrue(timeout.hasElapsedFor(sessions: 11, duration: 1999))
    }
    
    func testTimeoutOrReturnsTrueIfTimeoutAndSessionsPassed() {
        
        let timeout = ReviewRequestController.Timeout(sessions: 10, duration: 2000, operation: .or)
        XCTAssertTrue(timeout.hasElapsedFor(sessions: 11, duration: 2001))
    }
    
    func testTimeoutOrReturnsFalseIfNeitherPassed() {
        
        let timeout = ReviewRequestController.Timeout(sessions: 10, duration: 2000, operation: .or)
        XCTAssertFalse(timeout.hasElapsedFor(sessions: 9, duration: 1999))
    }
    
    func testTimeoutAndReturnsFalseIfOnlyTimeIntervalPassed() {
        
        let timeout = ReviewRequestController.Timeout(sessions: 10, duration: 2000, operation: .and)
        XCTAssertFalse(timeout.hasElapsedFor(sessions: 5, duration: 2001))
    }

    func testTimeoutAndReturnsFalseIfOnlySessionsPassed() {
        
        let timeout = ReviewRequestController.Timeout(sessions: 10, duration: 2000, operation: .and)
        XCTAssertFalse(timeout.hasElapsedFor(sessions: 11, duration: 1999))
    }
    
    func testTimeoutAndReturnsTrueIfTimeoutAndSessionsPassed() {
        
        let timeout = ReviewRequestController.Timeout(sessions: 10, duration: 2000, operation: .and)
        XCTAssertTrue(timeout.hasElapsedFor(sessions: 11, duration: 2001))
    }
    
    func testTimeoutAndReturnsFalseIfNeitherPassed() {
        
        let timeout = ReviewRequestController.Timeout(sessions: 10, duration: 2000, operation: .and)
        XCTAssertFalse(timeout.hasElapsedFor(sessions: 9, duration: 1999))
    }

    static var allTests = [
        ("testTimeoutOrReturnsTrueIfOnlyTimeIntervalPassed", testTimeoutOrReturnsTrueIfOnlyTimeIntervalPassed),
        ("testTimeoutOrReturnsTrueIfOnlySessionsPassed", testTimeoutOrReturnsTrueIfOnlySessionsPassed),
        ("testTimeoutOrReturnsTrueIfTimeoutAndSessionsPassed", testTimeoutOrReturnsTrueIfTimeoutAndSessionsPassed),
        ("testTimeoutOrReturnsFalseIfNeitherPassed", testTimeoutOrReturnsFalseIfNeitherPassed),
        ("testTimeoutAndReturnsFalseIfOnlyTimeIntervalPassed", testTimeoutAndReturnsFalseIfOnlyTimeIntervalPassed),
        ("testTimeoutAndReturnsFalseIfOnlySessionsPassed", testTimeoutAndReturnsFalseIfOnlySessionsPassed),
        ("testTimeoutAndReturnsTrueIfTimeoutAndSessionsPassed", testTimeoutAndReturnsTrueIfTimeoutAndSessionsPassed),
        ("testTimeoutAndReturnsFalseIfNeitherPassed", testTimeoutAndReturnsFalseIfNeitherPassed),
    ]
}
