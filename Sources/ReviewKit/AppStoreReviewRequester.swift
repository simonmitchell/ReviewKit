//
//  File.swift
//  
//
//  Created by Simon Mitchell on 18/03/2020.
//

#if canImport(StoreKit) && (os(iOS) || os(macOS))
import StoreKit

@available(iOS 10.3, *, macOS 10.14, *)
public final class AppStoreReviewRequester: ReviewRequester {
    
    public func requestReview(callback: (Bool?) -> Void) {
        SKStoreReviewController.requestReview()
        callback(nil)
    }
}
#endif
