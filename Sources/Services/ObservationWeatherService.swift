import Foundation

struct ObservationWeatherRequest: Sendable {
    let siteName: String
    let latitude: Double
    let longitude: Double
    let timeZoneIdentifier: String
    let sunsetDate: Date
    let nightEndDate: Date
}

struct ObservationWeatherSnapshot: Sendable, Equatable {
    let cloudCoverPercent: Int
    let sunsetTemperatureFahrenheit: Double
    let overnightLowTemperatureFahrenheit: Double
    let sourceName: String
}

enum ObservationWeatherError: LocalizedError {
    case invalidRequest
    case invalidResponse
    case requestFailed(statusCode: Int)
    case forecastUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            return "The observation weather request could not be built."
        case .invalidResponse:
            return "The weather service response was not usable."
        case let .requestFailed(statusCode):
            return "The weather service returned status \(statusCode)."
        case .forecastUnavailable:
            return "Weather forecast data is unavailable for this observation window."
        }
    }
}

enum ObservationWeatherService {
    private static let sourceName = "Open-Meteo Forecast API"
    private static let session = RemoteServiceSessionFactory.makeSession(
        timeoutIntervalForRequest: 10,
        timeoutIntervalForResource: 20
    )

    static func fetchSnapshot(for requestDetails: ObservationWeatherRequest) async throws -> ObservationWeatherSnapshot {
        guard let url = makeRequestURL(for: requestDetails) else {
            throw ObservationWeatherError.invalidRequest
        }

        var request = URLRequest(url: url)
        request.setValue("SmartScopeObservationPlanner/1.0 BigSkyAstro", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw ObservationWeatherError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw ObservationWeatherError.requestFailed(statusCode: httpResponse.statusCode)
        }

        let payload = try JSONDecoder().decode(OpenMeteoForecastResponse.self, from: data)
        let samples = payload.hourly.samples
        guard !samples.isEmpty else {
            throw ObservationWeatherError.forecastUnavailable
        }

        guard let sunsetSample = samples.min(by: {
            abs($0.date.timeIntervalSince(requestDetails.sunsetDate)) < abs($1.date.timeIntervalSince(requestDetails.sunsetDate))
        }) else {
            throw ObservationWeatherError.forecastUnavailable
        }

        let overnightSamples = samples.filter {
            $0.date >= requestDetails.sunsetDate && $0.date <= requestDetails.nightEndDate
        }
        let lowTemperature = (overnightSamples.isEmpty ? samples : overnightSamples)
            .map(\.temperatureFahrenheit)
            .min()

        guard let lowTemperature else {
            throw ObservationWeatherError.forecastUnavailable
        }

        return ObservationWeatherSnapshot(
            cloudCoverPercent: Int(sunsetSample.cloudCoverPercent.rounded()),
            sunsetTemperatureFahrenheit: sunsetSample.temperatureFahrenheit,
            overnightLowTemperatureFahrenheit: lowTemperature,
            sourceName: sourceName
        )
    }

    private static func makeRequestURL(for requestDetails: ObservationWeatherRequest) -> URL? {
        let rangeStart = requestDetails.sunsetDate.addingTimeInterval(-3_600)
        let rangeEnd = requestDetails.nightEndDate.addingTimeInterval(3_600)

        var components = URLComponents(string: "https://api.open-meteo.com/v1/forecast")
        components?.queryItems = [
            URLQueryItem(name: "latitude", value: coordinateString(requestDetails.latitude)),
            URLQueryItem(name: "longitude", value: coordinateString(requestDetails.longitude)),
            URLQueryItem(name: "hourly", value: "temperature_2m,cloud_cover"),
            URLQueryItem(name: "temperature_unit", value: "fahrenheit"),
            URLQueryItem(name: "timezone", value: "UTC"),
            URLQueryItem(name: "start_date", value: formattedUTCDate(rangeStart)),
            URLQueryItem(name: "end_date", value: formattedUTCDate(rangeEnd))
        ]

        return components?.url
    }

    private static func coordinateString(_ value: Double) -> String {
        String(format: "%.4f", value)
    }

    private static func formattedUTCDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }
}

private struct OpenMeteoForecastResponse: Decodable {
    let hourly: OpenMeteoHourlyForecast
}

private struct OpenMeteoHourlyForecast: Decodable {
    let time: [String]
    let temperatureFahrenheit: [Double]
    let cloudCoverPercent: [Double]

    enum CodingKeys: String, CodingKey {
        case time
        case temperatureFahrenheit = "temperature_2m"
        case cloudCoverPercent = "cloud_cover"
    }

    var samples: [OpenMeteoHourlyForecastSample] {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm"

        let sampleCount = min(time.count, temperatureFahrenheit.count, cloudCoverPercent.count)
        return (0 ..< sampleCount).compactMap { index in
            guard let date = formatter.date(from: time[index]) else { return nil }
            return OpenMeteoHourlyForecastSample(
                date: date,
                temperatureFahrenheit: temperatureFahrenheit[index],
                cloudCoverPercent: cloudCoverPercent[index]
            )
        }
    }
}

private struct OpenMeteoHourlyForecastSample {
    let date: Date
    let temperatureFahrenheit: Double
    let cloudCoverPercent: Double
}
