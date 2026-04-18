import SwiftData
import SwiftUI

struct CurrentPlanWorkspaceView: View {
    @Query(sort: \NightPlan.observingDate, order: .reverse) private var nightPlans: [NightPlan]
    @Query(sort: \NightLog.observingDate, order: .reverse) private var nightLogs: [NightLog]
    @Binding var selectedSection: SidebarSection

    @State private var selectedPlanID: UUID?
    @State private var workspaceMessage = ""

    private var selectedPlan: NightPlan? {
        if let selectedPlanID, let selectedPlan = nightPlans.first(where: { $0.id == selectedPlanID }) {
            return selectedPlan
        }

        return preferredCurrentPlan
    }

    private var preferredCurrentPlan: NightPlan? {
        nightPlans.first(where: { !$0.isConfirmed }) ?? nightPlans.first
    }

    var body: some View {
        HSplitView {
            CurrentPlanSidebarView(
                plans: nightPlans,
                selectedPlanID: Binding(
                    get: { selectedPlan?.id },
                    set: { selectedPlanID = $0 }
                ),
                onOpenPlanner: {
                    selectedSection = .planObservation
                }
            )
            .frame(minWidth: 290, idealWidth: 330, maxWidth: 390)

            if let selectedPlan {
                CurrentPlanDetailView(
                    plan: selectedPlan,
                    linkedLog: linkedLog(for: selectedPlan),
                    onOpenPlanner: {
                        selectedSection = .planObservation
                    },
                    workspaceMessage: $workspaceMessage
                )
                .id(selectedPlan.id)
            } else {
                ContentUnavailableView {
                    Label("No current plan yet", systemImage: "list.bullet.clipboard")
                } description: {
                    Text("Create a plan on the planning page, then come back here to review, print, and sync targets.")
                } actions: {
                    Button("Open Planner") {
                        selectedSection = .planObservation
                    }
                    .buttonStyle(.borderedProminent)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Current Plan")
        .safeAreaInset(edge: .bottom) {
            if !workspaceMessage.isEmpty {
                Text(workspaceMessage)
                    .font(AppTypography.body)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial)
            }
        }
        .onAppear {
            if selectedPlanID == nil {
                selectedPlanID = preferredCurrentPlan?.id
            }
        }
        .onChange(of: nightPlans.map(\.id)) { _, ids in
            guard !ids.isEmpty else {
                selectedPlanID = nil
                return
            }

            if let selectedPlanID, ids.contains(selectedPlanID) {
                return
            }

            self.selectedPlanID = preferredCurrentPlan?.id ?? ids.first
        }
    }

    private func linkedLog(for plan: NightPlan) -> NightLog? {
        if let linkedNightLogID = plan.linkedNightLogId {
            return nightLogs.first(where: { $0.id == linkedNightLogID })
        }

        return nightLogs.first(where: { $0.sourcePlanId == plan.id })
    }
}

private struct CurrentPlanSidebarView: View {
    let plans: [NightPlan]
    @Binding var selectedPlanID: UUID?
    let onOpenPlanner: () -> Void

    private var visiblePlanCount: Int {
        min(max(plans.count, 1), 2)
    }

    private var planListHeight: CGFloat {
        let rowHeight: CGFloat = 124
        let spacing: CGFloat = 12
        return (CGFloat(visiblePlanCount) * rowHeight) + (CGFloat(max(visiblePlanCount - 1, 0)) * spacing) + 6
    }

    private var selectedPlan: NightPlan? {
        guard let selectedPlanID else { return nil }
        return plans.first(where: { $0.id == selectedPlanID })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            VStack(alignment: .center, spacing: 12) {
                Text("Plan Review")
                    .font(AppTypography.bodyStrong)
                    .frame(maxWidth: .infinity, alignment: .center)

                Text(selectedPlan?.displayTitle ?? "Choose a saved plan to review the setup and target order.")
                    .font(AppTypography.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .center)

                HStack(spacing: 10) {
                    summaryChip(title: "Plans", value: "\(plans.count)")
                    summaryChip(title: "Targets", value: "\(selectedPlan?.orderedTargets.count ?? 0)")
                }
                .frame(maxWidth: .infinity, alignment: .center)

                Button {
                    onOpenPlanner()
                } label: {
                    Label("Open Planner", systemImage: "scope")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(18)
            .frame(maxWidth: .infinity, minHeight: 224, alignment: .top)
            .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 24, style: .continuous))

            if plans.isEmpty {
                ContentUnavailableView(
                    "No saved plans",
                    systemImage: "tray",
                    description: Text("Create a plan on the planning page and it will appear here.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(plans) { plan in
                            CurrentPlanSidebarRow(
                                plan: plan,
                                isSelected: plan.id == selectedPlanID
                            ) {
                                selectedPlanID = plan.id
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
                .frame(height: planListHeight, alignment: .top)
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func summaryChip(title: String, value: String) -> some View {
        VStack(alignment: .center, spacing: 2) {
            Text(title)
                .font(AppTypography.body)
                .foregroundStyle(.secondary)
            Text(value)
                .font(AppTypography.bodyEmphasized)
        }
        .frame(minWidth: 86)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(Color.secondary.opacity(0.12), in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct CurrentPlanSidebarRow: View {
    let plan: NightPlan
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 8) {
                Text(plan.displayTitle)
                    .font(AppTypography.bodyEmphasized)
                    .foregroundStyle(isSelected ? .white : .primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .center, spacing: 10) {
                        dateText

                        Spacer(minLength: 8)

                        syncStateBadge
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        dateText
                        syncStateBadge
                    }
                }

                Text("\(plan.orderedTargets.count) targets")
                    .font(AppTypography.body)
                    .foregroundStyle(isSelected ? .white.opacity(0.80) : .secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(16)
            .frame(maxWidth: .infinity, minHeight: 124, alignment: .topLeading)
            .background(backgroundShape)
        }
        .buttonStyle(.plain)
    }

    private var backgroundShape: some View {
        RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(isSelected ? Color.accentColor : Color.secondary.opacity(0.10))
    }

    private var dateText: some View {
        Text(plan.observingDate.formatted(date: .abbreviated, time: .omitted))
            .font(AppTypography.body)
            .foregroundStyle(isSelected ? .white.opacity(0.88) : .secondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
    }

    private var syncStateBadge: some View {
        Text(plan.syncState.displayName)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(isSelected ? .white : .secondary)
            .lineLimit(2)
            .fixedSize(horizontal: false, vertical: true)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(
                Capsule()
                    .fill(isSelected ? Color.white.opacity(0.18) : Color.secondary.opacity(0.12))
            )
    }
}
