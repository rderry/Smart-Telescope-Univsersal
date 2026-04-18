import Foundation
import SwiftData

enum PlanConfirmationService {
    @discardableResult
    static func confirmNightPlan(_ plan: NightPlan, context: ModelContext) throws -> NightLog {
        let log = try PlanLogSyncService.fetchNightLog(for: plan.id, context: context) ?? NightLog(
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

        plan.isConfirmed = true
        plan.syncState = .synced
        plan.linkedNightLogId = log.id

        try PlanLogSyncService.syncNightPlan(plan, to: log, context: context)
        return log
    }

    @discardableResult
    static func confirmCampaign(_ campaign: CampaignPlan, context: ModelContext) throws -> CampaignLog {
        let log = try PlanLogSyncService.fetchCampaignLog(for: campaign.id, context: context) ?? CampaignLog(
            title: campaign.title,
            startDate: campaign.startDate,
            endDate: campaign.endDate,
            notes: campaign.notes,
            sourceCampaignPlanId: campaign.id,
            syncState: .draft
        )

        if log.modelContext == nil {
            context.insert(log)
        }

        log.title = campaign.title
        log.startDate = campaign.startDate
        log.endDate = campaign.endDate
        log.notes = campaign.notes
        log.sourceCampaignPlanId = campaign.id
        log.syncState = .synced

        for night in campaign.nightPlans.sorted(by: { $0.observingDate < $1.observingDate }) {
            let nightLog = try confirmNightPlan(night, context: context)
            nightLog.campaignLog = log
            nightLog.sourceCampaignPlanId = campaign.id
            if !log.nightLogs.contains(where: { $0.id == nightLog.id }) {
                log.nightLogs.append(nightLog)
            }
        }

        campaign.isConfirmed = true
        campaign.syncState = .synced
        campaign.linkedCampaignLogId = log.id

        try context.save()
        return log
    }
}
