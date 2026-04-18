import Foundation
import CoreLocation

struct AddressLookupResult {
    let latitude: Double
    let longitude: Double
    let altitudeMeters: Double?
    let formattedAddress: String?
    let countryCode: String?
    let countryName: String?
    let timeZoneIdentifier: String?
}

enum LocationGeocodingError: LocalizedError {
    case invalidAddress
    case invalidCoordinates
    case noMatchFound

    var errorDescription: String? {
        switch self {
        case .invalidAddress:
            "Enter an address before trying to save the location."
        case .invalidCoordinates:
            "Enter valid WGS 84 coordinates before trying to resolve the location."
        case .noMatchFound:
            "No map match was found for that address."
        }
    }
}

enum LocationGeocodingService {
    @MainActor
    static func geocodeAddress(_ address: String, country: CountryOption) async throws -> AddressLookupResult {
        let trimmedAddress = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedAddress.isEmpty else {
            throw LocationGeocodingError.invalidAddress
        }

        let query = "\(trimmedAddress)\n\(country.name)"
        let preferredLocale = Locale(identifier: "en_\(country.code)")
        let placemark = try await geocodeAddressString(query, preferredLocale: preferredLocale)
        return try result(from: placemark)
    }

    @MainActor
    static func reverseGeocodeCoordinates(latitude: Double, longitude: Double) async throws -> AddressLookupResult {
        guard (-90.0 ... 90.0).contains(latitude), (-180.0 ... 180.0).contains(longitude) else {
            throw LocationGeocodingError.invalidCoordinates
        }

        let location = CLLocation(latitude: latitude, longitude: longitude)
        let placemark = try await reverseGeocode(location: location, preferredLocale: .current)
        return try result(from: placemark)
    }

    private static func geocodeAddressString(
        _ addressString: String,
        preferredLocale: Locale
    ) async throws -> CLPlacemark {
        let geocoder = CLGeocoder()

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CLPlacemark, Error>) in
            geocoder.geocodeAddressString(addressString, in: nil, preferredLocale: preferredLocale) { placemarks, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let bestPlacemark = placemarks?.first else {
                    continuation.resume(throwing: LocationGeocodingError.noMatchFound)
                    return
                }

                continuation.resume(returning: bestPlacemark)
            }
        }
    }

    private static func reverseGeocode(
        location: CLLocation,
        preferredLocale: Locale
    ) async throws -> CLPlacemark {
        let geocoder = CLGeocoder()

        return try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<CLPlacemark, Error>) in
            geocoder.reverseGeocodeLocation(location, preferredLocale: preferredLocale) { placemarks, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }

                guard let bestPlacemark = placemarks?.first else {
                    continuation.resume(throwing: LocationGeocodingError.noMatchFound)
                    return
                }

                continuation.resume(returning: bestPlacemark)
            }
        }
    }

    private static func result(from placemark: CLPlacemark) throws -> AddressLookupResult {
        guard let location = placemark.location else {
            throw LocationGeocodingError.noMatchFound
        }

        let altitudeMeters: Double?
        if location.altitude.isFinite {
            altitudeMeters = location.altitude
        } else {
            altitudeMeters = nil
        }

        return AddressLookupResult(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitudeMeters: altitudeMeters,
            formattedAddress: formattedAddress(from: placemark),
            countryCode: placemark.isoCountryCode,
            countryName: placemark.country,
            timeZoneIdentifier: placemark.timeZone?.identifier
        )
    }

    private static func formattedAddress(from placemark: CLPlacemark) -> String? {
        var components: [String] = []

        append(placemark.name, to: &components)
        append(streetAddress(from: placemark), to: &components)
        append(localityAddress(from: placemark), to: &components)
        append(placemark.country, to: &components)

        return components.isEmpty ? nil : components.joined(separator: ", ")
    }

    private static func streetAddress(from placemark: CLPlacemark) -> String? {
        [placemark.subThoroughfare, placemark.thoroughfare]
            .compactMap(normalizedText)
            .joined(separator: " ")
            .nilIfEmpty
    }

    private static func localityAddress(from placemark: CLPlacemark) -> String? {
        [placemark.locality, placemark.administrativeArea, placemark.postalCode]
            .compactMap(normalizedText)
            .joined(separator: " ")
            .nilIfEmpty
    }

    private static func append(_ value: String?, to components: inout [String]) {
        guard
            let normalized = normalizedText(value),
            !components.contains(where: { $0.caseInsensitiveCompare(normalized) == .orderedSame })
        else {
            return
        }

        components.append(normalized)
    }

    private static func normalizedText(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
