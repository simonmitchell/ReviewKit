//
//  Bundle+Version.swift
//  
//
//  Created by Simon Mitchell on 27/03/2020.
//

#if canImport(Foundation)
import Foundation

public extension Bundle {
    
    /// Returns the `CFBundleShortVersionString` value from the bundle as a version struct
    var version: ReviewRequestController.Version {
        
        // This can never NOT be present, so we won't force unwrap, but we will throw a fatal error if it is missing for some reason
        guard let versionString = infoDictionary?["CFBundleShortVersionString"] as? String else {
            fatalError("You cannot access Bundle().version if CFBundleShortVersionString is not present, please use a manually constructed version instead.")
        }
        
        let components = versionString.components(separatedBy: ".")
        
        // Apple requires `CFBundleShortVersionString` to be a set of integers separated by '.' so we can `fatalError` if the user hasn't done this!
        guard let firstComponent = components.first, let major = UInt(firstComponent) else {
            fatalError("CFBundleVersionString must be a string consisting of integers separated by a . otherwise Apple will reject your app.")
        }
        
        // If have only provided `major` part of version, fallback to `0`
        let minor: UInt = components.count > 1 ? UInt(components[1]) ?? 0 : 0
        // If haven't provided `patch` part of version string, fallback to `0`
        let patch: UInt = components.count > 2 ? UInt(components[2]) ?? 0 : 0
        
        return ReviewRequestController.Version(major: major, minor: minor, patch: patch)
    }
}

#endif
