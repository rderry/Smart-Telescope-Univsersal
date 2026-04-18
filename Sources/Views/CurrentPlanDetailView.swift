import SwiftData
import SwiftUI

struct CurrentPlanDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var plan: NightPlan
    let linkedLog: NightLog?
    let onOpenPlanner: () -> Void
    @Binding var workspaceMessage: String

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                CurrentPlanSummarySection(plan: plan, linkedLog: linkedLog)
                CurrentPlanInfoSection(plan: plan)
                CurrentPlanActionSection(
                    hasTargets: !plan.orderedTargets.isEmpty,
                    hasLinkedLog: plan.hasLinkedLog,
                    onOpenPlanner: onOpenPlanner,
                    onPrintPlan: printPlan,
                    onSendAllTargets: sendAllTargetsToLog
                )
                CurrentPlanNotesSection(plan: plan) {
                    persistChanges()
                }
                CurrentPlanTargetsSection(
                    plan: plan,
                    onMoveTarget: moveTarget,
                    onPersistTarget: persistChanges,
                    onSendTargetToLog: sendTargetToObservationLog(_:),
                    workspaceMessage: $workspaceMessage
                )
            }
            .padding(24)
            .frame(maxWidth: 1180, alignment: .leading)
        }
        .onChange(of: plan.title) { _, _ in persistChanges() }
        .onChange(of: plan.notes) { _, _ in persistChanges() }
    }

    private func moveTarget(_ target: PlannedTarget, direction: Int) {
        let orderedTargets = plan.orderedTargets
        guard let sourceIndex = orderedTargets.firstIndex(where: { $0.id == target.id }) else { return }

        let destinationIndex = sourceIndex + direction
        guard orderedTargets.indices.contains(destinationIndex) else { return }

        var reorderedTargets = orderedTargets
        reorderedTargets.swapAt(sourceIndex, destinationIndex)

        for (index, reorderedTarget) in reorderedTargets.enumerated() {
            reorderedTarget.orderIndex = index
            if plan.hasLinkedLog {
                reorderedTarget.syncState = .changed
            }
        }

        if plan.hasLinkedLog {
            plan.syncState = .changed
        }

        persistChanges()
        workspaceMessage = "Updated the order for `\(target.object?.catalogID ?? target.id.uuidString)`."
    }

    private func sendTargetToObservationLog(_ target: PlannedTarget) {
        do {
            let log = try ObservationPlanService.sendTargetToObservationLog(target, from: plan, context: modelContext)
            workspaceMessage = "Sent `\(target.object?.catalogID ?? target.id.uuidString)` to `\(log.title)`."
        } catch {
            workspaceMessage = AppIssueFormatter.persistenceMessage(for: "update the observation log", error: error)
        }
    }

    private func sendAllTargetsToLog() {
        guard !plan.orderedTargets.isEmpty else {
            workspaceMessage = "Add at least one target before sending the plan to the observation log."
            return
        }

        do {
            for target in plan.orderedTargets {
                _ = try ObservationPlanService.sendTargetToObservationLog(target, from: plan, context: modelContext)
            }
            workspaceMessage = "Sent \(plan.orderedTargets.count) targets to the observation log."
        } catch {
            workspaceMessage = AppIssueFormatter.persistenceMessage(for: "sync the observation log", error: error)
        }
    }

    private func printPlan() {
        ObservationPlanPrintService.printPlan(plan)
        workspaceMessage = "Opened the print panel for `\(plan.displayTitle)`."
    }

    private func persistChanges() {
        do {
            try modelContext.save()
        } catch {
            workspaceMessage = AppIssueFormatter.persistenceMessage(for: "save current plan changes", error: error)
        }
    }
}

private struct CurrentPlanSummarySection: View {
    let plan: NightPlan
    let linkedLog: NightLog?

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 14) {
                summaryCards
            }

            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .top, spacing: 14) {
                    summaryCardViews[0]
                    summaryCardViews[1]
                }

                HStack(alignment: .top, spacing: 14) {
                    summaryCardViews[2]
                    summaryCardViews[3]
                }
            }
        }
    }

    private var summaryCards: some View {
        ForEach(Array(summaryCardViews.enumerated()), id: \.offset) { _, view in
            view
        }
    }

    private var summaryCardViews: [AnyView] {
        [
            AnyView(summaryCard(
                title: "Current Session",
                primary: plan.displayTitle,
                secondary: plan.observingDate.formatted(date: .complete, time: .omitted)
            )),
            AnyView(summaryCard(
                title: "Window",
                primary: "\(plan.startTime.formatted(date: .omitted, time: .shortened)) - \(plan.endTime.formatted(date: .omitted, time: .shortened))",
                secondary: plan.site?.name ?? "Observation location not set"
            )),
            AnyView(summaryCard(
                title: "Targets",
                primary: "\(plan.orderedTargets.count)",
                secondary: plan.orderedTargets.first?.object?.displayName ?? "No targets yet"
            )),
            AnyView(summaryCard(
                title: "Log Status",
                primary: linkedLog?.title ?? "Not linked yet",
                secondary: linkedLog.map { "\($0.orderedEntries.count) log entries" } ?? plan.syncState.displayName
            ))
        ]
    }

    private func summaryCard(title: String, primary: String, secondary: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(AppTypography.body)
                .foregroundStyle(.secondary)

            Text(primary)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(secondary)
                .font(AppTypography.body)
                .foregroundStyle(.secondary)
                .lineLimit(3)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))
    }
}

private struct CurrentPlanInfoSection: View {
    let plan: NightPlan

    var body: some View {
        GroupBox("Plan Details") {
            VStack(alignment: .leading, spacing: 14) {
                detailRow(title: "Plan Name", value: plan.displayTitle)
                detailRow(title: "Date", value: plan.observingDate.formatted(date: .long, time: .omitted))
                detailRow(title: "Time", value: "\(plan.startTime.formatted(date: .omitted, time: .shortened)) - \(plan.endTime.formatted(date: .omitted, time: .shortened))")
                detailRow(title: "Observation Location", value: plan.site?.name ?? "Not set")
                detailRow(title: "Telescope", value: plan.equipment?.name ?? "Not set")
                detailRow(title: "Eye Piece", value: nonEmpty(plan.eyepiece))
                detailRow(title: "Other Equipment", value: nonEmpty(plan.otherEquipment))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func detailRow(title: String, value: String) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                Text(title)
                    .font(AppTypography.bodyEmphasized)
                    .frame(width: 180, alignment: .leading)

                Text(value)
                    .font(AppTypography.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(AppTypography.bodyEmphasized)

                Text(value)
                    .font(AppTypography.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func nonEmpty(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Not set" : trimmed
    }
}

private struct CurrentPlanActionSection: View {
    let hasTargets: Bool
    let hasLinkedLog: Bool
    let onOpenPlanner: () -> Void
    let onPrintPlan: () -> Void
    let onSendAllTargets: () -> Void

    var body: some View {
        GroupBox("Plan Actions") {
            VStack(alignment: .center, spacing: 14) {
                Text(
                    hasLinkedLog
                        ? "Review the current setup, print the plan, or send the latest changes back into the observation log."
                        : "Review the current setup, print the plan, or send every target into the observation log."
                )
                .font(AppTypography.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) {
                        actionButtons
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    VStack(alignment: .center, spacing: 12) {
                        actionButtons
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
    }

    @ViewBuilder
    private var actionButtons: some View {
        Button(action: onOpenPlanner) {
            Label("Open Planner", systemImage: "scope")
        }
        .buttonStyle(.bordered)
        .controlSize(.large)

        Button(action: onPrintPlan) {
            Label("Print Plan", systemImage: "printer")
        }
        .buttonStyle(.bordered)
        .controlSize(.large)

        Button(action: onSendAllTargets) {
            Label(hasLinkedLog ? "Update Log" : "Send All to Log", systemImage: "arrowshape.turn.up.right")
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.large)
        .disabled(!hasTargets)
    }
}

private struct CurrentPlanNotesSection: View {
    @Bindable var plan: NightPlan
    let onPersist: () -> Void

    var body: some View {
        GroupBox("Plan Notes") {
            TextField("Review notes, sequence reminders, or weather notes", text: $plan.notes, axis: .vertical)
                .lineLimit(3...6)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.body)
                .onChange(of: plan.notes) { _, _ in
                    onPersist()
                }
        }
    }
}

private struct CurrentPlanTargetsSection: View {
    @Bindable var plan: NightPlan
    let onMoveTarget: (PlannedTarget, Int) -> Void
    let onPersistTarget: () -> Void
    let onSendTargetToLog: (PlannedTarget) -> Void
    @Binding var workspaceMessage: String

    var body: some View {
        GroupBox("Target Lineup") {
            if plan.orderedTargets.isEmpty {
                ContentUnavailableView(
                    "No targets in this plan",
                    systemImage: "sparkles",
                    description: Text("Use the planning page to add objects, then return here to review and sync them.")
                )
                .frame(maxWidth: .infinity, minHeight: 220)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(Array(plan.orderedTargets.enumerated()), id: \.element.id) { index, target in
                            CurrentPlanTargetRowView(
                                target: target,
                                site: plan.site,
                                lookupDate: target.recommendedStart ?? plan.startTime,
                                isFirst: index == 0,
                                isLast: index == plan.orderedTargets.count - 1,
                                onMoveUp: { onMoveTarget(target, -1) },
                                onMoveDown: { onMoveTarget(target, 1) },
                                onPersist: onPersistTarget,
                                onSendToLog: { onSendTargetToLog(target) }
                            )
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                .frame(maxWidth: .infinity, minHeight: 180, maxHeight: 320, alignment: .top)
            }
        }
    }
}

private struct CurrentPlanTargetRowView: View {
    @Bindable var target: PlannedTarget
    let site: ObservingSite?
    let lookupDate: Date
    let isFirst: Bool
    let isLast: Bool
    let onMoveUp: () -> Void
    let onMoveDown: () -> Void
    let onPersist: () -> Void
    let onSendToLog: () -> Void

    private var localSkyText: String {
        guard let object = target.object, let site else {
            return "Altitude and azimuth will appear once the target and observation location are set."
        }

        let skyPosition = SkyCoordinateService.localSkyPosition(for: object, site: site, at: lookupDate)
        return "Altitude \(skyPosition.altitudeDegrees.formatted(.number.precision(.fractionLength(1))))° • Azimuth \(skyPosition.azimuthDegrees.formatted(.number.precision(.fractionLength(0))))° • \(skyPosition.magneticCardinalDirection)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    targetTextBlock

                    Spacer(minLength: 12)

                    moveButtons
                }

                VStack(alignment: .leading, spacing: 10) {
                    targetTextBlock

                    HStack(spacing: 10) {
                        moveButtons
                    }
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    statusControls
                }

                VStack(alignment: .leading, spacing: 10) {
                    statusControls
                }
            }

            TextField("Target notes", text: $target.notes, axis: .vertical)
                .lineLimit(2...3)
                .textFieldStyle(.roundedBorder)
                .font(AppTypography.body)
                .onChange(of: target.notes) { _, _ in
                    onPersist()
                }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
    }

    private var targetTextBlock: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(target.object?.displayName ?? "Unknown target")
                .font(AppTypography.bodyStrong)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)

            Text(summaryLine)
                .font(AppTypography.body)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)

            Text(localSkyText)
                .font(AppTypography.body)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var moveButtons: some View {
        HStack(spacing: 10) {
            Button(action: onMoveUp) {
                Image(systemName: "arrow.up")
            }
            .buttonStyle(.bordered)
            .disabled(isFirst)

            Button(action: onMoveDown) {
                Image(systemName: "arrow.down")
            }
            .buttonStyle(.bordered)
            .disabled(isLast)
        }
    }

    private var statusControls: some View {
        Group {
            Picker("Status", selection: $target.status) {
                ForEach(PlannedTargetStatus.allCases) { status in
                    Text(status.displayName).tag(status)
                }
            }
            .pickerStyle(.menu)
            .onChange(of: target.status) { _, _ in
                onPersist()
            }

            Spacer()

            Button(action: onSendToLog) {
                Label(target.linkedObservationEntryId == nil ? "Send to Log" : "Update Log", systemImage: "arrowshape.turn.up.right")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var summaryLine: String {
        let scoreText = "Score \(target.plannerScore.formatted(.number.precision(.fractionLength(0))))"
        let magnitudeText = target.object.map { "Mag \($0.magnitude.formatted(.number.precision(.fractionLength(1))))" }
        let typeText = target.object?.objectType.displayName
        let stateText = target.syncState.displayName

        return [typeText, magnitudeText, scoreText, stateText].compactMap { $0 }.joined(separator: " • ")
    }
}
