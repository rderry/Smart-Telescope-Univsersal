import Foundation

struct SunBelowHorizonEvents {
    let start: Date?
    let end: Date?

    static let unavailable = SunBelowHorizonEvents(start: nil, end: nil)
}

enum SolarHorizonService {
    static func sunBelowHorizonEvents(for site: ObservingSite, on date: Date) -> SunBelowHorizonEvents {
        let timeZone = TimeZone(identifier: site.timeZoneIdentifier) ?? .current
        var localCalendar = Calendar(identifier: .gregorian)
        localCalendar.timeZone = timeZone

        let localDayStart = localCalendar.dateInterval(of: .day, for: date)?.start ?? date
        let nextLocalDayStart = localCalendar.date(byAdding: .day, value: 1, to: localDayStart) ?? date

        return SunBelowHorizonEvents(
            start: solarHorizonEvent(
                isMorningEvent: false,
                site: site,
                date: localDayStart,
                timeZone: timeZone
            ),
            end: solarHorizonEvent(
                isMorningEvent: true,
                site: site,
                date: nextLocalDayStart,
                timeZone: timeZone
            )
        )
    }

    private static func solarHorizonEvent(
        isMorningEvent: Bool,
        site: ObservingSite,
        date: Date,
        timeZone: TimeZone
    ) -> Date? {
        var localCalendar = Calendar(identifier: .gregorian)
        localCalendar.timeZone = timeZone

        let dayOfYear = localCalendar.ordinality(of: .day, in: .year, for: date) ?? 1
        let longitudeHour = site.longitude / 15
        let approximateTime = Double(dayOfYear) + ((isMorningEvent ? 6 : 18) - longitudeHour) / 24

        let meanAnomaly = (0.9856 * approximateTime) - 3.289
        let trueLongitude = normalizedDegrees(
            meanAnomaly +
            (1.916 * sin(degreesToRadians(meanAnomaly))) +
            (0.020 * sin(2 * degreesToRadians(meanAnomaly))) +
            282.634
        )

        var rightAscension = radiansToDegrees(atan(0.91764 * tan(degreesToRadians(trueLongitude))))
        rightAscension = normalizedDegrees(rightAscension)

        let trueLongitudeQuadrant = floor(trueLongitude / 90) * 90
        let rightAscensionQuadrant = floor(rightAscension / 90) * 90
        rightAscension += trueLongitudeQuadrant - rightAscensionQuadrant
        rightAscension /= 15

        let sinDeclination = 0.39782 * sin(degreesToRadians(trueLongitude))
        let cosDeclination = cos(asin(sinDeclination))
        let cosLocalHourAngle =
            (cos(degreesToRadians(90.0)) - (sinDeclination * sin(degreesToRadians(site.latitude)))) /
            (cosDeclination * cos(degreesToRadians(site.latitude)))

        if cosLocalHourAngle > 1 || cosLocalHourAngle < -1 {
            return nil
        }

        var localHourAngle = isMorningEvent
            ? 360 - radiansToDegrees(acos(cosLocalHourAngle))
            : radiansToDegrees(acos(cosLocalHourAngle))
        localHourAngle /= 15

        let localMeanTime = localHourAngle + rightAscension - (0.06571 * approximateTime) - 6.622
        let universalTime = normalizedHours(localMeanTime - longitudeHour)

        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0) ?? .current
        let components = localCalendar.dateComponents([.year, .month, .day], from: date)

        guard let midnightUTC = utcCalendar.date(from: DateComponents(
            timeZone: TimeZone(secondsFromGMT: 0),
            year: components.year,
            month: components.month,
            day: components.day,
            hour: 0,
            minute: 0,
            second: 0
        )) else {
            return nil
        }

        return adjustedEventDate(
            midnightUTC.addingTimeInterval(universalTime * 3600),
            toMatchLocalDayFor: date,
            calendar: localCalendar
        )
    }

    private static func adjustedEventDate(
        _ eventDate: Date,
        toMatchLocalDayFor date: Date,
        calendar: Calendar
    ) -> Date {
        guard let targetDayStart = calendar.dateInterval(of: .day, for: date)?.start else {
            return eventDate
        }

        var adjustedDate = eventDate
        for _ in 0 ..< 2 {
            guard let eventDayStart = calendar.dateInterval(of: .day, for: adjustedDate)?.start else {
                return adjustedDate
            }

            if eventDayStart < targetDayStart {
                adjustedDate = adjustedDate.addingTimeInterval(24 * 60 * 60)
            } else if eventDayStart > targetDayStart {
                adjustedDate = adjustedDate.addingTimeInterval(-24 * 60 * 60)
            } else {
                return adjustedDate
            }
        }

        return adjustedDate
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
