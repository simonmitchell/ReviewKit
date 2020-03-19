import XCTest
@testable import ReviewKit

class TestRequestControllerStorage: ReviewRequestControllerStorage {
    
    func clearSessions() {
        sessions = []
    }
    
    func save(_ session: ReviewRequestController.Session) {
        // If it already exists, then replace it
        if let index = sessions.firstIndex(of: session) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
    }
    
    var lastRequestDate: Date?
    
    var lastRequestSession: Int?
    
    var lastRequestVersion: ReviewRequestController.Version?
    
    var firstSessionDate: Date?
    
    var numberOfSessions: Int
    
    var sessions: [ReviewRequestController.Session]
    
    init(sessions: [ReviewRequestController.Session]) {
        
        self.numberOfSessions = sessions.count
        self.sessions = sessions
    }
}

class TestReviewRequester: ReviewRequester {
    
    func requestReview(callback: (Bool?) -> Void) {
        wasCalled = true
        callback(response)
    }
    
    let response: Bool?
    
    var wasCalled: Bool = false
    
    init(response: Bool?) {
        self.response = response
    }
}

final class ReviewKitTests: XCTestCase {
    
    override func tearDown() {
        ReviewRequestController.shared.reset()
        ReviewRequestController.shared.disabledForBadSession = true
        ReviewRequestController.shared.badSessionTimeout = .init(sessions: 2, duration: 2 * .day, operation: .or)
        ReviewRequestController.shared.averageScoreThreshold = (score: 75, sessions: 3)
        ReviewRequestController.shared.scoreThreshold = 100.0
        ReviewRequestController.shared.reviewRequestTimeout = .init(sessions: 4, duration: 8 * .week, operation: .and)
        ReviewRequestController.shared.initialRequestTimeout = .init(sessions: 2, duration: 4 * .day, operation: .and)
        ReviewRequestController.shared.scoreBounds = -200.0...200.0
    }
    
    func testScoreUpdatesCorrectlyWithAction() {
        
        let requestController = ReviewRequestController.shared
        let testRequester = TestReviewRequester(response: nil)
        requestController.reviewRequester = testRequester
        requestController.storage = TestRequestControllerStorage(sessions: [])
        requestController.log(action: .init(score: 30))
        XCTAssertEqual(requestController.storage.sessions.last?.score, 30)
        XCTAssertEqual(requestController.currentSession.score, 30)
    }
    
    func testScoreLimitedToProvidedLowerBound() {
        
        let requestController = ReviewRequestController.shared
        let testRequester = TestReviewRequester(response: nil)
        requestController.reviewRequester = testRequester
        requestController.storage = TestRequestControllerStorage(sessions: [])
        requestController.scoreBounds = -10.0...10.0
        requestController.log(action: .init(score: -30))
        XCTAssertEqual(requestController.storage.sessions.last?.score, -10)
        XCTAssertEqual(requestController.currentSession.score, -10)
    }
    
    func testScoreLimitedToProvidedUpperBound() {
        
        let requestController = ReviewRequestController.shared
        let testRequester = TestReviewRequester(response: nil)
        requestController.reviewRequester = testRequester
        requestController.storage = TestRequestControllerStorage(sessions: [])
        requestController.scoreBounds = -10.0...10.0
        requestController.log(action: .init(score: 30))
        XCTAssertEqual(requestController.storage.sessions.last?.score, 10)
        XCTAssertEqual(requestController.currentSession.score, 10)
    }
    
    func testScoreNotLimitedIfBoundsNil() {
        
        let requestController = ReviewRequestController.shared
        let testRequester = TestReviewRequester(response: nil)
        requestController.reviewRequester = testRequester
        requestController.storage = TestRequestControllerStorage(sessions: [])
        requestController.scoreBounds = nil
        requestController.log(action: .init(score: 10000))
        XCTAssertEqual(requestController.storage.sessions.last?.score, 10000)
        XCTAssertEqual(requestController.currentSession.score, 10000)
    }
    
    func testTotalScoreCalculatedCorrectly() {
        let requestController = ReviewRequestController.shared
        let testRequester = TestReviewRequester(response: nil)
        requestController.reviewRequester = testRequester
        requestController.storage = TestRequestControllerStorage(sessions: [])
        requestController.log(action: .init(score: 10000)) // 200 - 30
        requestController.log(action: .init(score: -30))   // 170 + 10
        requestController.log(action: .init(score: 10))    // 180 - 70
        requestController.log(action: .init(score: -70))   // 110
        XCTAssertEqual(requestController.storage.sessions.last?.score, 110)
        XCTAssertEqual(requestController.currentSession.score, 110)
    }
    
    func testStartingInitialSessionSavesToStorage() {
        
        let requestController = ReviewRequestController.shared
        let testRequester = TestReviewRequester(response: nil)
        requestController.reviewRequester = testRequester
        let storage = TestRequestControllerStorage(sessions: [])
        requestController.storage = storage
        requestController.startSession(version: .initial, date: Date(timeIntervalSince1970: 0))
        
        XCTAssertEqual(storage.firstSessionDate, Date(timeIntervalSince1970: 0))
        XCTAssertEqual(storage.sessions.count, 1)
        XCTAssertEqual(storage.sessions.first?.date, Date(timeIntervalSince1970: 0))
        XCTAssertEqual(storage.numberOfSessions, 1)
    }
    
    func testInitialStateAfterStartIsCorrect() {
        
        let requestController = ReviewRequestController.shared
        let testRequester = TestReviewRequester(response: nil)
        requestController.reviewRequester = testRequester
        let storage = TestRequestControllerStorage(sessions: [])
        let date = Date(timeIntervalSince1970: 0)
        requestController.storage = storage
        requestController.startSession(version: .initial, date: date)
        
        XCTAssertEqual(storage.sessions.last?.isBad, false)
        XCTAssertEqual(storage.firstSessionDate, date)
        XCTAssertEqual(storage.sessions.count, 1)
        XCTAssertEqual(storage.numberOfSessions, 1)
        XCTAssertNil(storage.lastRequestDate)
        XCTAssertNil(storage.lastRequestSession)
        XCTAssertFalse(requestController.currentSession.isBad)
        XCTAssertEqual(requestController.currentSession.date, date)
    }
    
    func testSessionWithNewDateAppendedCorrectly() {
        
        let requestController = ReviewRequestController.shared
        let testRequester = TestReviewRequester(response: nil)
        requestController.reviewRequester = testRequester
        let storage = TestRequestControllerStorage(sessions: [])
        let date = Date(timeIntervalSince1970: 0)
        requestController.storage = storage
        requestController.startSession(version: .initial, date: date)
        requestController.startSession(version: .initial, date: date.addingTimeInterval(100))
        
        XCTAssertEqual(storage.firstSessionDate, date)
        XCTAssertEqual(storage.sessions.count, 2)
        XCTAssertEqual(storage.numberOfSessions, 2)
        XCTAssertEqual(requestController.currentSession.date, date.addingTimeInterval(100))
        XCTAssertEqual(storage.sessions.last?.date, date.addingTimeInterval(100))
    }
    
    func testLoggingBadActionMarksSessionAsBad() {
        
        let requestController = ReviewRequestController.shared
        let testRequester = TestReviewRequester(response: nil)
        requestController.reviewRequester = testRequester
        let storage = TestRequestControllerStorage(sessions: [])
        requestController.storage = storage
        requestController.startSession(version: .initial)
        
        requestController.log(action: .init(score: -40, showReview: false, isBad: true))
        
        XCTAssertTrue(requestController.currentSession.isBad)
        XCTAssertEqual(storage.sessions.last?.isBad, true)
    }
    
    func testLoggingGoodActionDoesntUnMarkSessionAsBad() {
        
        let requestController = ReviewRequestController.shared
        let testRequester = TestReviewRequester(response: nil)
        requestController.reviewRequester = testRequester
        let storage = TestRequestControllerStorage(sessions: [])
        requestController.storage = storage
        requestController.startSession(version: .initial)
        
        requestController.log(action: .init(score: -40, showReview: false, isBad: true))
        requestController.log(action: .init(score: -20, showReview: false, isBad: false))
        
        XCTAssertTrue(requestController.currentSession.isBad)
        XCTAssertEqual(storage.sessions.last?.isBad, true)
    }
    
    func testReviewNotShownUnlessActionIsReviewable() {
        
        let requestController = ReviewRequestController.shared
        let testRequester = TestReviewRequester(response: nil)
        requestController.reviewRequester = testRequester
        let storage = TestRequestControllerStorage(sessions: [
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -105 * .day), version: .zero, score: 200, isBad: false),
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -100 * .day), version: .zero, score: 200, isBad: false),
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -95 * .day), version: .zero, score: 200, isBad: false)
        ])
        requestController.storage = storage
        requestController.startSession(version: .initial)
        
        let expectation = self.expectation(description: "log_action")
        var result: Result<Bool, Error>? = nil
        requestController.log(action: .init(score: 200, showReview: false, isBad: false), callback: { (logResult) in
            result = logResult
            expectation.fulfill()
        })
        waitForExpectations(timeout: 2, handler: nil)
        XCTAssertFalse(testRequester.wasCalled)
        XCTAssertNotNil(result)
        guard let _result = result else {
            XCTFail("Result not returned")
            return
        }
        switch _result {
        case .success(let sent):
            XCTAssertFalse(sent)
        default:
            XCTFail("Unexpected error occured")
        }
    }
    
    func testReviewNotShownIfSessionMarkedBad() {
        
        let requestController = ReviewRequestController.shared
        let testRequester = TestReviewRequester(response: nil)
        requestController.reviewRequester = testRequester
        let storage = TestRequestControllerStorage(sessions: [
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -105 * .day), version: .zero, score: 200, isBad: false),
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -100 * .day), version: .zero, score: 200, isBad: false),
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -95 * .day), version: .zero, score: 200, isBad: false)
        ])
        requestController.storage = storage
        requestController.startSession(version: .initial)
        
        let expectation = self.expectation(description: "log_action")
        var result: Result<Bool, Error>? = nil
        requestController.log(action: .init(score: 200, showReview: true, isBad: true), callback: { (logResult) in
            result = logResult
            expectation.fulfill()
        })
        waitForExpectations(timeout: 2, handler: nil)
        XCTAssertFalse(testRequester.wasCalled)
        XCTAssertNotNil(result)
        guard let _result = result else {
            XCTFail("Result not returned")
            return
        }
        switch _result {
        case .success(let sent):
            XCTAssertFalse(sent)
        default:
            XCTFail("Unexpected error occured")
        }
    }
    
    func testReviewShownForBadActionIfAllowBadSessions() {
        
        let requestController = ReviewRequestController.shared
        let testRequester = TestReviewRequester(response: nil)
        requestController.reviewRequester = testRequester
        requestController.disabledForBadSession = false
        let storage = TestRequestControllerStorage(sessions: [
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -105 * .day), version: .zero, score: 200, isBad: false),
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -100 * .day), version: .zero, score: 200, isBad: false),
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -95 * .day), version: .zero, score: 200, isBad: false)
        ])
        storage.firstSessionDate = Date(timeIntervalSinceNow: -105 * .day)
        requestController.storage = storage
        requestController.startSession(version: .initial)
        
        let expectation = self.expectation(description: "log_action")
        var result: Result<Bool, Error>? = nil
        requestController.log(action: .init(score: 200, showReview: true, isBad: true), callback: { (logResult) in
            result = logResult
            expectation.fulfill()
        })
        waitForExpectations(timeout: 2, handler: nil)
        XCTAssertTrue(testRequester.wasCalled)
        XCTAssertNotNil(result)
        guard let _result = result else {
            XCTFail("Result not returned")
            return
        }
        switch _result {
        case .success(let sent):
            XCTAssertTrue(sent)
        default:
            XCTFail("Unexpected error occured")
        }
    }
    
    func testReviewNotShownIfCurrentSessionThresholdNotMet()  {
        
        let requestController = ReviewRequestController.shared
        let testRequester = TestReviewRequester(response: nil)
        requestController.reviewRequester = testRequester
        requestController.disabledForBadSession = false
        let storage = TestRequestControllerStorage(sessions: [
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -105 * .day), version: .zero, score: 200, isBad: false),
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -100 * .day), version: .zero, score: 200, isBad: false),
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -95 * .day), version: .zero, score: 200, isBad: false)
        ])
        storage.firstSessionDate = Date(timeIntervalSinceNow: -105 * .day)
        requestController.storage = storage
        requestController.startSession(version: .initial)
        
        let expectation = self.expectation(description: "log_action")
        var result: Result<Bool, Error>? = nil
        requestController.log(action: .init(score: 50, showReview: true, isBad: false), callback: { (logResult) in
            result = logResult
            expectation.fulfill()
        })
        waitForExpectations(timeout: 2, handler: nil)
        XCTAssertFalse(testRequester.wasCalled)
        XCTAssertNotNil(result)
        guard let _result = result else {
            XCTFail("Result not returned")
            return
        }
        switch _result {
        case .success(let sent):
            XCTAssertFalse(sent)
        default:
            XCTFail("Unexpected error occured")
        }
    }
    
    func testReviewNotShownIfInitialTimeoutTimeIntervalNotMet()  {
        
        let requestController = ReviewRequestController.shared
        let testRequester = TestReviewRequester(response: nil)
        requestController.reviewRequester = testRequester
        requestController.disabledForBadSession = false
        let storage = TestRequestControllerStorage(sessions: [
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -1 * .day), version: .zero, score: 200, isBad: false),
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -1.1 * .day), version: .zero, score: 200, isBad: false),
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -1.2 * .day), version: .zero, score: 200, isBad: false)
        ])
        storage.numberOfSessions = 3
        storage.firstSessionDate = Date(timeIntervalSinceNow: -1 * .day)
        requestController.storage = storage
        requestController.startSession(version: .initial)
        
        let expectation = self.expectation(description: "log_action")
        var result: Result<Bool, Error>? = nil
        requestController.log(action: .init(score: 200, showReview: true, isBad: false), callback: { (logResult) in
            result = logResult
            expectation.fulfill()
        })
        waitForExpectations(timeout: 2, handler: nil)
        XCTAssertFalse(testRequester.wasCalled)
        XCTAssertNotNil(result)
        guard let _result = result else {
            XCTFail("Result not returned")
            return
        }
        switch _result {
        case .success(let sent):
            XCTAssertFalse(sent)
        default:
            XCTFail("Unexpected error occured")
        }
    }
    
    func testReviewNotShownIfInitialTimeoutSessionsNotMet()  {
        
        let requestController = ReviewRequestController.shared
        let testRequester = TestReviewRequester(response: nil)
        requestController.reviewRequester = testRequester
        requestController.disabledForBadSession = false
        let storage = TestRequestControllerStorage(sessions: [
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -1 * .day), version: .zero, score: 200, isBad: false)
        ])
        storage.numberOfSessions = 1
        storage.firstSessionDate = Date(timeIntervalSinceNow: -100 * .day)
        requestController.storage = storage
        requestController.startSession(version: .initial)
        
        let expectation = self.expectation(description: "log_action")
        var result: Result<Bool, Error>? = nil
        requestController.log(action: .init(score: 200, showReview: true, isBad: false), callback: { (logResult) in
            result = logResult
            expectation.fulfill()
        })
        waitForExpectations(timeout: 2, handler: nil)
        XCTAssertFalse(testRequester.wasCalled)
        XCTAssertNotNil(result)
        guard let _result = result else {
            XCTFail("Result not returned")
            return
        }
        switch _result {
        case .success(let sent):
            XCTAssertFalse(sent)
        default:
            XCTFail("Unexpected error occured")
        }
    }
    
    func testReviewNotShownIfBadSessionTimeoutTimeIntervalNotMet()  {
        
        let requestController = ReviewRequestController.shared
        let testRequester = TestReviewRequester(response: nil)
        requestController.reviewRequester = testRequester
        requestController.initialRequestTimeout = ReviewRequestController.Timeout(sessions: 0, duration: 0, operation: .or)
        let storage = TestRequestControllerStorage(sessions: [
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -1.3 * .day), version: .zero, score: 200, isBad: true),
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -1.2 * .day), version: .zero, score: 200, isBad: false),
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -1.1 * .day), version: .zero, score: 200, isBad: false),
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -1 * .day), version: .zero, score: 200, isBad: true)
        ])
        storage.numberOfSessions = 3
        requestController.storage = storage
        requestController.startSession(version: .initial)
        
        let expectation = self.expectation(description: "log_action")
        var result: Result<Bool, Error>? = nil
        requestController.log(action: .init(score: 200, showReview: true, isBad: false), callback: { (logResult) in
            result = logResult
            expectation.fulfill()
        })
        waitForExpectations(timeout: 2, handler: nil)
        XCTAssertFalse(testRequester.wasCalled)
        XCTAssertNotNil(result)
        guard let _result = result else {
            XCTFail("Result not returned")
            return
        }
        switch _result {
        case .success(let sent):
            XCTAssertFalse(sent)
        default:
            XCTFail("Unexpected error occured")
        }
    }
    
    func testReviewNotShownIfBadSessionTimeoutSessionsNotMet()  {
        
        let requestController = ReviewRequestController.shared
        let testRequester = TestReviewRequester(response: nil)
        requestController.reviewRequester = testRequester
        requestController.initialRequestTimeout = ReviewRequestController.Timeout(sessions: 0, duration: 0, operation: .or)
        let storage = TestRequestControllerStorage(sessions: [
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -1.2 * .day), version: .zero, score: 200, isBad: false),
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -1.3 * .day), version: .zero, score: 200, isBad: true)
        ])
        storage.numberOfSessions = 3
        requestController.storage = storage
        requestController.startSession(version: .initial)
        
        let expectation = self.expectation(description: "log_action")
        var result: Result<Bool, Error>? = nil
        requestController.log(action: .init(score: 200, showReview: true, isBad: false), callback: { (logResult) in
            result = logResult
            expectation.fulfill()
        })
        waitForExpectations(timeout: 2, handler: nil)
        XCTAssertFalse(testRequester.wasCalled)
        XCTAssertNotNil(result)
        guard let _result = result else {
            XCTFail("Result not returned")
            return
        }
        switch _result {
        case .success(let sent):
            XCTAssertFalse(sent)
        default:
            XCTFail("Unexpected error occured")
        }
    }
    
    func testReviewNotShownIfLastRequestTimeoutTimeIntervalNotMet()  {
        
        let requestController = ReviewRequestController.shared
        let testRequester = TestReviewRequester(response: nil)
        requestController.reviewRequester = testRequester
        requestController.initialRequestTimeout = ReviewRequestController.Timeout(sessions: 0, duration: 0, operation: .or)
        requestController.badSessionTimeout = ReviewRequestController.Timeout(sessions: 0, duration: 0, operation: .or)
        requestController.reviewRequestTimeout = ReviewRequestController.Timeout(sessions: 10, duration: 100 * .day, operation: .and)
        let storage = TestRequestControllerStorage(sessions: [])
        storage.lastRequestSession = 80
        storage.lastRequestDate = Date(timeIntervalSince1970: -2 * .day)
        storage.numberOfSessions = 100
        requestController.storage = storage
        requestController.startSession(version: .initial, date: Date(timeIntervalSince1970: 0))
        
        let expectation = self.expectation(description: "log_action")
        var result: Result<Bool, Error>? = nil
        requestController.log(action: .init(score: 200, showReview: true, isBad: false), callback: { (logResult) in
            result = logResult
            expectation.fulfill()
        }, date: Date(timeIntervalSince1970: 1))
        waitForExpectations(timeout: 2, handler: nil)
        XCTAssertFalse(testRequester.wasCalled)
        XCTAssertNotNil(result)
        guard let _result = result else {
            XCTFail("Result not returned")
            return
        }
        switch _result {
        case .success(let sent):
            XCTAssertFalse(sent)
        default:
            XCTFail("Unexpected error occured")
        }
    }
    
    func testReviewNotShownIfLastRequestTimeoutSessionsNotMet()  {
        
        let requestController = ReviewRequestController.shared
        let testRequester = TestReviewRequester(response: nil)
        requestController.reviewRequester = testRequester
        requestController.initialRequestTimeout = ReviewRequestController.Timeout(sessions: 0, duration: 0, operation: .or)
        requestController.badSessionTimeout = ReviewRequestController.Timeout(sessions: 0, duration: 0, operation: .or)
        requestController.reviewRequestTimeout = ReviewRequestController.Timeout(sessions: 10, duration: .day, operation: .and)
        let storage = TestRequestControllerStorage(sessions: [])
        storage.lastRequestSession = 99
        storage.lastRequestDate = Date(timeIntervalSince1970: -2 * .day)
        storage.numberOfSessions = 100
        requestController.storage = storage
        requestController.startSession(version: .initial, date: Date(timeIntervalSince1970: 0))
        
        let expectation = self.expectation(description: "log_action")
        var result: Result<Bool, Error>? = nil
        requestController.log(action: .init(score: 200, showReview: true, isBad: false), callback: { (logResult) in
            result = logResult
            expectation.fulfill()
        })
        waitForExpectations(timeout: 2, handler: nil)
        XCTAssertFalse(testRequester.wasCalled)
        XCTAssertNotNil(result)
        guard let _result = result else {
            XCTFail("Result not returned")
            return
        }
        switch _result {
        case .success(let sent):
            XCTAssertFalse(sent)
        default:
            XCTFail("Unexpected error occured")
        }
    }
    
    func testReviewNotShownIfVersionChangeThresholdNotMet() {
        
        let requestController = ReviewRequestController.shared
        let testRequester = TestReviewRequester(response: nil)
        requestController.reviewRequester = testRequester
        let storage = TestRequestControllerStorage(sessions: [
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -107 * .day), version: .zero, score: 200, isBad: false),
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -106 * .day), version: .zero, score: 200, isBad: false),
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -105 * .day), version: .zero, score: 200, isBad: false)
        ])
        storage.numberOfSessions = 3
        storage.lastRequestVersion = .initial
        storage.firstSessionDate = Date(timeIntervalSinceNow: -105 * .day)
        requestController.storage = storage
        requestController.startSession(version: .initial)
        
        let expectation = self.expectation(description: "log_action")
        var result: Result<Bool, Error>? = nil
        requestController.log(action: .init(score: 200, showReview: true, isBad: false), callback: { (logResult) in
            result = logResult
            expectation.fulfill()
        })
        waitForExpectations(timeout: 2, handler: nil)
        XCTAssertFalse(testRequester.wasCalled)
        XCTAssertNotNil(result)
        guard let _result = result else {
            XCTFail("Result not returned")
            return
        }
        switch _result {
        case .success(let sent):
            XCTAssertFalse(sent)
        default:
            XCTFail("Unexpected error occured")
        }
    }
    
    func testReviewNotShownIfAverageScoreNotMet() {
        
        let requestController = ReviewRequestController.shared
        let testRequester = TestReviewRequester(response: nil)
        requestController.reviewRequester = testRequester
        let storage = TestRequestControllerStorage(sessions: [
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -105 * .day), version: .zero, score: 78, isBad: false),
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -100 * .day), version: .zero, score: 60, isBad: false),
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -95 * .day), version: .zero, score: 72, isBad: false)
        ])
        storage.firstSessionDate = Date(timeIntervalSinceNow: -105 * .day)
        requestController.storage = storage
        requestController.startSession(version: .initial)
        
        let expectation = self.expectation(description: "log_action")
        var result: Result<Bool, Error>? = nil
        requestController.log(action: .init(score: 200, showReview: true, isBad: true), callback: { (logResult) in
            result = logResult
            expectation.fulfill()
        })
        waitForExpectations(timeout: 2, handler: nil)
        XCTAssertFalse(testRequester.wasCalled)
        XCTAssertNotNil(result)
        guard let _result = result else {
            XCTFail("Result not returned")
            return
        }
        switch _result {
        case .success(let sent):
            XCTAssertFalse(sent)
        default:
            XCTFail("Unexpected error occured")
        }
    }
    
    func testAverageForReviewsCalculatedOverCorrectNumberOfSessions() {
        
        let requestController = ReviewRequestController.shared
        let testRequester = TestReviewRequester(response: nil)
        requestController.reviewRequester = testRequester
        let storage = TestRequestControllerStorage(sessions: [
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -107 * .day), version: .zero, score: 200, isBad: false),
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -106 * .day), version: .zero, score: 200, isBad: false),
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -105 * .day), version: .zero, score: 78, isBad: false),
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -100 * .day), version: .zero, score: 60, isBad: false),
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -95 * .day), version: .zero, score: 72, isBad: false)
        ])
        storage.firstSessionDate = Date(timeIntervalSinceNow: -105 * .day)
        requestController.storage = storage
        requestController.startSession(version: .initial)
        
        let expectation = self.expectation(description: "log_action")
        var result: Result<Bool, Error>? = nil
        requestController.log(action: .init(score: 200, showReview: true, isBad: true), callback: { (logResult) in
            result = logResult
            expectation.fulfill()
        })
        waitForExpectations(timeout: 2, handler: nil)
        XCTAssertFalse(testRequester.wasCalled)
        XCTAssertNotNil(result)
        guard let _result = result else {
            XCTFail("Result not returned")
            return
        }
        switch _result {
        case .success(let sent):
            XCTAssertFalse(sent)
        default:
            XCTFail("Unexpected error occured")
        }
    }
    
    func testReviewShownIfAllCriteriaMet() {
        
        let requestController = ReviewRequestController.shared
        let testRequester = TestReviewRequester(response: nil)
        requestController.reviewRequester = testRequester
        let storage = TestRequestControllerStorage(sessions: [
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -107 * .day), version: .initial, score: 200, isBad: false),
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -106 * .day), version: .initial, score: 200, isBad: false),
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -105 * .day), version: .initial, score: 200, isBad: false)
        ])
        storage.numberOfSessions = 8
        storage.firstSessionDate = Date(timeIntervalSinceNow: -105 * .day)
        storage.lastRequestVersion = .zero
        storage.lastRequestDate = Date(timeIntervalSinceNow: -80 * .day)
        storage.lastRequestSession = 1
        requestController.storage = storage
        requestController.startSession(version: .init(major: 1, minor: 0, patch: 1))
        
        let expectation = self.expectation(description: "log_action")
        var result: Result<Bool, Error>? = nil
        requestController.log(action: .init(score: 200, showReview: true, isBad: false), callback: { (logResult) in
            result = logResult
            expectation.fulfill()
        })
        waitForExpectations(timeout: 2, handler: nil)
        XCTAssertTrue(testRequester.wasCalled)
        XCTAssertNotNil(result)
        guard let _result = result else {
            XCTFail("Result not returned")
            return
        }
        switch _result {
        case .success(let sent):
            XCTAssertTrue(sent)
        default:
            XCTFail("Unexpected error occured")
        }
    }
    
    func testStoragePropertiesSetCorrectlyWhenReviewRequested() {
        
        let requestController = ReviewRequestController.shared
        let testRequester = TestReviewRequester(response: nil)
        requestController.reviewRequester = testRequester
        let storage = TestRequestControllerStorage(sessions: [
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -107 * .day), version: .zero, score: 200, isBad: false),
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -106 * .day), version: .zero, score: 200, isBad: false),
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -105 * .day), version: .zero, score: 200, isBad: false)
        ])
        storage.numberOfSessions = 3
        storage.firstSessionDate = Date(timeIntervalSinceNow: -105 * .day)
        requestController.storage = storage
        requestController.startSession(version: .initial)
        
        let date = Date()
        
        let expectation = self.expectation(description: "log_action")
        var result: Result<Bool, Error>? = nil
        requestController.log(action: .init(score: 200, showReview: true, isBad: false), callback: { (logResult) in
            result = logResult
            expectation.fulfill()
        }, date: date)
        waitForExpectations(timeout: 2, handler: nil)
        XCTAssertEqual(storage.lastRequestDate, date)
        XCTAssertEqual(storage.lastRequestSession, 4)
        XCTAssertEqual(storage.lastRequestVersion, .initial)
        XCTAssertTrue(testRequester.wasCalled)
        XCTAssertNotNil(result)
        guard let _result = result else {
            XCTFail("Result not returned")
            return
        }
        switch _result {
        case .success(let sent):
            XCTAssertTrue(sent)
        default:
            XCTFail("Unexpected error occured")
        }
    }
    
    func testStoragePropertiesNotSetWhenReviewRequesterDidntShowPrompt() {
        
        let requestController = ReviewRequestController.shared
        let testRequester = TestReviewRequester(response: false)
        requestController.reviewRequester = testRequester
        let storage = TestRequestControllerStorage(sessions: [
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -107 * .day), version: .zero, score: 200, isBad: false),
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -106 * .day), version: .zero, score: 200, isBad: false),
            ReviewRequestController.Session(date: Date(timeIntervalSinceNow: -105 * .day), version: .zero, score: 200, isBad: false)
        ])
        storage.numberOfSessions = 3
        storage.firstSessionDate = Date(timeIntervalSinceNow: -105 * .day)
        requestController.storage = storage
        requestController.startSession(version: .initial)
        
        let date = Date()
        
        let expectation = self.expectation(description: "log_action")
        var result: Result<Bool, Error>? = nil
        requestController.log(action: .init(score: 200, showReview: true, isBad: false), callback: { (logResult) in
            result = logResult
            expectation.fulfill()
        }, date: date)
        waitForExpectations(timeout: 2, handler: nil)
        XCTAssertNil(storage.lastRequestDate)
        XCTAssertNil(storage.lastRequestSession)
        XCTAssertNil(storage.lastRequestVersion)
        XCTAssertTrue(testRequester.wasCalled)
        XCTAssertNotNil(result)
        guard let _result = result else {
            XCTFail("Result not returned")
            return
        }
        switch _result {
        case .success(let sent):
            XCTAssertFalse(sent)
        default:
            XCTFail("Unexpected error occured")
        }
    }
    
    static var allTests = [
        ("testScoreUpdatesCorrectlyWithAction", testScoreUpdatesCorrectlyWithAction),
        ("testScoreLimitedToProvidedLowerBound", testScoreLimitedToProvidedLowerBound),
        ("testScoreLimitedToProvidedUpperBound", testScoreLimitedToProvidedUpperBound),
        ("testScoreNotLimitedIfBoundsNil", testScoreNotLimitedIfBoundsNil),
        ("testTotalScoreCalculatedCorrectly", testTotalScoreCalculatedCorrectly),
        ("testStartingInitialSessionSavesToStorage", testStartingInitialSessionSavesToStorage),
        ("testInitialStateAfterStartIsCorrect", testInitialStateAfterStartIsCorrect),
        ("testSessionWithNewDateAppendedCorrectly", testSessionWithNewDateAppendedCorrectly),
        ("testLoggingBadActionMarksSessionAsBad", testLoggingBadActionMarksSessionAsBad),
        ("testLoggingGoodActionDoesntUnMarkSessionAsBad", testLoggingGoodActionDoesntUnMarkSessionAsBad),
        ("testReviewNotShownUnlessActionIsReviewable", testReviewNotShownUnlessActionIsReviewable),
        ("testReviewNotShownIfSessionMarkedBad", testReviewNotShownIfSessionMarkedBad),
        ("testReviewShownForBadActionIfAllowBadSessions", testReviewShownForBadActionIfAllowBadSessions),
        ("testReviewNotShownIfCurrentSessionThresholdNotMet", testReviewNotShownIfCurrentSessionThresholdNotMet),
        ("testReviewNotShownIfInitialTimeoutTimeIntervalNotMet", testReviewNotShownIfInitialTimeoutTimeIntervalNotMet),
        ("testReviewNotShownIfInitialTimeoutSessionsNotMet", testReviewNotShownIfInitialTimeoutSessionsNotMet),
        ("testReviewNotShownIfBadSessionTimeoutTimeIntervalNotMet", testReviewNotShownIfBadSessionTimeoutTimeIntervalNotMet),
        ("testReviewNotShownIfBadSessionTimeoutSessionsNotMet", testReviewNotShownIfBadSessionTimeoutSessionsNotMet),
        ("testReviewNotShownIfLastRequestTimeoutTimeIntervalNotMet", testReviewNotShownIfLastRequestTimeoutTimeIntervalNotMet),
        ("testReviewNotShownIfLastRequestTimeoutSessionsNotMet", testReviewNotShownIfLastRequestTimeoutSessionsNotMet),
        ("testReviewNotShownIfAverageScoreNotMet", testReviewNotShownIfAverageScoreNotMet),
        ("testAverageForReviewsCalculatedOverCorrectNumberOfSessions", testAverageForReviewsCalculatedOverCorrectNumberOfSessions),
        ("testReviewShownIfAllCriteriaMet", testReviewShownIfAllCriteriaMet),
        ("testStoragePropertiesSetCorrectlyWhenReviewRequested", testStoragePropertiesSetCorrectlyWhenReviewRequested),
        ("testReviewNotShownIfVersionChangeThresholdNotMet", testReviewNotShownIfVersionChangeThresholdNotMet),
        ("testStoragePropertiesNotSetWhenReviewRequesterDidntShowPrompt", testStoragePropertiesNotSetWhenReviewRequesterDidntShowPrompt)
    ]
}
