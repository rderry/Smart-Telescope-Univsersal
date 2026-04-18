import Foundation

struct ObservationDurationTier {
    let shortestMinutes: Int
    let medianMinutes: Int
    let presentationMinutes: Int
}

struct VesperaObservationTimingEstimate {
    let withoutDualBandFilter: ObservationDurationTier
    let withDualBandFilter: ObservationDurationTier
    let filterRecommendation: String
}

enum VesperaObservationTimingService {
    static func estimate(for object: DSOObject) -> VesperaObservationTimingEstimate {
        let baseShortest = baseShortestMinutes(for: object)
        let brightnessFactor = brightnessFactor(for: object.magnitude)

        let withoutFilter = ObservationDurationTier(
            shortestMinutes: roundedMinutes(Double(baseShortest) * brightnessFactor),
            medianMinutes: roundedMinutes(Double(baseShortest * 2) * brightnessFactor),
            presentationMinutes: roundedMinutes(Double(baseShortest * 4) * brightnessFactor)
        )

        let dualBandMultiplier = dualBandMultiplier(for: object)
        let withFilter = ObservationDurationTier(
            shortestMinutes: roundedMinutes(Double(withoutFilter.shortestMinutes) * dualBandMultiplier.shortest),
            medianMinutes: roundedMinutes(Double(withoutFilter.medianMinutes) * dualBandMultiplier.median),
            presentationMinutes: roundedMinutes(Double(withoutFilter.presentationMinutes) * dualBandMultiplier.presentation)
        )

        return VesperaObservationTimingEstimate(
            withoutDualBandFilter: withoutFilter,
            withDualBandFilter: withFilter,
            filterRecommendation: filterRecommendation(for: object)
        )
    }

    private static func baseShortestMinutes(for object: DSOObject) -> Int {
        switch object.objectType {
        case .openCluster, .globularCluster, .asterism, .starCloud:
            return 10
        case .planetaryNebula:
            return 12
        case .emissionNebula, .reflectionNebula, .darkNebula, .supernovaRemnant:
            return 15
        case .galaxy:
            return 20
        }
    }

    private static func brightnessFactor(for magnitude: Double) -> Double {
        switch magnitude {
        case ..<3:
            return 0.7
        case ..<5:
            return 0.85
        case ..<7:
            return 1.0
        case ..<9:
            return 1.2
        default:
            return 1.4
        }
    }

    private static func dualBandMultiplier(for object: DSOObject) -> (shortest: Double, median: Double, presentation: Double) {
        switch object.objectType {
        case .emissionNebula, .darkNebula, .planetaryNebula, .supernovaRemnant:
            return (1.0, 1.5, 2.0)
        case .openCluster, .globularCluster:
            return (1.1, 1.35, 1.7)
        case .reflectionNebula:
            return (1.15, 1.5, 2.0)
        case .galaxy, .asterism, .starCloud:
            return (1.2, 1.5, 2.0)
        }
    }

    private static func roundedMinutes(_ minutes: Double) -> Int {
        max(5, Int((minutes / 5).rounded() * 5))
    }

    private static func filterRecommendation(for object: DSOObject) -> String {
        switch object.objectType {
        case .emissionNebula, .darkNebula, .planetaryNebula, .supernovaRemnant:
            return "Dual Band filter is strongly recommended for this object type."
        case .openCluster, .globularCluster:
            return "Dual Band filter can improve star sharpness, but gains are usually more modest."
        case .reflectionNebula:
            return "Dual Band filter may help selectively, but broad-spectrum detail can still favor no filter."
        case .galaxy, .asterism, .starCloud:
            return "Dual Band filter is usually less beneficial here; no filter is often the better baseline."
        }
    }
}
