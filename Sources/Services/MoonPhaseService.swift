import Foundation

struct MoonPhaseSnapshot: Equatable, Sendable {
    let phaseDegrees: Double

    var phaseName: String {
        switch normalizedPhaseDegrees {
        case 0..<22.5, 337.5..<360:
            "New Moon"
        case 22.5..<67.5:
            "Waxing Crescent"
        case 67.5..<112.5:
            "First Quarter"
        case 112.5..<157.5:
            "Waxing Gibbous"
        case 157.5..<202.5:
            "Full Moon"
        case 202.5..<247.5:
            "Waning Gibbous"
        case 247.5..<292.5:
            "Last Quarter"
        default:
            "Waning Crescent"
        }
    }

    var symbolName: String {
        switch normalizedPhaseDegrees {
        case 0..<22.5, 337.5..<360:
            "moonphase.new.moon"
        case 22.5..<67.5:
            "moonphase.waxing.crescent"
        case 67.5..<112.5:
            "moonphase.first.quarter"
        case 112.5..<157.5:
            "moonphase.waxing.gibbous"
        case 157.5..<202.5:
            "moonphase.full.moon"
        case 202.5..<247.5:
            "moonphase.waning.gibbous"
        case 247.5..<292.5:
            "moonphase.last.quarter"
        default:
            "moonphase.waning.crescent"
        }
    }

    private var normalizedPhaseDegrees: Double {
        let remainder = phaseDegrees.truncatingRemainder(dividingBy: 360)
        return remainder >= 0 ? remainder : remainder + 360
    }
}

struct MoonEquatorialCoordinates: Equatable, Sendable {
    let rightAscensionHours: Double
    let declinationDegrees: Double
}

struct MoonPhaseRequest: Sendable {
    let date: Date
    let latitude: Double
    let longitude: Double
    let timeZoneIdentifier: String
}

enum MoonPhaseService {
    private static let session = RemoteServiceSessionFactory.makeSession(
        timeoutIntervalForRequest: 10,
        timeoutIntervalForResource: 20
    )

    static func fetchMoonPhase(for requestDetails: MoonPhaseRequest) async throws -> MoonPhaseSnapshot {
        guard let url = makeRequestURL(for: requestDetails) else {
            throw MoonPhaseError.invalidRequest
        }

        var request = URLRequest(url: url)
        request.setValue("SmartScopeObservationPlanner/1.0 BigSkyAstro", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw MoonPhaseError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw MoonPhaseError.requestFailed(statusCode: httpResponse.statusCode)
        }

        let payload = try JSONDecoder().decode(METMoonResponse.self, from: data)

        guard let phaseValue = payload.properties.moonphase?.value else {
            throw MoonPhaseError.phaseUnavailable
        }

        return MoonPhaseSnapshot(phaseDegrees: phaseValue)
    }

    static func approximateSnapshot(for date: Date) -> MoonPhaseSnapshot {
        let synodicMonth = 29.530588853
        let knownNewMoonJulianDay = 2451550.1
        var phaseCycles = (julianDay(for: date) - knownNewMoonJulianDay) / synodicMonth
        phaseCycles -= floor(phaseCycles)

        if phaseCycles < 0 {
            phaseCycles += 1
        }

        return MoonPhaseSnapshot(phaseDegrees: phaseCycles * 360)
    }

    static func approximateEquatorialCoordinates(for date: Date) -> MoonEquatorialCoordinates {
        let daysSinceEpoch = julianDay(for: date) - 2451543.5
        let ascendingNode = degreesToRadians(normalizedDegrees(125.1228 - 0.0529538083 * daysSinceEpoch))
        let inclination = degreesToRadians(5.1454)
        let periapsis = degreesToRadians(normalizedDegrees(318.0634 + 0.1643573223 * daysSinceEpoch))
        let semiMajorAxis = 60.2666
        let eccentricity = 0.0549
        let meanAnomaly = degreesToRadians(normalizedDegrees(115.3654 + 13.0649929509 * daysSinceEpoch))

        let eccentricAnomaly = meanAnomaly + eccentricity * sin(meanAnomaly) * (1 + eccentricity * cos(meanAnomaly))
        let orbitalX = semiMajorAxis * (cos(eccentricAnomaly) - eccentricity)
        let orbitalY = semiMajorAxis * (sqrt(1 - eccentricity * eccentricity) * sin(eccentricAnomaly))
        let trueAnomaly = atan2(orbitalY, orbitalX)
        let distance = sqrt((orbitalX * orbitalX) + (orbitalY * orbitalY))
        let eclipticLongitude = trueAnomaly + periapsis

        let xh = distance * (cos(ascendingNode) * cos(eclipticLongitude) - sin(ascendingNode) * sin(eclipticLongitude) * cos(inclination))
        let yh = distance * (sin(ascendingNode) * cos(eclipticLongitude) + cos(ascendingNode) * sin(eclipticLongitude) * cos(inclination))
        let zh = distance * (sin(eclipticLongitude) * sin(inclination))

        let obliquity = degreesToRadians(23.4393 - (0.0000003563 * daysSinceEpoch))
        let xe = xh
        let ye = (yh * cos(obliquity)) - (zh * sin(obliquity))
        let ze = (yh * sin(obliquity)) + (zh * cos(obliquity))

        let rightAscensionRadians = atan2(ye, xe)
        let declinationRadians = atan2(ze, sqrt((xe * xe) + (ye * ye)))

        return MoonEquatorialCoordinates(
            rightAscensionHours: normalizedHours((radiansToDegrees(rightAscensionRadians)) / 15),
            declinationDegrees: radiansToDegrees(declinationRadians)
        )
    }

    static func angularSeparationDegrees(
        rightAscensionHours firstRightAscensionHours: Double,
        declinationDegrees firstDeclinationDegrees: Double,
        secondRightAscensionHours: Double,
        secondDeclinationDegrees: Double
    ) -> Double {
        let firstRightAscensionRadians = degreesToRadians(firstRightAscensionHours * 15)
        let firstDeclinationRadians = degreesToRadians(firstDeclinationDegrees)
        let secondRightAscensionRadians = degreesToRadians(secondRightAscensionHours * 15)
        let secondDeclinationRadians = degreesToRadians(secondDeclinationDegrees)

        let cosineSeparation =
            (sin(firstDeclinationRadians) * sin(secondDeclinationRadians)) +
            (cos(firstDeclinationRadians) * cos(secondDeclinationRadians) * cos(firstRightAscensionRadians - secondRightAscensionRadians))

        return radiansToDegrees(acos(min(max(cosineSeparation, -1), 1)))
    }

    private static func makeRequestURL(for requestDetails: MoonPhaseRequest) -> URL? {
        let timeZone = TimeZone(identifier: requestDetails.timeZoneIdentifier) ?? .current

        var components = URLComponents(string: "https://api.met.no/weatherapi/sunrise/3.0/moon")
        components?.queryItems = [
            URLQueryItem(name: "date", value: formattedDate(requestDetails.date, in: timeZone)),
            URLQueryItem(name: "lat", value: coordinateString(requestDetails.latitude)),
            URLQueryItem(name: "lon", value: coordinateString(requestDetails.longitude)),
            URLQueryItem(name: "offset", value: offsetString(for: requestDetails.date, in: timeZone))
        ]

        return components?.url
    }

    private static func formattedDate(_ date: Date, in timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func coordinateString(_ value: Double) -> String {
        let factor = 10_000.0
        let truncated = (value * factor).rounded(.towardZero) / factor
        return String(format: "%.4f", truncated)
    }

    private static func offsetString(for date: Date, in timeZone: TimeZone) -> String {
        let totalSeconds = timeZone.secondsFromGMT(for: date)
        let sign = totalSeconds >= 0 ? "+" : "-"
        let absoluteSeconds = abs(totalSeconds)
        let hours = absoluteSeconds / 3600
        let minutes = (absoluteSeconds % 3600) / 60
        return String(format: "%@%02d:%02d", sign, hours, minutes)
    }

    private static func julianDay(for date: Date) -> Double {
        (date.timeIntervalSince1970 / 86400) + 2440587.5
    }

    private static func normalizedDegrees(_ value: Double) -> Double {
        var adjusted = value.truncatingRemainder(dividingBy: 360)
        if adjusted < 0 {
            adjusted += 360
        }
        return adjusted
    }

    private static func normalizedHours(_ value: Double) -> Double {
        var adjusted = value.truncatingRemainder(dividingBy: 24)
        if adjusted < 0 {
            adjusted += 24
        }
        return adjusted
    }

    private static func degreesToRadians(_ value: Double) -> Double {
        value * .pi / 180
    }

    private static func radiansToDegrees(_ value: Double) -> Double {
        value * 180 / .pi
    }
}

enum MoonPhaseError: LocalizedError {
    case invalidRequest
    case invalidResponse
    case requestFailed(statusCode: Int)
    case phaseUnavailable

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            "Could not build the moon-phase request."
        case .invalidResponse:
            "Moon-phase service returned an unreadable response."
        case .requestFailed(let statusCode):
            "Moon-phase service returned HTTP \(statusCode)."
        case .phaseUnavailable:
            "Moon phase was unavailable for the selected site and date."
        }
    }
}

private struct METMoonResponse: Decodable {
    let properties: METMoonProperties
}

private struct METMoonProperties: Decodable {
    let moonphase: METMoonPhaseValue?
}

private struct METMoonPhaseValue: Decodable {
    let value: Double
}
