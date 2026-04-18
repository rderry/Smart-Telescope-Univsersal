import Foundation

enum MagnitudeVisibilityPolicy {
    static let maximumIncludedMagnitude = 11.0

    static func allows(magnitude: Double) -> Bool {
        magnitude < maximumIncludedMagnitude
    }

    static func allows(optionalMagnitude: Double?) -> Bool {
        guard let optionalMagnitude else { return true }
        return allows(magnitude: optionalMagnitude)
    }
}
