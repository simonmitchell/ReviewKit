//
//  File.swift
//  
//
//  Created by Simon Mitchell on 16/03/2020.
//

#if canImport(Foundation)
import Foundation
#endif

extension UserDefaults: ReviewRequestControllerStorage {
    
    private static let ReviewSessionsKey = "ReviewRequestSessions"
    
    private static let LastReviewDateKey = "ReviewRequestLastDate"
    
    private static let FirstReviewDateKey = "ReviewRequestFirstDate"
    
    private static let LastReviewSessionKey = "ReviewRequestLastSession"
    
    private static let NumberOfSessionsKey = "ReviewRequestSessions"
    
    private static let LastReviewVersionKey = "ReviewRequestLastVersion"
    
    public func clearSessions() {
        removeObject(forKey: UserDefaults.ReviewSessionsKey)
    }
    
    public func save(_ session: ReviewRequestController.Session) {
        
        var newSessions = sessions
        // If it already exists, then replace it
        if let index = newSessions.firstIndex(of: session) {
            newSessions[index] = session
        } else {
            newSessions.append(session)
        }
        
        do {
            let data = try JSONEncoder().encode(newSessions)
            set(data, forKey: UserDefaults.ReviewSessionsKey)
        } catch _ {
            
        }
    }
    
    public var lastRequestSession: Int? {
        get {
            guard object(forKey: UserDefaults.LastReviewSessionKey) != nil else {
                return nil
            }
            return integer(forKey: UserDefaults.LastReviewSessionKey)
        }
        set {
            if let newValue = newValue {
                set(newValue, forKey: UserDefaults.LastReviewSessionKey)
            } else {
                removeObject(forKey: UserDefaults.LastReviewSessionKey)
            }
        }
    }
    
    public var lastRequestDate: Date? {
        get {
            guard object(forKey: UserDefaults.LastReviewDateKey) != nil else {
                return nil
            }
            let timeInterval = double(forKey: UserDefaults.LastReviewDateKey)
            return Date(timeIntervalSince1970: timeInterval)
        }
        set {
            if let newValue = newValue {
                set(newValue.timeIntervalSince1970, forKey: UserDefaults.LastReviewDateKey)
            } else {
                removeObject(forKey: UserDefaults.LastReviewDateKey)
            }
        }
    }
    
    public var firstSessionDate: Date? {
        get {
            guard object(forKey: UserDefaults.FirstReviewDateKey) != nil else {
                return nil
            }
            let timeInterval = double(forKey: UserDefaults.FirstReviewDateKey)
            return Date(timeIntervalSince1970: timeInterval)
        }
        set {
            if let newValue = newValue {
                set(newValue.timeIntervalSince1970, forKey: UserDefaults.FirstReviewDateKey)
            } else {
                removeObject(forKey: UserDefaults.FirstReviewDateKey)
            }
        }
    }
    
    public var numberOfSessions: Int {
        get {
            return integer(forKey: UserDefaults.ReviewSessionsKey)
        }
        set {
            set(newValue, forKey: UserDefaults.ReviewSessionsKey)
        }
    }
    
    public var lastRequestVersion: ReviewRequestController.Version? {
        get {
            guard let data = data(forKey: UserDefaults.LastReviewVersionKey) else {
                return nil
            }
            return try? JSONDecoder().decode(ReviewRequestController.Version.self, from: data)
        }
        set {
            guard let newValue = newValue else {
                removeObject(forKey: UserDefaults.LastReviewVersionKey)
                return
            }
            do {
                let data = try JSONEncoder().encode(newValue)
                set(data, forKey: UserDefaults.ReviewSessionsKey)
            } catch _ {
                
            }
        }
    }
    
    public var sessions: [ReviewRequestController.Session] {
        guard let data = data(forKey: UserDefaults.ReviewSessionsKey) else {
            return []
        }
        let decoded = try? JSONDecoder().decode(Array<ReviewRequestController.Session>.self, from: data)
        return decoded ?? []
    }
}
