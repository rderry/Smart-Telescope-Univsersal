import Foundation

enum ElevationLookupError: LocalizedError {
    case invalidCoordinates
    case noElevationFound

    var errorDescription: String? {
        switch self {
        case .invalidCoordinates:
            "Enter valid WGS 84 coordinates before trying to resolve elevation."
        case .noElevationFound:
            "No terrain elevation was found for that location."
        }
    }
}

enum ElevationLookupService {
    private static let session = RemoteServiceSessionFactory.makeSession(
        timeoutIntervalForRequest: 8,
        timeoutIntervalForResource: 12
    )

    static func elevationMeters(latitude: Double, longitude: Double) async throws -> Double {
        guard (-90.0 ... 90.0).contains(latitude), (-180.0 ... 180.0).contains(longitude) else {
            throw ElevationLookupError.invalidCoordinates
        }

        if let usgsElevation = try? await usgsElevationMeters(latitude: latitude, longitude: longitude) {
            return usgsElevation
        }

        if let openMeteoElevation = try? await openMeteoElevationMeters(latitude: latitude, longitude: longitude) {
            return openMeteoElevation
        }

        throw ElevationLookupError.noElevationFound
    }

    static func usgsElevationMeters(from data: Data) throws -> Double {
        let response = try JSONDecoder().decode(USGSElevationResponse.self, from: data)
        guard let value = response.value.doubleValue, value.isFinite, value > -100_000 else {
            throw ElevationLookupError.noElevationFound
        }
        return value
    }

    static func openMeteoElevationMeters(from data: Data) throws -> Double {
        let response = try JSONDecoder().decode(OpenMeteoElevationResponse.self, from: data)
        guard let value = response.elevation.first, value.isFinite else {
            throw ElevationLookupError.noElevationFound
        }
        return value
    }

    private static func usgsElevationMeters(latitude: Double, longitude: Double) async throws -> Double {
        var components = URLComponents(string: "https://epqs.nationalmap.gov/v1/json")
        components?.queryItems = [
            URLQueryItem(name: "x", value: longitude.formatted(.number.precision(.fractionLength(8)))),
            URLQueryItem(name: "y", value: latitude.formatted(.number.precision(.fractionLength(8)))),
            URLQueryItem(name: "wkid", value: "4326"),
            URLQueryItem(name: "units", value: "Meters"),
            URLQueryItem(name: "includeDate", value: "false")
        ]

        guard let url = components?.url else {
            throw ElevationLookupError.invalidCoordinates
        }

        let (data, response) = try await session.data(from: url)
        try validateHTTPResponse(response)
        return try usgsElevationMeters(from: data)
    }

    private static func openMeteoElevationMeters(latitude: Double, longitude: Double) async throws -> Double {
        var components = URLComponents(string: "https://api.open-meteo.com/v1/elevation")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: latitude.formatted(.number.precision(.fractionLength(8)))),
            URLQueryItem(name: "longitude", value: longitude.formatted(.number.precision(.fractionLength(8))))
        ]

        guard let url = components?.url else {
            throw ElevationLookupError.invalidCoordinates
        }

        let (data, response) = try await session.data(from: url)
        try validateHTTPResponse(response)
        return try openMeteoElevationMeters(from: data)
    }

    private static func validateHTTPResponse(_ response: URLResponse) throws {
        guard let httpResponse = response as? HTTPURLResponse else { return }
        guard (200 ... 299).contains(httpResponse.statusCode) else {
            throw ElevationLookupError.noElevationFound
        }
    }
}

private struct USGSElevationResponse: Decodable {
    let value: LossyDouble
}

private struct OpenMeteoElevationResponse: Decodable {
    let elevation: [Double]
}

private struct LossyDouble: Decodable {
    let doubleValue: Double?

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let value = try? container.decode(Double.self) {
            doubleValue = value
        } else if let value = try? container.decode(String.self) {
            doubleValue = Double(value)
        } else {
            doubleValue = nil
        }
    }
}
