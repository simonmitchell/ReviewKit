//
//  ReviewRequestController.swift
//
//  Created by Simon Mitchell on 15/03/2020.
//  Copyright © 2020 Simon Mitchell. All rights reserved.
//

#if canImport(Foundation)
import Foundation
#endif

#if canImport(StoreKit)
import StoreKit
#endif


extension TimeInterval {
    /// Time interval constant for a day
    static let day: TimeInterval = 24 * 60 * 60
    /// Time interval constant for a week
    static let week: TimeInterval = 7 * day
}

/// A class for controlling review prompts, this will track sessions for each use of the app and only post reviews when a set of criteria are met
///
/// 1. The session's score has reached a certain threshold value
/// 2. Nothing considered "bad" has happened in the given session (Error, crash, e.t.c)
/// 3. A lower limit of app sessions have been seen by the request controller
/// 4. The last x app sessions had a score above a certain value
/// 5. The last session marked as `bad` was x sessions or a certain date ago
/// 6. The prompt hasn't been requested for a certain period of time
public final class ReviewRequestController {
    
    //MARK: - Classes and Objects
    
    /// An action which can be sent to the review request controller
    public struct Action {
        
        /// The score of the action, could be positive (good) or negative (bad).
        /// Bear in mind the score threshold and average threshold required for the prompt to be shown when providing this value
        public let score: Double
        
        /// If this is set to true, the whole session will be set as bad, and the review prompt won't be shown (If this option is enabled)
        public let isBad: Bool
        
        /// Whether a review should be shown if the review criteria are met after this action
        public let showReview: Bool
        
        /// Initialises a new event
        /// - Parameters:
        ///   - score: The score of the action, positive for good, negative for bad
        ///   - showReview: Whether a review should be shown if the review criteria are met after this action
        ///   - isBad: Whether the action is bad enough to disable review prompt for whole session (If enabled)
        public init(score: Double, showReview: Bool = false, isBad: Bool = false) {
            self.score = score
            self.isBad = isBad
            self.showReview = showReview
        }
    }
    
    
    /// An object representing a semver version
    public struct Version: Codable {
        
        /// The initial version of an app (1, 0, 0)
        public static let initial = Version(major: 1, minor: 0, patch: 0)
        
        /// The major version number
        public let major: UInt
        
        /// The minor version number
        public let minor: UInt
        
        /// The patch version number
        public let patch: UInt
        
        /// Initialises a version given the major, minor, and patch versions
        /// - Parameters:
        ///   - major: The major version
        ///   - minor: The minor version
        ///   - patch: The patch version
        public init(major: UInt, minor: UInt, patch: UInt) {
            self.major = major
            self.minor = minor
            self.patch = patch
        }
    }
    
    /// A session object which tracks an app section, and it's review "score"
    public struct Session: Codable, Equatable {
        
        /// The date that the session began at
        public let date: Date
        
        /// The version that the session was for
        public let version: Version
        
        /// The total score of the session
        public var score: Double
        
        /// Whether the session was marked as "bad" when it was running
        public var isBad: Bool
        
        public static func ==(lhs: Session, rhs: Session) -> Bool {
            return lhs.date == rhs.date && lhs.version == rhs.version
        }
    }
    
    /// A structural representation of a timeout used by the review request controller
    public struct Timeout {
        
        /// Enum representation of either || or &&
        public enum Operator {
            case and
            case or
        }
        
        /// The number of sessions that must have passed for the timeout to have elapsed
        public let sessions: Int
        
        /// The time interval that must have elapsed for the timeout to have done so too
        public let duration: TimeInterval
        
        /// The operator to apply to the two timeout options, allows you to choose whether both must have elapsed,
        /// or just one!
        public let operation: Operator
        
        /// Returns whether the timeout has elapsed based on the parameters provided
        /// - Parameters:
        ///   - testSessions: The number of sessions that have elapsed
        ///   - testDuration: The duration in time that has elapsed
        public func hasElapsedFor(sessions testSessions: Int, duration testDuration: TimeInterval) -> Bool {
            switch operation {
            case .and:
                return testSessions > sessions && testDuration > duration
            case .or:
                return testSessions > sessions || testDuration > duration
            }
        }
        
        /// Initialises a timeout given the sessions, duration and operation
        /// - Parameters:
        ///   - sessions: The number of sessions that must pass for the timeout to be fulfilled
        ///   - duration: The duration of time that must have passed for the timeout to be over
        ///   - operation: The operator to apply to sessions/duration, AND or OR!
        public init(sessions: Int, duration: TimeInterval, operation: Operator) {
            self.sessions = sessions
            self.duration = duration
            self.operation = operation
        }
    }
    
    /// Shared instance of ReviewRequestController
    public static let shared = ReviewRequestController()
    
    /// The storage that the request controller uses to store all it's info.
    /// Defaults to `UserDefaults.standard`, any other UserDefaults instance can also be used due to it's implementation of `ReviewRequestControllerStorage`
    public var storage: ReviewRequestControllerStorage = UserDefaults.standard
    
    //MARK: - Configuration
    
    /// The object that will be used to request a review from the user, on iOS and macOS (assuming min versions) this will default to a proxy object that calls `SKStoreRequestController`'s method
    public var reviewRequester: ReviewRequester?
    
    /// The average score threshold above which the review prompt will be shown, calculated across the number of sessions shown. If there are fewer sessions in total than the given value, the average will be taken over all available sessions. Setting sessions to 0 will skip this step
    public var averageScoreThreshold: (score: Double, sessions: Int) = (score: 75, sessions: 3)
    
    /// The threshold above which the review prompt will be shown to the user assuming other criteria are met
    /// Defaults to 100.0
    public var scoreThreshold: Double = 100.0
    
    /// The restricting bounds of score, this stops the value getting out of control in either positiveness or negativeness...
    /// Defaults to -200...200
    public var scoreBounds: ClosedRange<Double>? = -200.0...200.0
    
    /// The timeout interval for the initial request to be seen
    /// Defaults to 3 sessions and 4 days
    public var initialRequestTimeout: Timeout = Timeout(sessions: 2, duration: 4 * .day, operation: .and)
    
    /// The timeout between review requests
    /// defaults to and AND timeout for 5 sessions and 8 weeks!
    public var reviewRequestTimeout: Timeout = Timeout(sessions: 4, duration: 8 * .week, operation: .and)
    
    /// The difference between the current sessions version and the last reviewed version required to trigger review
    /// Defaults to (major: 0, minor: 0, patch: 1) so the same patch version won't have review requested twice
    public var reviewVersionTimeout: Version? = Version(major: 0, minor: 0, patch: 1)
    
    /// Whether a bad session should entirely disable the review prompt
    public var disabledForBadSession: Bool = true
    
    /// The timeout for which review prompt should not be shown
    /// Defaults to an OR timeout for 2 sessions or 2 days having passed
    public var badSessionTimeout: Timeout = Timeout(sessions: 2, duration: 2 * .day, operation: .or)
        
    private var _currentSession: Session = Session(date: Date(), version: .init(major: 1, minor: 0, patch: 0), score: 0.0, isBad: false)
    
    /// The current running session, can only be got, can't be set. To interact with it please call `logActionWith(score:showReview)`
    public var currentSession: Session {
        return _currentSession
    }
    
    public init() {
        #if canImport(StoreKit) && (os(iOS) || os(macOS))
        if #available(iOS 10.3, macOS 10.14, *) {
            reviewRequester = AppStoreReviewRequester()
        } else {
            // Fallback on earlier versions
        }
        #endif
    }
    
    /// Resets all data!
    public func reset() {
        storage.lastRequestSession = nil
        storage.lastRequestDate = nil
        storage.numberOfSessions = 0
        storage.firstSessionDate = nil
        storage.clearSessions()
        _currentSession = Session(date: Date(), version: _currentSession.version, score: 0.0, isBad: false)
    }
    
    //MARK: - Interaction
    
    /// Starts an app session, should be called where appropriate, and only once per launch ideally. all this does is creates a new session and performs the first save of the session into the storage object
    /// - Parameter version: The version to use for the session
    /// - Parameter date: The start date of the session, defaults to `Date()` used for dependency injection for testing
    public func startSession(version: Version, date: Date = Date()) {
        _currentSession = Session(date: date, version: version, score: 0.0, isBad: false)
        if storage.firstSessionDate == nil {
            storage.firstSessionDate = date
        }
        storage.save(_currentSession)
        storage.numberOfSessions += 1
    }
    
    /// Returns whether the initial timeout for the first prompt to be shown has elapsed
    /// - Parameter date: The date to check against, this allows for testing of this function
    private func timeoutSinceFirstSessionHasElapsed(for date: Date = Date()) -> Bool {
        // Make sure we meet the minimum timeout for showing this to the user
        let firstSessionDate = storage.firstSessionDate ?? _currentSession.date
        let numberOfSessions = storage.numberOfSessions
        return initialRequestTimeout.hasElapsedFor(sessions: numberOfSessions, duration: date.timeIntervalSince(firstSessionDate))
    }
    
    /// Returns whether the initial timeout for the first prompt to be shown has elapsed
    public var timeoutSinceFirstSessionHasElapsed: Bool {
        return timeoutSinceFirstSessionHasElapsed()
    }
    
    /// Returns whether the timeout since the last review prompt was shown has elapsed
    /// - Parameter date: The date to check against, this allows for testing of this function
    private func timeoutSinceLastRequestHasElapsed(for date: Date = Date()) -> Bool {
        // Make sure we meet the minimum timeout for showing this to the user
        guard let lastRequestDate = storage.lastRequestDate, let lastRequestSession = storage.lastRequestSession else {
            return true
        }
        let numberOfSessions = storage.numberOfSessions
        return reviewRequestTimeout.hasElapsedFor(sessions: numberOfSessions - lastRequestSession, duration: date.timeIntervalSince(lastRequestDate))
    }
    
    /// Returns whether the initial timeout for the first prompt to be shown has elapsed
    public var timeoutSinceLastRequestHasElapsed: Bool {
        return timeoutSinceLastRequestHasElapsed()
    }
    
    /// Returns whether the bad request timeout has elapsed
    /// - Parameter date: The date to check against, this allows for testing of this function
    private func timeoutSinceLastBadSessionHasElapsed(for date: Date = Date()) -> Bool {
        // Get all sessions exluding the current session
        let sessions = storage.sessions.filter({ $0 != _currentSession })
        
        // Get the last bad session
        guard let lastBadSessionElement = sessions.enumerated().map({ $0 }).last(where: { $0.element.isBad }) else {
            return true
        }
        
        let sessionsDiff = storage.sessions.count - lastBadSessionElement.offset
        let timeSince = date.timeIntervalSince(lastBadSessionElement.element.date)
        return badSessionTimeout.hasElapsedFor(sessions: sessionsDiff, duration: timeSince)
    }
    
    /// Returns whether the bad request timeout has elapsed. This ignores the current session, which should be checked separately.
    /// - Parameter date: The date to check against, this allows for testing of this function
    public var timeoutSinceLastBadSessionHasElapsed: Bool {
        return timeoutSinceLastBadSessionHasElapsed()
    }
    
    /// Returns whether the app version has changed significantly enough since the last review prompt
    public var versionChangeSinceLastRequestIsSatisfied: Bool {
        guard let lastRequestVersion = storage.lastRequestVersion, let versionTimeout = reviewVersionTimeout else {
            return true
        }
        return _currentSession.version - lastRequestVersion >= versionTimeout
    }
    
    /// Returns whether the average score threshold has been met over the last n sessions. If no previous sessions have occured, this will return false
    public var averageScoreThresholdIsMet: Bool {
        
        // Get all sessions exluding the current session
        let sessions = storage.sessions.filter({ $0 != _currentSession })
        guard averageScoreThreshold.sessions > 0 else {
            return true
        }
        guard !sessions.isEmpty else {
            return false
        }
        
        let sessionsForAverage = sessions.suffix(averageScoreThreshold.sessions)
        let averageScore = sessionsForAverage.map({ $0.score }).average
        return averageScore >= averageScoreThreshold.score
    }
    
    /// Returns whether the current session's score is above the threshold to show a review
    public var currentSessionIsAboveScoreThreshold: Bool {
        return _currentSession.score > scoreThreshold
    }
    
    /// Logs a given app action
    /// - Parameter action: The action that occured
    /// - Parameter callback: A callback which lets you know if a review was requested (Or possibly requested in the case of SKStoreReviewController)
    /// - Parameter currentDate: The date on which the action occured, defaults to `Date()` and only used for testing ideally
    /// - Returns: A boolean value for if a request was made to show review
    public func log(action: Action, callback: ((Result<Bool, Error>) -> Void)? = nil,  date currentDate: Date = Date()) {
        
        // Set the current session's score, but clamp it if a clamp is set!
        if let scoreBounds = scoreBounds {
            _currentSession.score = scoreBounds.clamp(_currentSession.score + action.score)
        } else {
            _currentSession.score += action.score
        }
        
        // Can't mark already bad session as un-bad
        if !_currentSession.isBad, action.isBad {
            _currentSession.isBad = true
        }
        
        // Save the session to storage so it's saved for further sessions to observe
        storage.save(_currentSession)
        
        // If we're not supposed to show a review after this action, then we're done for now!
        guard action.showReview else {
            callback?(Result.success(false))
            return
        }
        
        // Make sure if the session has been marked as bad, then it's ignored if that option is enabled
        guard !_currentSession.isBad || !disabledForBadSession else {
            callback?(Result.success(false))
            return
        }
        
        // Make sure we have met the score threshold for this session
        guard currentSessionIsAboveScoreThreshold else {
            callback?(Result.success(false))
            return
        }
        
        // Test based on initial timeout
        guard timeoutSinceFirstSessionHasElapsed(for: currentDate) else {
            callback?(Result.success(false))
            return
        }
        
        // Make sure timeout since last bad session has elapsed!
        guard timeoutSinceLastBadSessionHasElapsed(for: currentDate) else {
            callback?(Result.success(false))
            return
        }
        
        // Test based on version change since last review
        guard versionChangeSinceLastRequestIsSatisfied else {
            callback?(Result.success(false))
            return
        }
        
        // Test based on timeout since last review
        guard timeoutSinceLastRequestHasElapsed(for: currentDate) else {
            callback?(Result.success(false))
            return
        }

        // Make sure average score is met!
        guard averageScoreThresholdIsMet else {
            callback?(Result.success(false))
            return
        }
        
        guard let reviewRequester = reviewRequester else {
            callback?(Result.failure(RequestError.reviewRequesterNotProvided))
            return
        }
        
        reviewRequester.requestReview { [weak self] (sent) in
            guard sent == true || sent == nil else {
                callback?(Result.success(false))
                return
            }
            guard let self = self else {
                callback?(Result.success(false))
                return
            }
            self.storage.lastRequestDate = currentDate
            self.storage.lastRequestSession = storage.numberOfSessions
            self.storage.lastRequestVersion = _currentSession.version
            callback?(Result.success(true))
        }
    }
    
    enum RequestError: Error {
        case reviewRequesterNotProvided
    }
}
