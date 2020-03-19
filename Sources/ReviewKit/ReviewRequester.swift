//
//  ReviewRequester.swift
//
//  Created by Simon Mitchell on 18/03/2020.
//

#if canImport(Foundation)
import Foundation
#endif

/// This is a protocol which is used by `ReviewRequestController` to actually request a review from the user. On appropriate platforms it is set by default
/// to SKStoreReviewController, but this protocol allows your own logic to be implemented.
public protocol ReviewRequester {
    
    /// This function should request a review from the user
    ///
    /// - Note: Callback with nil, is equivalent to calling back with `true`. It should be used in the case where you're not sure if the user was actually prompted, for example using SKStoreRequestController
    /// - Parameter callback: The callback must always be called, and if you are able to indicate whether a review prompt was actually shown to the user you should return a boolean indicating this.
    func requestReview(callback: (Bool?) -> Void)
}
