import Foundation
import SwiftData

@MainActor
enum BootstrapService {
    static func bootstrapIfNeeded(context: ModelContext) throws {
        try CatalogService.bootstrapCatalogIfNeeded(context: context)
        try TransientFeedService.bootstrapFeedIfNeeded(context: context)
        try bootstrapProfilesIfNeeded(context: context)
    }

    private static func bootstrapProfilesIfNeeded(context: ModelContext) throws {
        let siteCount = try context.fetchCount(FetchDescriptor<ObservingSite>())
        if siteCount == 0 {
            context.insert(
                ObservingSite(
                    name: "Home Backyard",
                    latitude: 39.7392,
                    longitude: -104.9903,
                    elevationMeters: 1609,
                    bortleClass: 6,
                    notes: "Default urban test site."
                )
            )
            context.insert(
                ObservingSite(
                    name: "Mountain Dark Site",
                    latitude: 38.9972,
                    longitude: -105.5478,
                    elevationMeters: 2800,
                    bortleClass: 2,
                    notes: "Primary dark-sky destination."
                )
            )
        }

        try EquipmentCatalogService.bootstrapIfNeeded(context: context)
        try context.save()
    }
}
