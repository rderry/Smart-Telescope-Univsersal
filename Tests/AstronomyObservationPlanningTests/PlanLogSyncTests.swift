import SwiftData
import XCTest
@testable import AstronomyObservationPlanning

@MainActor
final class PlanLogSyncTests: XCTestCase {
    private var container: ModelContainer!
    private var context: ModelContext!

    override func setUp() async throws {
        try await super.setUp()
        container = ModelContainerFactory.makeInMemoryContainer()
        context = ModelContext(container)
    }

    func testBootstrapSeedsAdditionalCatalogFamiliesAndTransients() throws {
        try CatalogService.bootstrapCatalogIfNeeded(context: context)
        try TransientFeedService.bootstrapFeedIfNeeded(context: context)

        let objects = try context.fetch(FetchDescriptor<DSOObject>())
        let transients = try context.fetch(FetchDescriptor<TransientFeedItem>())

        XCTAssertTrue(objects.contains(where: { $0.catalogFamily == .caldwell }))
        XCTAssertTrue(objects.contains(where: { $0.catalogFamily == .ic }))
        XCTAssertTrue(objects.contains(where: { $0.catalogFamily == .sharpless2 }))
        XCTAssertTrue(objects.contains(where: { $0.catalogFamily == .lbn }))
        XCTAssertTrue(transients.contains(where: { $0.transientType == .comet }))
        XCTAssertTrue(transients.contains(where: { $0.transientType == .asteroid }))
        XCTAssertTrue(objects.allSatisfy { $0.magnitude < MagnitudeVisibilityPolicy.maximumIncludedMagnitude })
        XCTAssertTrue(transients.allSatisfy { MagnitudeVisibilityPolicy.allows(optionalMagnitude: $0.magnitude) })
    }

    func testSkyCoordinateServiceReturnsDirectionAndAltitude() {
        let object = DSOObject(
            catalogID: "M45",
            commonName: "Pleiades",
            primaryDesignation: "Melotte 22",
            catalogFamily: .messier,
            objectType: .openCluster,
            constellation: "Taurus",
            rightAscensionHours: 3.792,
            declinationDegrees: 24.117,
            magnitude: 1.6,
            angularSizeArcMinutes: 110
        )
        let site = ObservingSite(name: "Test Site", latitude: 39.7392, longitude: -104.9903)
        let date = ISO8601DateFormatter().date(from: "2026-01-12T04:00:00Z") ?? .now

        let position = SkyCoordinateService.localSkyPosition(for: object, site: site, at: date)

        XCTAssertTrue(position.altitudeDegrees >= -90 && position.altitudeDegrees <= 90)
        XCTAssertTrue(position.azimuthDegrees >= 0 && position.azimuthDegrees <= 360)
        XCTAssertFalse(position.magneticCardinalDirection.isEmpty)
    }

    func testVesperaObservationTimingServiceReturnsBothFilterProfiles() {
        let object = DSOObject(
            catalogID: "M42",
            commonName: "Orion Nebula",
            primaryDesignation: "NGC 1976",
            catalogFamily: .messier,
            objectType: .emissionNebula,
            constellation: "Orion",
            rightAscensionHours: 5.591,
            declinationDegrees: -5.45,
            magnitude: 4.0,
            angularSizeArcMinutes: 65
        )

        let estimate = VesperaObservationTimingService.estimate(for: object)

        XCTAssertGreaterThanOrEqual(estimate.withoutDualBandFilter.shortestMinutes, 5)
        XCTAssertGreaterThanOrEqual(estimate.withDualBandFilter.presentationMinutes, estimate.withoutDualBandFilter.presentationMinutes)
        XCTAssertFalse(estimate.filterRecommendation.isEmpty)
    }

    func testConfirmNightPlanCreatesLinkedNightLogAndEntries() throws {
        let object = DSOObject(
            catalogID: "M42",
            commonName: "Orion Nebula",
            primaryDesignation: "NGC 1976",
            catalogFamily: .messier,
            objectType: .emissionNebula,
            constellation: "Orion",
            rightAscensionHours: 5.591,
            declinationDegrees: -5.45,
            magnitude: 4,
            angularSizeArcMinutes: 65
        )
        let site = ObservingSite(name: "Test Site", latitude: 40, longitude: -105)
        let equipment = EquipmentProfile(name: "Scope", apertureMillimeters: 200, focalLengthMillimeters: 1200)
        let plan = NightPlan(
            title: "Winter session",
            observingDate: .now,
            startTime: .now,
            endTime: .now.addingTimeInterval(7200),
            site: site,
            equipment: equipment
        )
        let target = PlannedTarget(orderIndex: 0, plannerScore: 92, object: object, nightPlan: plan)
        plan.plannedTargets.append(target)

        context.insert(object)
        context.insert(site)
        context.insert(equipment)
        context.insert(plan)
        context.insert(target)

        let log = try PlanConfirmationService.confirmNightPlan(plan, context: context)

        XCTAssertTrue(plan.isConfirmed)
        XCTAssertEqual(log.sourcePlanId, plan.id)
        XCTAssertEqual(log.observationEntries.count, 1)
        XCTAssertEqual(log.observationEntries.first?.sourcePlannedTargetId, target.id)
        XCTAssertEqual(log.observationEntries.first?.status, .planned)
    }

    func testConfirmCampaignCreatesChildNightLogs() throws {
        let object = DSOObject(
            catalogID: "M13",
            commonName: "Great Hercules Cluster",
            primaryDesignation: "NGC 6205",
            catalogFamily: .messier,
            objectType: .globularCluster,
            constellation: "Hercules",
            rightAscensionHours: 16.695,
            declinationDegrees: 36.467,
            magnitude: 5.8,
            angularSizeArcMinutes: 20
        )
        let campaign = CampaignPlan(title: "Summer run", startDate: .now, endDate: .now.addingTimeInterval(86400))
        let firstNight = NightPlan(
            title: "Night 1",
            observingDate: .now,
            startTime: .now,
            endTime: .now.addingTimeInterval(7200),
            campaignPlan: campaign
        )
        let secondNight = NightPlan(
            title: "Night 2",
            observingDate: .now.addingTimeInterval(86400),
            startTime: .now.addingTimeInterval(86400),
            endTime: .now.addingTimeInterval(93600),
            campaignPlan: campaign
        )
        firstNight.plannedTargets.append(PlannedTarget(orderIndex: 0, plannerScore: 88, object: object, nightPlan: firstNight))
        secondNight.plannedTargets.append(PlannedTarget(orderIndex: 0, plannerScore: 85, object: object, nightPlan: secondNight))
        campaign.nightPlans.append(contentsOf: [firstNight, secondNight])

        context.insert(object)
        context.insert(campaign)
        context.insert(firstNight)
        context.insert(secondNight)
        firstNight.plannedTargets.forEach(context.insert)
        secondNight.plannedTargets.forEach(context.insert)

        let campaignLog = try PlanConfirmationService.confirmCampaign(campaign, context: context)

        XCTAssertTrue(campaign.isConfirmed)
        XCTAssertEqual(campaignLog.sourceCampaignPlanId, campaign.id)
        XCTAssertEqual(campaignLog.nightLogs.count, 2)
        XCTAssertEqual(Set(campaignLog.nightLogs.compactMap(\.sourcePlanId)), Set([firstNight.id, secondNight.id]))
    }

    func testSharedCampaignTargetSyncsObservationTimesAndImageCountsIntoLogs() throws {
        let object = DSOObject(
            catalogID: "M51",
            commonName: "Whirlpool Galaxy",
            primaryDesignation: "NGC 5194",
            catalogFamily: .messier,
            objectType: .galaxy,
            constellation: "Canes Venatici",
            rightAscensionHours: 13.497,
            declinationDegrees: 47.195,
            magnitude: 8.4,
            angularSizeArcMinutes: 11.2
        )
        let firstNightStart = Date(timeIntervalSince1970: 1_775_404_800)
        let firstNightEnd = firstNightStart.addingTimeInterval(5_400)
        let secondNightStart = firstNightStart.addingTimeInterval(86_400)
        let secondNightEnd = secondNightStart.addingTimeInterval(7_200)

        let campaign = CampaignPlan(
            title: "Whirlpool Run",
            startDate: firstNightStart,
            endDate: secondNightStart,
            sharedTarget: object
        )
        let firstNight = NightPlan(
            title: "Night 1",
            observingDate: firstNightStart,
            startTime: firstNightStart,
            endTime: firstNightEnd,
            campaignPlan: campaign
        )
        let secondNight = NightPlan(
            title: "Night 2",
            observingDate: secondNightStart,
            startTime: secondNightStart,
            endTime: secondNightEnd,
            campaignPlan: campaign
        )

        let firstTarget = PlannedTarget(
            orderIndex: 0,
            plannerScore: 90,
            observationStart: firstNightStart,
            observationEnd: firstNightEnd,
            capturedImageCount: 24,
            object: object,
            nightPlan: firstNight
        )
        let secondTarget = PlannedTarget(
            orderIndex: 0,
            plannerScore: 90,
            observationStart: secondNightStart,
            observationEnd: secondNightEnd,
            capturedImageCount: 36,
            object: object,
            nightPlan: secondNight
        )

        firstNight.plannedTargets.append(firstTarget)
        secondNight.plannedTargets.append(secondTarget)
        campaign.nightPlans.append(contentsOf: [firstNight, secondNight])

        context.insert(object)
        context.insert(campaign)
        context.insert(firstNight)
        context.insert(secondNight)
        context.insert(firstTarget)
        context.insert(secondTarget)

        let campaignLog = try PlanConfirmationService.confirmCampaign(campaign, context: context)
        XCTAssertEqual(campaignLog.nightLogs.count, 2)

        let firstEntry = campaignLog.nightLogs
            .first(where: { $0.sourcePlanId == firstNight.id })?
            .observationEntries
            .first
        let secondEntry = campaignLog.nightLogs
            .first(where: { $0.sourcePlanId == secondNight.id })?
            .observationEntries
            .first

        XCTAssertEqual(firstEntry?.capturedImageCount, 24)
        XCTAssertEqual(firstEntry?.observationStart, firstNightStart)
        XCTAssertEqual(firstEntry?.observationEnd, firstNightEnd)
        XCTAssertEqual(secondEntry?.capturedImageCount, 36)
        XCTAssertEqual(secondEntry?.observationStart, secondNightStart)
        XCTAssertEqual(secondEntry?.observationEnd, secondNightEnd)
    }

    func testSharedObservationUsesTargetNameForNightLogTitle() throws {
        let object = DSOObject(
            catalogID: "M27",
            commonName: "Dumbbell Nebula",
            primaryDesignation: "NGC 6853",
            catalogFamily: .messier,
            objectType: .planetaryNebula,
            constellation: "Vulpecula",
            rightAscensionHours: 19.993,
            declinationDegrees: 22.721,
            magnitude: 7.5,
            angularSizeArcMinutes: 8
        )
        let date = Date(timeIntervalSince1970: 1_775_404_800)
        let campaign = CampaignPlan(
            title: "Summer Observation",
            startDate: date,
            endDate: date,
            sharedTarget: object
        )
        let night = NightPlan(
            title: "Dumbbell Nebula • \(date.formatted(date: .abbreviated, time: .omitted))",
            observingDate: date,
            startTime: date,
            endTime: date.addingTimeInterval(3600),
            campaignPlan: campaign
        )
        let target = PlannedTarget(
            orderIndex: 0,
            plannerScore: 70,
            observationStart: date,
            observationEnd: date.addingTimeInterval(3600),
            object: object,
            nightPlan: night
        )

        night.plannedTargets.append(target)
        campaign.nightPlans.append(night)

        context.insert(object)
        context.insert(campaign)
        context.insert(night)
        context.insert(target)

        let log = try PlanConfirmationService.confirmNightPlan(night, context: context)

        XCTAssertTrue(log.title.contains("Dumbbell Nebula"))
        XCTAssertFalse(log.title.contains("Summer Observation"))
    }

    func testObservationHistoryServiceReturnsOnlyLoggedEntriesForTarget() throws {
        let target = DSOObject(
            catalogID: "M51",
            commonName: "Whirlpool Galaxy",
            primaryDesignation: "NGC 5194",
            catalogFamily: .messier,
            objectType: .galaxy,
            constellation: "Canes Venatici",
            rightAscensionHours: 13.497,
            declinationDegrees: 47.195,
            magnitude: 8.4,
            angularSizeArcMinutes: 11.2
        )
        let otherObject = DSOObject(
            catalogID: "M82",
            commonName: "Cigar Galaxy",
            primaryDesignation: "NGC 3034",
            catalogFamily: .messier,
            objectType: .galaxy,
            constellation: "Ursa Major",
            rightAscensionHours: 9.934,
            declinationDegrees: 69.679,
            magnitude: 8.4,
            angularSizeArcMinutes: 9.3
        )
        let site = ObservingSite(name: "Test Site", latitude: 40, longitude: -105)
        let log = NightLog(
            title: "Whirlpool Galaxy • Apr 7, 2026",
            observingDate: Date(timeIntervalSince1970: 1_775_404_800),
            actualStart: Date(timeIntervalSince1970: 1_775_404_800),
            actualEnd: Date(timeIntervalSince1970: 1_775_408_400),
            site: site
        )
        let matchingEntry = ObservationEntry(
            orderIndex: 0,
            loggedAt: Date(timeIntervalSince1970: 1_775_404_900),
            observationStart: Date(timeIntervalSince1970: 1_775_404_800),
            observationEnd: Date(timeIntervalSince1970: 1_775_408_400),
            capturedImageCount: 42,
            notes: "Strong detail in the spiral arms.",
            status: .observed,
            object: target,
            nightLog: log
        )
        let otherEntry = ObservationEntry(
            orderIndex: 1,
            loggedAt: Date(timeIntervalSince1970: 1_775_405_000),
            observationStart: Date(timeIntervalSince1970: 1_775_405_000),
            observationEnd: Date(timeIntervalSince1970: 1_775_408_000),
            capturedImageCount: 18,
            notes: "Should not be included.",
            status: .observed,
            object: otherObject,
            nightLog: log
        )

        log.observationEntries.append(contentsOf: [matchingEntry, otherEntry])

        context.insert(target)
        context.insert(otherObject)
        context.insert(site)
        context.insert(log)
        context.insert(matchingEntry)
        context.insert(otherEntry)

        let records = try ObservationHistoryService.fetchLoggedObservations(for: target, context: context)

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.logTitle, log.title)
        XCTAssertEqual(records.first?.capturedImageCount, 42)
        XCTAssertEqual(records.first?.status, .observed)
    }

    func testSyncAddsAndCancelsEntriesWhenPlanChanges() throws {
        let object1 = DSOObject(
            catalogID: "M27",
            commonName: "Dumbbell Nebula",
            primaryDesignation: "NGC 6853",
            catalogFamily: .messier,
            objectType: .planetaryNebula,
            constellation: "Vulpecula",
            rightAscensionHours: 19.993,
            declinationDegrees: 22.721,
            magnitude: 7.5,
            angularSizeArcMinutes: 8
        )
        let object2 = DSOObject(
            catalogID: "M57",
            commonName: "Ring Nebula",
            primaryDesignation: "NGC 6720",
            catalogFamily: .messier,
            objectType: .planetaryNebula,
            constellation: "Lyra",
            rightAscensionHours: 18.893,
            declinationDegrees: 33.03,
            magnitude: 8.8,
            angularSizeArcMinutes: 1.4
        )
        let plan = NightPlan(
            title: "Planetaries",
            observingDate: .now,
            startTime: .now,
            endTime: .now.addingTimeInterval(7200)
        )
        let target1 = PlannedTarget(orderIndex: 0, plannerScore: 80, object: object1, nightPlan: plan)
        plan.plannedTargets.append(target1)
        context.insert(object1)
        context.insert(object2)
        context.insert(plan)
        context.insert(target1)

        let log = try PlanConfirmationService.confirmNightPlan(plan, context: context)
        XCTAssertEqual(log.observationEntries.count, 1)

        let target2 = PlannedTarget(orderIndex: 1, plannerScore: 78, object: object2, nightPlan: plan)
        context.insert(target2)
        plan.plannedTargets.append(target2)
        try PlanLogSyncService.syncNightPlanToLinkedLog(plan, context: context)

        XCTAssertEqual(log.observationEntries.count, 2)
        XCTAssertEqual(log.orderedEntries.last?.object?.catalogID, "M57")

        plan.plannedTargets.removeAll(where: { $0.id == target1.id })
        context.delete(target1)
        try PlanLogSyncService.syncNightPlanToLinkedLog(plan, context: context)

        let cancelledEntry = log.observationEntries.first(where: { $0.sourcePlannedTargetId == target1.id })
        XCTAssertEqual(cancelledEntry?.status, .cancelled)
        XCTAssertTrue(cancelledEntry?.isRemoved ?? false)
    }

    func testObservationEntryStatusSyncsBackToPlanSummary() throws {
        let object = DSOObject(
            catalogID: "M51",
            commonName: "Whirlpool Galaxy",
            primaryDesignation: "NGC 5194",
            catalogFamily: .messier,
            objectType: .galaxy,
            constellation: "Canes Venatici",
            rightAscensionHours: 13.497,
            declinationDegrees: 47.195,
            magnitude: 8.4,
            angularSizeArcMinutes: 11.2
        )
        let plan = NightPlan(
            title: "Galaxy night",
            observingDate: .now,
            startTime: .now,
            endTime: .now.addingTimeInterval(7200)
        )
        let target = PlannedTarget(orderIndex: 0, plannerScore: 82, object: object, nightPlan: plan)
        plan.plannedTargets.append(target)
        context.insert(object)
        context.insert(plan)
        context.insert(target)

        let log = try PlanConfirmationService.confirmNightPlan(plan, context: context)
        guard let entry = log.observationEntries.first else {
            XCTFail("Missing observation entry")
            return
        }

        entry.status = .observed
        try PlanLogSyncService.syncObservationEntryBackToPlan(entry, context: context)
        XCTAssertEqual(target.status, .observed)

        entry.status = .skipped
        try PlanLogSyncService.syncObservationEntryBackToPlan(entry, context: context)
        XCTAssertEqual(target.status, .skipped)
    }
}
