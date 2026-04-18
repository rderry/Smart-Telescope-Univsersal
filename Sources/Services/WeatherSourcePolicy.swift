import Foundation

struct WeatherSourceDescriptor: Sendable, Equatable {
    let name: String
    let systemImage: String
    let website: String

    static let nationalWeatherService = WeatherSourceDescriptor(
        name: "NOAA National Weather Service",
        systemImage: "cloud.sun",
        website: "weather.gov"
    )

    static let metNorway = WeatherSourceDescriptor(
        name: "MET Norway Global Weather API",
        systemImage: "globe.americas",
        website: "api.met.no"
    )
}

enum WeatherSourcePolicy {
    static func source(for countryCode: String?) -> WeatherSourceDescriptor {
        switch countryCode?.uppercased() {
        case "US":
            .nationalWeatherService
        default:
            .metNorway
        }
    }
}
