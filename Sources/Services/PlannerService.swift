import Foundation

struct PlannedTargetSuggestion: Identifiable {
    let id: String
    let object: DSOObject
    let score: Double
    let bestTime: Date
    let maxAltitudeDegrees: Double
    let darknessFraction: Double
    let moonSeparationDegrees: Double

    var summary: String {
        "Score \(Int(score.rounded())) • Alt \(Int(maxAltitudeDegrees.rounded()))° • Dark \(Int((darknessFraction * 100).rounded()))% • Moon \(Int(moonSeparationDegrees.rounded()))°"
    }
}

enum PlannerService {
    static func recommendTargets(for plan: NightPlan, objects: [DSOObject], limit: Int = 12) -> [PlannedTargetSuggestion] {
        guard let site = plan.site else { return [] }

        let interval = max(plan.endTime.timeIntervalSince(plan.startTime), 0)
        let stepCount = max(Int(interval / 1800), 1)
        let sampleTimes = (0...stepCount).map { index in
            plan.startTime.addingTimeInterval(Double(index) * interval / Double(stepCount))
        }

        let midpoint = plan.startTime.addingTimeInterval(interval / 2)
        let moonCoordinates = moonEquatorialCoordinates(for: midpoint)

        return objects.compactMap { object in
            let altitudes = sampleTimes.map { altitude(for: object, site: site, at: $0) }
            let maxAltitude = altitudes.max() ?? -90
            guard maxAltitude >= 20 else { return nil }

            let darknessSamples = sampleTimes.filter { sunAltitude(site: site, at: $0) <= -18.0 }
            let darknessFraction = Double(darknessSamples.count) / Double(sampleTimes.count)
            guard darknessFraction > 0 else { return nil }

            let bestIndex = altitudes.firstIndex(of: maxAltitude) ?? 0
            let bestTime = sampleTimes[bestIndex]
            let moonSeparation = angularSeparation(
                ra1Hours: object.rightAscensionHours,
                dec1Degrees: object.declinationDegrees,
                ra2Hours: moonCoordinates.raHours,
                dec2Degrees: moonCoordinates.decDegrees
            )

            let altitudeScore = normalized(value: maxAltitude, min: 20, max: 80)
            let moonScore = normalized(value: moonSeparation, min: 20, max: 160)
            let sizeScore = normalized(value: object.angularSizeArcMinutes, min: 5, max: 120)
            let brightnessScore = 1 - normalized(value: object.magnitude, min: 5, max: 11)

            let score = ((altitudeScore * 0.45) + (darknessFraction * 0.25) + (moonScore * 0.20) + (sizeScore * 0.05) + (brightnessScore * 0.05)) * 100

            return PlannedTargetSuggestion(
                id: object.catalogID,
                object: object,
                score: score,
                bestTime: bestTime,
                maxAltitudeDegrees: maxAltitude,
                darknessFraction: darknessFraction,
                moonSeparationDegrees: moonSeparation
            )
        }
        .sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return lhs.object.displayName < rhs.object.displayName
            }
            return lhs.score > rhs.score
        }
        .prefix(limit)
        .map { $0 }
    }

    @discardableResult
    static func applySuggestions(_ suggestions: [PlannedTargetSuggestion], to plan: NightPlan) -> [PlannedTarget] {
        let existingIDs = Set(plan.plannedTargets.compactMap { $0.object?.catalogID })
        var nextIndex = (plan.plannedTargets.map(\.orderIndex).max() ?? -1) + 1
        var addedTargets: [PlannedTarget] = []

        for suggestion in suggestions where !existingIDs.contains(suggestion.object.catalogID) {
            let target = PlannedTarget(
                orderIndex: nextIndex,
                plannerScore: suggestion.score,
                recommendedStart: suggestion.bestTime.addingTimeInterval(-1800),
                recommendedEnd: suggestion.bestTime.addingTimeInterval(1800),
                status: .planned,
                syncState: plan.hasLinkedLog ? .changed : .draft,
                object: suggestion.object,
                nightPlan: plan
            )
            plan.plannedTargets.append(target)
            addedTargets.append(target)
            nextIndex += 1
        }

        return addedTargets
    }

    private static func normalized(value: Double, min: Double, max: Double) -> Double {
        guard max > min else { return 0 }
        return Swift.max(0, Swift.min(1, (value - min) / (max - min)))
    }

    private static func altitude(for object: DSOObject, site: ObservingSite, at date: Date) -> Double {
        let localSiderealTimeHours = lstHours(for: date, longitudeDegrees: site.longitude)
        let hourAngleDegrees = normalizedDegrees((localSiderealTimeHours - object.rightAscensionHours) * 15)
        let latitudeRadians = site.latitude * .pi / 180
        let declinationRadians = object.declinationDegrees * .pi / 180
        let hourAngleRadians = hourAngleDegrees * .pi / 180

        let altitude = asin(
            sin(latitudeRadians) * sin(declinationRadians) +
            cos(latitudeRadians) * cos(declinationRadians) * cos(hourAngleRadians)
        )

        return altitude * 180 / .pi
    }

    private static func sunAltitude(site: ObservingSite, at date: Date) -> Double {
        let sun = sunEquatorialCoordinates(for: date)
        return altitude(raHours: sun.raHours, decDegrees: sun.decDegrees, site: site, at: date)
    }

    private static func altitude(raHours: Double, decDegrees: Double, site: ObservingSite, at date: Date) -> Double {
        let localSiderealTimeHours = lstHours(for: date, longitudeDegrees: site.longitude)
        let hourAngleDegrees = normalizedDegrees((localSiderealTimeHours - raHours) * 15)
        let latitudeRadians = site.latitude * .pi / 180
        let declinationRadians = decDegrees * .pi / 180
        let hourAngleRadians = hourAngleDegrees * .pi / 180

        let altitude = asin(
            sin(latitudeRadians) * sin(declinationRadians) +
            cos(latitudeRadians) * cos(declinationRadians) * cos(hourAngleRadians)
        )

        return altitude * 180 / .pi
    }

    private static func lstHours(for date: Date, longitudeDegrees: Double) -> Double {
        let daysSinceJ2000 = julianDay(for: date) - 2451545.0
        let gmst = 18.697374558 + (24.06570982441908 * daysSinceJ2000)
        return normalizedHours(gmst + longitudeDegrees / 15)
    }

    private static func julianDay(for date: Date) -> Double {
        (date.timeIntervalSince1970 / 86400) + 2440587.5
    }

    private static func sunEquatorialCoordinates(for date: Date) -> (raHours: Double, decDegrees: Double) {
        let n = julianDay(for: date) - 2451545.0
        let meanLongitude = normalizedDegrees(280.460 + 0.9856474 * n)
        let meanAnomaly = normalizedDegrees(357.528 + 0.9856003 * n)
        let eclipticLongitude = normalizedDegrees(
            meanLongitude +
            (1.915 * sin(meanAnomaly * .pi / 180)) +
            (0.020 * sin(2 * meanAnomaly * .pi / 180))
        )
        let obliquity = (23.439 - 0.0000004 * n) * .pi / 180
        let lambda = eclipticLongitude * .pi / 180

        let ra = atan2(cos(obliquity) * sin(lambda), cos(lambda)) * 180 / .pi
        let dec = asin(sin(obliquity) * sin(lambda)) * 180 / .pi
        return (normalizedHours(ra / 15), dec)
    }

    private static func moonEquatorialCoordinates(for date: Date) -> (raHours: Double, decDegrees: Double) {
        let n = julianDay(for: date) - 2451545.0
        let l0 = normalizedDegrees(218.316 + 13.176396 * n)
        let mMoon = normalizedDegrees(134.963 + 13.064993 * n)
        let mSun = normalizedDegrees(357.529 + 0.98560028 * n)
        let d = normalizedDegrees(297.850 + 12.190749 * n)
        let f = normalizedDegrees(93.272 + 13.229350 * n)

        let lambda = l0
            + 6.289 * sin(mMoon * .pi / 180)
            + 1.274 * sin((2 * d - mMoon) * .pi / 180)
            + 0.658 * sin((2 * d) * .pi / 180)
            + 0.214 * sin((2 * mMoon) * .pi / 180)
            - 0.186 * sin(mSun * .pi / 180)

        let beta = 5.128 * sin(f * .pi / 180)
        let epsilon = (23.439 - 0.0000004 * n) * .pi / 180
        let lambdaRadians = lambda * .pi / 180
        let betaRadians = beta * .pi / 180

        let ra = atan2(
            sin(lambdaRadians) * cos(epsilon) - tan(betaRadians) * sin(epsilon),
            cos(lambdaRadians)
        ) * 180 / .pi

        let dec = asin(
            sin(betaRadians) * cos(epsilon) +
            cos(betaRadians) * sin(epsilon) * sin(lambdaRadians)
        ) * 180 / .pi

        return (normalizedHours(ra / 15), dec)
    }

    private static func angularSeparation(
        ra1Hours: Double,
        dec1Degrees: Double,
        ra2Hours: Double,
        dec2Degrees: Double
    ) -> Double {
        let ra1 = ra1Hours * 15 * .pi / 180
        let ra2 = ra2Hours * 15 * .pi / 180
        let dec1 = dec1Degrees * .pi / 180
        let dec2 = dec2Degrees * .pi / 180

        let cosine = sin(dec1) * sin(dec2) + cos(dec1) * cos(dec2) * cos(ra1 - ra2)
        return acos(Swift.max(-1, Swift.min(1, cosine))) * 180 / .pi
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
}
