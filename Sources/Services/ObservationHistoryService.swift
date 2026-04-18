import Foundation
import SwiftData
import SwiftUI

#if canImport(AppKit)
import AppKit
#endif

struct LoggedTargetObservation: Identifiable {
    let id: UUID
    let logTitle: String
    let observationDate: Date
    let observationStart: Date?
    let observationEnd: Date?
    let capturedImageCount: Int
    let status: ObservationEntryStatus
    let notes: String
    let siteName: String
}

enum ObservationHistoryService {
    static func fetchLoggedObservations(for target: DSOObject, context: ModelContext) throws -> [LoggedTargetObservation] {
        let entries = try context.fetch(FetchDescriptor<ObservationEntry>())

        return entries
            .filter { entry in
                !entry.isRemoved && entry.object?.catalogID == target.catalogID
            }
            .sorted(by: sortMostRecentFirst)
            .map { entry in
                LoggedTargetObservation(
                    id: entry.id,
                    logTitle: entry.nightLog?.title ?? "Observation",
                    observationDate: entry.nightLog?.observingDate ?? entry.loggedAt ?? .distantPast,
                    observationStart: entry.observationStart ?? entry.nightLog?.actualStart,
                    observationEnd: entry.observationEnd ?? entry.nightLog?.actualEnd,
                    capturedImageCount: entry.capturedImageCount,
                    status: entry.status,
                    notes: entry.notes,
                    siteName: entry.nightLog?.site?.name ?? "Unknown site"
                )
            }
    }

    private static func sortMostRecentFirst(lhs: ObservationEntry, rhs: ObservationEntry) -> Bool {
        let lhsDate = lhs.observationStart ?? lhs.nightLog?.observingDate ?? lhs.loggedAt ?? .distantPast
        let rhsDate = rhs.observationStart ?? rhs.nightLog?.observingDate ?? rhs.loggedAt ?? .distantPast

        if lhsDate == rhsDate {
            return lhs.id.uuidString > rhs.id.uuidString
        }

        return lhsDate > rhsDate
    }
}

#if canImport(AppKit)
enum ObservationHistoryPrintService {
    @MainActor
    static func printReport(for target: DSOObject, records: [LoggedTargetObservation]) {
        let printView = ObservationHistoryPrintDocument(target: target, records: records)
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

private struct ObservationHistoryPrintDocument: View {
    let target: DSOObject
    let records: [LoggedTargetObservation]

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text(target.displayName)
                .font(AppTypography.sectionTitle)
            Text("Logged observations for \(target.catalogID)")
                .font(AppTypography.bodyEmphasized)
                .foregroundStyle(.secondary)
            Text("Generated \(Date().formatted(date: .abbreviated, time: .shortened))")
                .font(AppTypography.body)
                .foregroundStyle(.secondary)

            Divider()

            if records.isEmpty {
                Text("No logged observations found for this target.")
                    .foregroundStyle(.secondary)
            } else {
                ForEach(records) { record in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(record.logTitle)
                            .font(AppTypography.bodyEmphasized)
                        Text("\(record.observationDate.formatted(date: .abbreviated, time: .omitted)) • \(record.siteName)")
                            .font(AppTypography.body)
                            .foregroundStyle(.secondary)
                        Text(observationWindowText(for: record))
                            .font(AppTypography.body)
                        Text("Frames: \(record.capturedImageCount) • Status: \(record.status.displayName)")
                            .font(AppTypography.body)
                        if !record.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            Text(record.notes)
                                .font(AppTypography.body)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Divider()
                }
            }
        }
    }

    private func observationWindowText(for record: LoggedTargetObservation) -> String {
        let start = record.observationStart?.formatted(date: .omitted, time: .shortened) ?? "Unknown start"
        let end = record.observationEnd?.formatted(date: .omitted, time: .shortened) ?? "Unknown end"
        return "Observation Window: \(start) - \(end)"
    }
}
#endif
