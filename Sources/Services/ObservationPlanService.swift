import Foundation
import SwiftData

private enum ObservationPlanServiceError: LocalizedError {
    case missingTargetObject

    var errorDescription: String? {
        switch self {
        case .missingTargetObject:
            return "Select a catalog object before sending a target to the observation log."
        }
    }
}

enum ObservationPlanService {
    static func savePlan(_ plan: NightPlan, context: ModelContext) throws {
        if plan.modelContext == nil {
            context.insert(plan)
        }

        try context.save()
    }

    static func markTargetRemovedFromObservationLog(_ target: PlannedTarget, context: ModelContext) throws {
        guard let entry = try fetchLinkedObservationEntry(for: target, context: context) else { return }

        entry.isRemoved = true
        entry.status = .cancelled
        entry.syncState = .removed
        try context.save()
    }

    @discardableResult
    static func sendTargetToObservationLog(_ target: PlannedTarget, from plan: NightPlan, context: ModelContext) throws -> NightLog {
        guard let object = target.object else {
            throw ObservationPlanServiceError.missingTargetObject
        }

        let log = try ensureNightLog(for: plan, context: context)
        let entry = log.observationEntries.first(where: { $0.sourcePlannedTargetId == target.id }) ?? ObservationEntry(
            orderIndex: target.orderIndex,
            loggedAt: Date(),
            observationStart: target.observationStart ?? target.recommendedStart,
            observationEnd: target.observationEnd ?? target.recommendedEnd,
            capturedImageCount: target.capturedImageCount,
            notes: target.notes,
            status: observationStatus(for: target.status),
            syncState: .synced,
            sourcePlannedTargetId: target.id,
            object: object,
            nightLog: log
        )

        if entry.modelContext == nil {
            context.insert(entry)
        }

        entry.nightLog = log
        entry.orderIndex = target.orderIndex
        entry.loggedAt = entry.loggedAt ?? Date()
        entry.observationStart = target.observationStart ?? target.recommendedStart ?? log.actualStart
        entry.observationEnd = target.observationEnd ?? target.recommendedEnd ?? log.actualEnd
        entry.capturedImageCount = target.capturedImageCount
        entry.object = object
        entry.sourcePlannedTargetId = target.id
        entry.isRemoved = false
        entry.status = observationStatus(for: target.status)
        entry.syncState = .synced

        let trimmedNotes = target.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotes.isEmpty || entry.notes.isEmpty {
            entry.notes = target.notes
        }

        if !log.observationEntries.contains(where: { $0.id == entry.id }) {
            log.observationEntries.append(entry)
        }

        log.observationEntries = log.orderedEntries
        target.linkedObservationEntryId = entry.id
        target.syncState = .synced
        plan.linkedNightLogId = log.id
        plan.isConfirmed = true
        plan.syncState = .synced

        try context.save()
        return log
    }

    private static func ensureNightLog(for plan: NightPlan, context: ModelContext) throws -> NightLog {
        let log = try fetchLinkedNightLog(for: plan, context: context) ?? NightLog(
            title: PlanLogSyncService.resolvedNightLogTitle(for: plan),
            observingDate: plan.observingDate,
            actualStart: plan.startTime,
            actualEnd: plan.endTime,
            summaryNotes: plan.notes,
            sourcePlanId: plan.id,
            sourceCampaignPlanId: plan.campaignPlan?.id,
            syncState: .draft,
            site: plan.site,
            equipment: plan.equipment
        )

        if log.modelContext == nil {
            context.insert(log)
        }

        log.title = PlanLogSyncService.resolvedNightLogTitle(for: plan)
        log.observingDate = plan.observingDate
        log.sourcePlanId = plan.id
        log.sourceCampaignPlanId = plan.campaignPlan?.id
        log.syncState = .synced

        if !log.timeWindowWasOverridden {
            log.actualStart = plan.startTime
            log.actualEnd = plan.endTime
        }

        if !log.siteWasOverridden {
            log.site = plan.site
        }

        if !log.equipmentWasOverridden {
            log.equipment = plan.equipment
        }

        let trimmedNotes = plan.notes.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmedNotes.isEmpty || log.summaryNotes.isEmpty {
            log.summaryNotes = plan.notes
        }

        return log
    }

    private static func fetchLinkedNightLog(for plan: NightPlan, context: ModelContext) throws -> NightLog? {
        if let planID = plan.linkedNightLogId {
            let descriptor = FetchDescriptor<NightLog>(
                predicate: #Predicate { log in
                    log.id == planID
                }
            )

            if let log = try context.fetch(descriptor).first {
                return log
            }
        }

        return try PlanLogSyncService.fetchNightLog(for: plan.id, context: context)
    }

    private static func observationStatus(for status: PlannedTargetStatus) -> ObservationEntryStatus {
        switch status {
        case .planned:
            return .planned
        case .observed:
            return .observed
        case .skipped:
            return .skipped
        }
    }

    private static func fetchLinkedObservationEntry(for target: PlannedTarget, context: ModelContext) throws -> ObservationEntry? {
        if let linkedEntryID = target.linkedObservationEntryId {
            let descriptor = FetchDescriptor<ObservationEntry>(
                predicate: #Predicate { entry in
                    entry.id == linkedEntryID
                }
            )

            if let entry = try context.fetch(descriptor).first {
                return entry
            }
        }

        let targetID = target.id
        let descriptor = FetchDescriptor<ObservationEntry>(
            predicate: #Predicate { entry in
                entry.sourcePlannedTargetId == targetID
            }
        )
        return try context.fetch(descriptor).first
    }
}
