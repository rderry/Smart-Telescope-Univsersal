import Foundation
import SwiftData

struct DatabaseRefreshReport {
    let warnings: [String]

    static let empty = DatabaseRefreshReport(warnings: [])
}

struct DatabaseRefreshSnapshot {
    let catalogLastSuccess: Date?
    let transientLastSuccess: Date?

    var latestSuccessfulRefresh: Date? {
        [catalogLastSuccess, transientLastSuccess]
            .compactMap { $0 }
            .max()
    }
}

struct DatabaseRefreshSchedule {
    let refreshInterval: TimeInterval

    func isDue(lastSuccess: Date?, now: Date = .now) -> Bool {
        guard let lastSuccess else { return true }
        return now.timeIntervalSince(lastSuccess) >= refreshInterval
    }
}

@MainActor
enum DatabaseRefreshService {
    static let weeklySchedule = DatabaseRefreshSchedule(refreshInterval: 7 * 24 * 60 * 60)

    private static let catalogLastSuccessKey = "database_refresh.catalog_last_success"
    private static let transientLastSuccessKey = "database_refresh.transient_last_success"

    static func bootstrapAndRefreshIfNeeded(context: ModelContext, now: Date = .now) async throws -> DatabaseRefreshReport {
        try BootstrapService.bootstrapIfNeeded(context: context)
        return await refreshAllNow(context: context, now: now)
    }

    static func refreshIfNeeded(context: ModelContext, now: Date = .now) async -> DatabaseRefreshReport {
        let defaults = UserDefaults.standard
        var warnings: [String] = []

        if weeklySchedule.isDue(lastSuccess: defaults.object(forKey: catalogLastSuccessKey) as? Date, now: now) {
            await performCatalogRefresh(context: context, now: now, warnings: &warnings, defaults: defaults)
        }

        if weeklySchedule.isDue(lastSuccess: defaults.object(forKey: transientLastSuccessKey) as? Date, now: now) {
            await performTransientRefresh(context: context, now: now, warnings: &warnings, defaults: defaults)
        }

        return DatabaseRefreshReport(warnings: warnings)
    }

    static func refreshAllNow(context: ModelContext, now: Date = .now) async -> DatabaseRefreshReport {
        let defaults = UserDefaults.standard
        var warnings: [String] = []

        await performCatalogRefresh(context: context, now: now, warnings: &warnings, defaults: defaults)
        await performTransientRefresh(context: context, now: now, warnings: &warnings, defaults: defaults)
        performEquipmentRefresh(context: context, now: now, warnings: &warnings)

        return DatabaseRefreshReport(warnings: warnings)
    }

    static func refreshSnapshot(defaults: UserDefaults = .standard) -> DatabaseRefreshSnapshot {
        DatabaseRefreshSnapshot(
            catalogLastSuccess: defaults.object(forKey: catalogLastSuccessKey) as? Date,
            transientLastSuccess: defaults.object(forKey: transientLastSuccessKey) as? Date
        )
    }

    static func lastSuccessfulRefreshDate(defaults: UserDefaults = .standard) -> Date? {
        refreshSnapshot(defaults: defaults).latestSuccessfulRefresh
    }

    static func preferredReferenceSite(context: ModelContext) throws -> TransientFeedReferenceSite {
        let sites = try context.fetch(FetchDescriptor<ObservingSite>())

        if let preferredSite = LocationPreferenceStore.preferredSite(from: sites) {
            return TransientFeedReferenceSite(
                name: preferredSite.name,
                latitude: preferredSite.latitude,
                longitude: preferredSite.longitude,
                elevationMeters: preferredSite.elevationMeters
            )
        }

        if let bestSite = sites.min(by: referenceSiteSort) {
            return TransientFeedReferenceSite(
                name: bestSite.name,
                latitude: bestSite.latitude,
                longitude: bestSite.longitude,
                elevationMeters: bestSite.elevationMeters
            )
        }

        return TransientFeedReferenceSite(
            name: "Mountain Dark Site",
            latitude: 38.9972,
            longitude: -105.5478,
            elevationMeters: 2_800
        )
    }

    private static func referenceSiteSort(lhs: ObservingSite, rhs: ObservingSite) -> Bool {
        if lhs.normalizedBortleClass == rhs.normalizedBortleClass {
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }

        return lhs.normalizedBortleClass < rhs.normalizedBortleClass
    }

    private static func performCatalogRefresh(
        context: ModelContext,
        now: Date,
        warnings: inout [String],
        defaults: UserDefaults
    ) async {
        do {
            try await CatalogService.refreshCatalogFromInternet(context: context)
            defaults.set(now, forKey: catalogLastSuccessKey)
        } catch {
            warnings.append(
                AppIssueFormatter.remoteServiceWarning(
                    service: "The live catalog refresh",
                    error: error
                )
            )
        }
    }

    private static func performTransientRefresh(
        context: ModelContext,
        now: Date,
        warnings: inout [String],
        defaults: UserDefaults
    ) async {
        do {
            let referenceSite = try preferredReferenceSite(context: context)
            try await TransientFeedService.refreshFeedFromInternet(context: context, referenceSite: referenceSite, now: now)
            defaults.set(now, forKey: transientLastSuccessKey)
        } catch {
            warnings.append(
                AppIssueFormatter.remoteServiceWarning(
                    service: "The live transient refresh",
                    error: error
                )
            )
        }
    }

    private static func performEquipmentRefresh(
        context: ModelContext,
        now: Date,
        warnings: inout [String]
    ) {
        do {
            try EquipmentCatalogService.refreshBundledDatabase(
                context: context,
                groups: Set(EquipmentCatalogGroup.allCases),
                now: now
            )
        } catch {
            warnings.append(
                AppIssueFormatter.remoteServiceWarning(
                    service: "The equipment database refresh",
                    error: error
                )
            )
        }
    }
}
