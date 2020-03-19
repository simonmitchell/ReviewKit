//
//  File.swift
//  
//
//  Created by Simon Mitchell on 16/03/2020.
//

extension ReviewRequestController.Version: Comparable {
    public static func < (lhs: ReviewRequestController.Version, rhs: ReviewRequestController.Version) -> Bool {
        guard lhs.major == rhs.major else {
            return lhs.major < rhs.major
        }
        guard lhs.minor == rhs.minor else {
            return lhs.minor < rhs.minor
        }
        return lhs.patch < rhs.patch
    }
}

extension ReviewRequestController.Version: Equatable {
    public static func == (lhs: ReviewRequestController.Version, rhs: ReviewRequestController.Version) -> Bool {
        return lhs.major == rhs.major && lhs.minor == rhs.minor && lhs.patch == rhs.patch
    }
}

extension ReviewRequestController.Version: AdditiveArithmetic {
    
    public static func -= (lhs: inout ReviewRequestController.Version, rhs: ReviewRequestController.Version) {
        lhs = lhs - rhs
    }
    
    public static func - (lhs: ReviewRequestController.Version, rhs: ReviewRequestController.Version) -> ReviewRequestController.Version {
        return ReviewRequestController.Version(
            major: UInt(max(0, Int(lhs.major) - Int(rhs.major))),
            minor: UInt(max(0, Int(lhs.minor) - Int(rhs.minor))),
            patch: UInt(max(0, Int(lhs.patch) - Int(rhs.patch)))
        )
    }
    
    public static func += (lhs: inout ReviewRequestController.Version, rhs: ReviewRequestController.Version) {
        lhs = lhs + rhs
    }
    
    public static func + (lhs: ReviewRequestController.Version, rhs: ReviewRequestController.Version) -> ReviewRequestController.Version {
        return ReviewRequestController.Version(major: lhs.major + rhs.major, minor: lhs.minor + rhs.minor, patch: lhs.patch + rhs.patch)
    }
    
    public static var zero: ReviewRequestController.Version {
        return ReviewRequestController.Version(major: 0, minor: 0, patch: 0)
    }
}
