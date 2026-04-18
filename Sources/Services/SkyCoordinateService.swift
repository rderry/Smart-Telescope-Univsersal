import Foundation

struct LocalSkyPosition {
    let altitudeDegrees: Double
    let azimuthDegrees: Double
    let magneticCardinalDirection: String
}

enum SkyCoordinateService {
    static func localSkyPosition(for object: DSOObject, site: ObservingSite, at date: Date) -> LocalSkyPosition {
        localSkyPosition(
            rightAscensionHours: object.rightAscensionHours,
            declinationDegrees: object.declinationDegrees,
            site: site,
            at: date
        )
    }

    static func localSkyPosition(
        rightAscensionHours: Double,
        declinationDegrees: Double,
        site: ObservingSite,
        at date: Date
    ) -> LocalSkyPosition {
        let localSiderealTimeHours = lstHours(for: date, longitudeDegrees: site.longitude)
        let hourAngleDegrees = normalizedDegrees((localSiderealTimeHours - rightAscensionHours) * 15)
        let latitudeRadians = site.latitude * .pi / 180
        let declinationRadians = declinationDegrees * .pi / 180
        let hourAngleRadians = hourAngleDegrees * .pi / 180

        let altitudeRadians = asin(
            sin(latitudeRadians) * sin(declinationRadians) +
            cos(latitudeRadians) * cos(declinationRadians) * cos(hourAngleRadians)
        )

        let azimuthRadians = atan2(
            sin(hourAngleRadians),
            cos(hourAngleRadians) * sin(latitudeRadians) - tan(declinationRadians) * cos(latitudeRadians)
        )

        let altitudeDegrees = altitudeRadians * 180 / .pi
        let azimuthDegrees = normalizedAzimuthDegrees((azimuthRadians * 180 / .pi) + 180)

        return LocalSkyPosition(
            altitudeDegrees: altitudeDegrees,
            azimuthDegrees: azimuthDegrees,
            magneticCardinalDirection: magneticDirectionLabel(for: azimuthDegrees)
        )
    }

    private static func lstHours(for date: Date, longitudeDegrees: Double) -> Double {
        let daysSinceJ2000 = julianDay(for: date) - 2451545.0
        let gmst = 18.697374558 + (24.06570982441908 * daysSinceJ2000)
        return normalizedHours(gmst + longitudeDegrees / 15)
    }

    private static func julianDay(for date: Date) -> Double {
        (date.timeIntervalSince1970 / 86400) + 2440587.5
    }

    private static func normalizedDegrees(_ value: Double) -> Double {
        var adjusted = value.truncatingRemainder(dividingBy: 360)
        if adjusted < -180 { adjusted += 360 }
        if adjusted > 180 { adjusted -= 360 }
        return adjusted
    }

    private static func normalizedHours(_ value: Double) -> Double {
        var adjusted = value.truncatingRemainder(dividingBy: 24)
        if adjusted < 0 { adjusted += 24 }
        return adjusted
    }

    private static func normalizedAzimuthDegrees(_ value: Double) -> Double {
        var adjusted = value.truncatingRemainder(dividingBy: 360)
        if adjusted < 0 { adjusted += 360 }
        return adjusted
    }

    private static func magneticDirectionLabel(for azimuthDegrees: Double) -> String {
        let headings = [
            "N", "NNE", "NE", "ENE",
            "E", "ESE", "SE", "SSE",
            "S", "SSW", "SW", "WSW",
            "W", "WNW", "NW", "NNW"
        ]
        let index = Int((azimuthDegrees + 11.25) / 22.5) % headings.count
        return headings[index]
    }
}
