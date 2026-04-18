import Foundation
import SwiftUI

#if canImport(AppKit)
import AppKit

enum ObservationPlanPrintService {
    @MainActor
    static func printPlan(_ plan: NightPlan) {
        let printView = ObservationPlanPrintDocument(plan: plan)
            .frame(width: 720, alignment: .topLeading)
            .padding(28)

        let hostingView = NSHostingView(rootView: printView)
        let fittingSize = hostingView.fittingSize
        hostingView.frame = NSRect(
            origin: .zero,
            size: NSSize(
                width: max(720, fittingSize.width),
                height: max(720, fittingSize.height)
            )
        )

        let operation = NSPrintOperation(view: hostingView)
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        operation.run()
    }
}

private struct ObservationPlanPrintDocument: View {
    let plan: NightPlan

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(plan.displayTitle)
                .font(AppTypography.sectionTitle)

            Text("Observation plan for \(plan.observingDate.formatted(date: .abbreviated, time: .omitted))")
                .font(AppTypography.bodyEmphasized)
                .foregroundStyle(.secondary)

            Text("Generated \(Date().formatted(date: .abbreviated, time: .shortened))")
                .font(AppTypography.body)
                .foregroundStyle(.secondary)

            Divider()

            VStack(alignment: .leading, spacing: 6) {
                Text("Time Window: \(timeText)")
                Text("Observation Location: \(plan.site?.name ?? "Not set")")
                Text("Telescope: \(plan.equipment?.name ?? "Not set")")

                if !plan.eyepiece.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Eyepiece: \(plan.eyepiece)")
                }

                if !plan.otherEquipment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Other Equipment: \(plan.otherEquipment)")
                }

                if !plan.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text("Plan Notes: \(plan.notes)")
                }
            }
            .font(AppTypography.body)

            Divider()

            Text("Targets")
                .font(AppTypography.bodyEmphasized)

            if plan.orderedTargets.isEmpty {
                Text("No targets have been added to this plan yet.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(Array(plan.orderedTargets.enumerated()), id: \.element.id) { index, target in
                    VStack(alignment: .leading, spacing: 6) {
                        Text("\(index + 1). \(target.object?.displayName ?? "Unknown target")")
                            .font(AppTypography.bodyEmphasized)

                        Text(targetSummary(for: target))
                            .font(AppTypography.body)
                            .foregroundStyle(.secondary)

                        if !target.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(target.notes)
                                .font(AppTypography.body)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()
                }
            }
        }
    }

    private var timeText: String {
        let start = plan.startTime.formatted(date: .omitted, time: .shortened)
        let end = plan.endTime.formatted(date: .omitted, time: .shortened)
        return "\(start) - \(end)"
    }

    private func targetSummary(for target: PlannedTarget) -> String {
        let object = target.object
        let nameBits = [
            object?.catalogID,
            object.map { $0.objectType.displayName },
            object.map { "Magnitude \($0.magnitude.formatted(.number.precision(.fractionLength(1))))" },
            "Status \(target.status.displayName)"
        ].compactMap { $0 }

        let recommendedWindow: String
        if let recommendedStart = target.recommendedStart, let recommendedEnd = target.recommendedEnd {
            recommendedWindow = "Recommended \(recommendedStart.formatted(date: .omitted, time: .shortened)) - \(recommendedEnd.formatted(date: .omitted, time: .shortened))"
        } else {
            recommendedWindow = "No recommended window"
        }

        return nameBits.joined(separator: " • ") + " • " + recommendedWindow
    }
}
#endif
