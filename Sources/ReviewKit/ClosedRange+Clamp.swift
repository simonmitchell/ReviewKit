//
//  ClosedRange+Clamp.swift
//  
//
//  Created by Simon Mitchell on 16/03/2020.
//

public extension ClosedRange {
    /// Clamps a given value to the bounds of `self`
    /// - Parameter value: The value to clamp to bounds
    func clamp(_ value : Bound) -> Bound {
        return self.lowerBound > value ? self.lowerBound
            : self.upperBound < value ? self.upperBound
            : value
    }
}
