import Foundation
import SwiftData

enum PlanLogSyncService {
    static func resolvedNightLogTitle(for plan: NightPlan) -> String {
        if !plan.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return plan.title
        }

        if let targetName = plan.campaignPlan?.sharedTarget?.displayName {
            return "\(targetName) • \(plan.observingDate.formatted(date: .abbreviated, time: .omitted))"
        }

        return defaultNightLogTitle(for: plan.observingDate)
    }

    static func syncNightPlanToLinkedLog(_ plan: NightPlan, context: ModelContext) throws {
        guard let log = try fetchNightLog(for: plan.id, context: context) else { return }
        try syncNightPlan(plan, to: log, context: context)
    }

    static func syncNightPlan(_ plan: NightPlan, to log: NightLog, context: ModelContext) throws {
        log.title = resolvedNightLogTitle(for: plan)
        log.observingDate = plan.observingDate
        if !log.timeWindowWasOverridden {
            log.actualStart = plan.startTime
            log.actualEnd = plan.endTime
        }
        log.summaryNotes = plan.notes
        log.sourcePlanId = plan.id
        log.sourceCampaignPlanId = plan.campaignPlan?.id
        log.syncState = .synced

        if !log.siteWasOverridden {
            log.site = plan.site
        }
        if !log.equipmentWasOverridden {
            log.equipment = plan.equipment
        }

        let plannedTargets = plan.orderedTargets
        let plannedTargetIDs = Set(plannedTargets.map(\.id))
        let standaloneEntries = log.observationEntries.filter { $0.sourcePlannedTargetId == nil }
        let linkedEntries = log.observationEntries.filter { $0.sourcePlannedTargetId != nil }
        let existingEntriesBySource = linkedEntries.reduce(into: [UUID: ObservationEntry]()) { partialResult, entry in
            guard let sourceID = entry.sourcePlannedTargetId else { return }
            partialResult[sourceID] = entry
        }
        var syncedLinkedEntries: [ObservationEntry] = []

        for (index, target) in plannedTargets.enumerated() {
            let entry = existingEntriesBySource[target.id] ?? {
                let newEntry = ObservationEntry(
                    orderIndex: index,
                    loggedAt: nil,
                    observationStart: target.observationStart,
                    observationEnd: target.observationEnd,
                    capturedImageCount: target.capturedImageCount,
                    notes: target.notes,
                    status: .planned,
                    syncState: .synced,
                    sourcePlannedTargetId: target.id,
                    object: target.object,
                    nightLog: nil
                )
                return newEntry
            }()

            if entry.modelContext == nil {
                context.insert(entry)
            }

            entry.nightLog = log
            entry.orderIndex = index
            entry.object = target.object
            entry.sourcePlannedTargetId = target.id
            entry.observationStart = target.observationStart
            entry.observationEnd = target.observationEnd
            entry.capturedImageCount = target.capturedImageCount
            entry.isRemoved = false
            entry.syncState = SyncState.synced
            if entry.status == ObservationEntryStatus.cancelled {
                entry.status = ObservationEntryStatus.planned
            }
            if entry.notes.isEmpty {
                entry.notes = target.notes
            }

            target.linkedObservationEntryId = entry.id
            target.syncState = .synced
            syncedLinkedEntries.append(entry)
        }

        let removedLinkedEntries = linkedEntries.filter { entry in
            guard let sourceID = entry.sourcePlannedTargetId else { return false }
            return !plannedTargetIDs.contains(sourceID)
        }

        for entry in removedLinkedEntries {
            entry.isRemoved = true
            entry.status = .cancelled
            entry.syncState = .removed
            entry.nightLog = log
        }

        log.observationEntries = (standaloneEntries + syncedLinkedEntries + removedLinkedEntries)
            .sorted { lhs, rhs in
                if lhs.orderIndex == rhs.orderIndex {
                    return lhs.id.uuidString < rhs.id.uuidString
                }
                return lhs.orderIndex < rhs.orderIndex
            }

        plan.linkedNightLogId = log.id
        plan.syncState = .synced
        try context.save()
    }

    static func syncObservationEntryBackToPlan(_ entry: ObservationEntry, context: ModelContext) throws {
        guard let sourcePlannedTargetId = entry.sourcePlannedTargetId else { return }
        let descriptor = FetchDescriptor<PlannedTarget>(
            predicate: #Predicate { target in
                target.id == sourcePlannedTargetId
            }
        )
        guard let target = try context.fetch(descriptor).first else { return }

        switch entry.status {
        case .planned:
            target.status = .planned
        case .observed:
            target.status = .observed
        case .skipped, .cancelled:
            target.status = .skipped
        }

        target.syncState = entry.isRemoved ? .removed : .synced
        try context.save()
    }

    static func fetchNightLog(for planID: UUID, context: ModelContext) throws -> NightLog? {
        let descriptor = FetchDescriptor<NightLog>(
            predicate: #Predicate { log in
                log.sourcePlanId == planID
            }
        )
        return try context.fetch(descriptor).first
    }

    static func fetchCampaignLog(for campaignID: UUID, context: ModelContext) throws -> CampaignLog? {
        let descriptor = FetchDescriptor<CampaignLog>(
            predicate: #Predicate { log in
                log.sourceCampaignPlanId == campaignID
            }
        )
        return try context.fetch(descriptor).first
    }

    static func defaultNightLogTitle(for date: Date) -> String {
        "Observation Log \(date.formatted(date: .abbreviated, time: .omitted))"
    }
}
