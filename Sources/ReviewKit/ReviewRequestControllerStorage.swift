//
//  ReviewRequestControllerStorage.swift
//  
//  Created by Simon Mitchell on 16/03/2020.
//  Copyright © 2020 Simon Mitchell. All rights reserved.
//

#if canImport(Foundation)
import Foundation
#endif

/// A protocol for storing info about review requests, allows us to dependency inject for tests
public protocol ReviewRequestControllerStorage {
    
    /// Clears all sessions stored
    func clearSessions()
    
    /// Saves a session to the storage, should replace existing sessions if already in storage
    /// - Parameter session: The session to save
    func save(_ session: ReviewRequestController.Session)
    
    /// The last time a review request was asked for, i.e. all review criteria were met
    var lastRequestDate: Date? { get set }
    
    /// The last session in which a review request was asked for
    var lastRequestSession: Int? { get set }
    
    /// The last version in which a review request was asked for
    var lastRequestVersion: ReviewRequestController.Version? { get set }
    
    /// The date of the first app session recorded
    var firstSessionDate: Date? { get set }
    
    /// The number of app sessions that have occured, this should not be maintained internally by implementers of this protocol, it will be set by the `ReviewRequestController` where deemed appropriate
    var numberOfSessions: Int { get set }
    
    /// All sessions that have occured
    var sessions: [ReviewRequestController.Session] { get }
}
