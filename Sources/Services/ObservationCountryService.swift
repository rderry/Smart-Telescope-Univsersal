import Foundation
import CoreLocation

struct ObservationCountryRequest: Sendable {
    let latitude: Double
    let longitude: Double
}

struct ObservationCountryDetails: Sendable, Equatable {
    let countryCode: String
    let countryName: String
}

actor ObservationCountryService {
    static let shared = ObservationCountryService()

    func resolveCountry(for request: ObservationCountryRequest) async throws -> ObservationCountryDetails {
        let location = CLLocation(latitude: request.latitude, longitude: request.longitude)
        let preferredLocale = Locale.current
        let placemark = try await Self.reverseGeocode(location: location, preferredLocale: preferredLocale)

        guard
            let countryCode = Self.countryCode(from: placemark),
            let countryName = Self.displayName(
                forCountryCode: countryCode,
                fallback: placemark.country,
                locale: preferredLocale
            )
        else {
            throw ObservationCountryError.countryUnavailable
        }

        return ObservationCountryDetails(
            countryCode: countryCode.uppercased(),
            countryName: countryName
        )
    }

    private static func reverseGeocode(
        location: CLLocation,
        preferredLocale: Locale
    ) async throws -> CLPlacemark {
        let geocoder = CLGeocoder()

        return try await withCheckedThrowingContinuation { continuation in
            geocoder.reverseGeocodeLocation(location, preferredLocale: preferredLocale) { placemarks, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let placemark = placemarks?.first else {
                    continuation.resume(throwing: ObservationCountryError.countryUnavailable)
                    return
                }

                continuation.resume(returning: placemark)
            }
        }
    }

    private static func countryCode(from placemark: CLPlacemark) -> String? {
        let code = placemark.isoCountryCode?.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines) ?? ""
        return code.isEmpty ? nil : code.uppercased()
    }

    private static func displayName(
        forCountryCode code: String,
        fallback: String?,
        locale: Locale
    ) -> String? {
        let localizedName = locale.localizedString(forRegionCode: code)
            ?? Locale(identifier: "en_US").localizedString(forRegionCode: code)
            ?? fallback
        let trimmedName = localizedName?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (trimmedName?.isEmpty == false) ? trimmedName : nil
    }
}

enum ObservationCountryError: LocalizedError {
    case countryUnavailable

    var errorDescription: String? {
        switch self {
        case .countryUnavailable:
            "Country lookup was unavailable for this observation location."
        }
    }
}
