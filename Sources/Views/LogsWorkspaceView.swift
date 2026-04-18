import SwiftData
import SwiftUI

private enum LogsMode: String, CaseIterable, Identifiable {
    case nightLogs
    case campaignLogs

    var id: String { rawValue }

    var title: String {
        switch self {
        case .nightLogs: "Night Logs"
        case .campaignLogs: "Observation Logs"
        }
    }
}

struct LogsWorkspaceView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NightLog.observingDate, order: .reverse) private var nightLogs: [NightLog]
    @Query(sort: \CampaignLog.startDate, order: .reverse) private var campaignLogs: [CampaignLog]
    @Query(sort: \DSOObject.primaryDesignation) private var catalogObjects: [DSOObject]
    @Binding var selectedSection: SidebarSection

    @State private var mode: LogsMode = .nightLogs
    @State private var selectedNightLogID: UUID?
    @State private var selectedCampaignLogID: UUID?
    @State private var message = ""

    var body: some View {
        VStack(spacing: 0) {
            Picker("Logs", selection: $mode) {
                ForEach(LogsMode.allCases) { entry in
                    Text(entry.title).tag(entry)
                }
            }
            .pickerStyle(.segmented)
            .padding()

            HSplitView {
                listPane
                    .frame(minWidth: 320, idealWidth: 360, maxWidth: 420)

                detailPane
            }
        }
        .navigationTitle("Logs")
        .safeAreaInset(edge: .bottom) {
            if !message.isEmpty {
                Text(message)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(.thinMaterial)
            }
        }
        .onAppear {
            selectedNightLogID = nightLogs.first?.id
            selectedCampaignLogID = campaignLogs.first?.id
        }
    }

    @ViewBuilder
    private var listPane: some View {
        switch mode {
        case .nightLogs:
            List(selection: $selectedNightLogID) {
                Section {
                    ForEach(nightLogs) { log in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(log.title)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            Text(log.observingDate.formatted(date: .abbreviated, time: .omitted))
                                .font(AppTypography.body)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .tag(log.id)
                    }
                    .onDelete(perform: deleteNightLogs)
                } header: {
                    HStack {
                        Text("Night Logs")
                        Spacer()
                        Button("New Standalone") {
                            addStandaloneNightLog()
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        case .campaignLogs:
            List(selection: $selectedCampaignLogID) {
                Section("Observation Logs") {
                    ForEach(campaignLogs) { log in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(log.title)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("\(log.nightLogs.count) linked nights")
                                .font(AppTypography.body)
                                .foregroundStyle(.secondary)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .tag(log.id)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private var detailPane: some View {
        switch mode {
        case .nightLogs:
            if let selectedNightLog {
                NightLogEditorView(log: selectedNightLog, allObjects: catalogObjects, message: $message)
            } else {
                ContentUnavailableView("Select a night log", systemImage: "book.closed")
            }
        case .campaignLogs:
            if let selectedCampaignLog {
                CampaignLogDetailView(log: selectedCampaignLog)
            } else {
                ContentUnavailableView("Select an observation log", systemImage: "book.closed")
            }
        }
    }

    private var selectedNightLog: NightLog? {
        nightLogs.first(where: { $0.id == selectedNightLogID }) ?? nightLogs.first
    }

    private var selectedCampaignLog: CampaignLog? {
        campaignLogs.first(where: { $0.id == selectedCampaignLogID }) ?? campaignLogs.first
    }

    private func addStandaloneNightLog() {
        let now = Date()
        let log = NightLog(
            title: "Standalone Log \(now.formatted(date: .abbreviated, time: .omitted))",
            observingDate: now,
            actualStart: now,
            actualEnd: Calendar.current.date(byAdding: .hour, value: 4, to: now),
            summaryNotes: "",
            syncState: .draft
        )
        modelContext.insert(log)
        do {
            try modelContext.save()
            selectedNightLogID = log.id
            message = "Added a standalone night log."
        } catch {
            message = AppIssueFormatter.persistenceMessage(for: "save the new night log", error: error)
        }
    }

    private func deleteNightLogs(at offsets: IndexSet) {
        for index in offsets {
            modelContext.delete(nightLogs[index])
        }
        do {
            try modelContext.save()
            selectedNightLogID = nightLogs.first?.id
            message = "Deleted the selected night log."
        } catch {
            message = AppIssueFormatter.persistenceMessage(for: "delete the night log", error: error)
        }
    }
}

private struct NightLogEditorView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var log: NightLog
    let allObjects: [DSOObject]
    @Binding var message: String
    @State private var manualSelectionID = ""

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GroupBox("Night Log") {
                    VStack(alignment: .leading, spacing: 12) {
                        TextField("Title", text: $log.title)
                            .controlSize(.large)
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 12) {
                                DatePicker("Date", selection: $log.observingDate, displayedComponents: .date)
                                DatePicker("Start", selection: actualStartBinding, displayedComponents: [.date, .hourAndMinute])
                                DatePicker("End", selection: actualEndBinding, displayedComponents: [.date, .hourAndMinute])
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                DatePicker("Date", selection: $log.observingDate, displayedComponents: .date)
                                DatePicker("Start", selection: actualStartBinding, displayedComponents: [.date, .hourAndMinute])
                                DatePicker("End", selection: actualEndBinding, displayedComponents: [.date, .hourAndMinute])
                            }
                        }
                        TextField("Summary notes", text: $log.summaryNotes, axis: .vertical)
                            .lineLimit(3...6)
                        if log.sourcePlanId != nil {
                            Label("Live-linked from a confirmed plan", systemImage: "link")
                                .foregroundStyle(.secondary)
                        } else {
                            Label("Standalone log", systemImage: "square.and.pencil")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                GroupBox("Observation Entries") {
                    VStack(alignment: .leading, spacing: 12) {
                        ViewThatFits(in: .horizontal) {
                            HStack(spacing: 12) {
                                Picker("Add object", selection: $manualSelectionID) {
                                    Text("Select target").tag("")
                                    ForEach(allObjects) { object in
                                        Text(object.displayName).tag(object.catalogID)
                                    }
                                }
                                Button("Add Ad Hoc") {
                                    guard let object = allObjects.first(where: { $0.catalogID == manualSelectionID }) else { return }
                                    let entry = ObservationEntry(
                                        orderIndex: log.observationEntries.count,
                                        loggedAt: Date(),
                                        notes: "",
                                        status: .planned,
                                        syncState: .draft,
                                        object: object,
                                        nightLog: log
                                    )
                                    modelContext.insert(entry)
                                    log.observationEntries.append(entry)
                                    do {
                                        try modelContext.save()
                                        manualSelectionID = ""
                                        message = "Added an ad hoc observation entry."
                                    } catch {
                                        message = AppIssueFormatter.persistenceMessage(for: "save the ad hoc observation entry", error: error)
                                    }
                                }
                                .disabled(manualSelectionID.isEmpty)
                                .controlSize(.large)
                            }

                            VStack(alignment: .leading, spacing: 12) {
                                Picker("Add object", selection: $manualSelectionID) {
                                    Text("Select target").tag("")
                                    ForEach(allObjects) { object in
                                        Text(object.displayName).tag(object.catalogID)
                                    }
                                }
                                Button("Add Ad Hoc") {
                                    guard let object = allObjects.first(where: { $0.catalogID == manualSelectionID }) else { return }
                                    let entry = ObservationEntry(
                                        orderIndex: log.observationEntries.count,
                                        loggedAt: Date(),
                                        notes: "",
                                        status: .planned,
                                        syncState: .draft,
                                        object: object,
                                        nightLog: log
                                    )
                                    modelContext.insert(entry)
                                    log.observationEntries.append(entry)
                                    do {
                                        try modelContext.save()
                                        manualSelectionID = ""
                                        message = "Added an ad hoc observation entry."
                                    } catch {
                                        message = AppIssueFormatter.persistenceMessage(for: "save the ad hoc observation entry", error: error)
                                    }
                                }
                                .disabled(manualSelectionID.isEmpty)
                                .controlSize(.large)
                            }
                        }

                        if log.orderedEntries.isEmpty {
                            ContentUnavailableView("No observations yet", systemImage: "eye")
                        } else {
                            ForEach(log.orderedEntries) { entry in
                                ObservationEntryRow(entry: entry, message: $message)
                                Divider()
                            }
                        }
                    }
                }
            }
            .padding(20)
        }
    }

    private var actualStartBinding: Binding<Date> {
        Binding(
            get: { log.actualStart ?? log.observingDate },
            set: {
                log.timeWindowWasOverridden = true
                log.actualStart = $0
            }
        )
    }

    private var actualEndBinding: Binding<Date> {
        Binding(
            get: { log.actualEnd ?? log.observingDate.addingTimeInterval(10800) },
            set: {
                log.timeWindowWasOverridden = true
                log.actualEnd = $0
            }
        )
    }
}

private struct ObservationEntryRow: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var entry: ObservationEntry
    @Binding var message: String

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.object?.displayName ?? "Unknown target")
                            .font(AppTypography.bodyEmphasized)
                        if entry.isRemoved {
                            Text("Removed from the source plan")
                                .font(AppTypography.body)
                                .foregroundStyle(.orange)
                        }
                    }
                    Spacer()
                    Picker("Status", selection: Binding(
                        get: { entry.status },
                        set: { newValue in
                            entry.status = newValue
                            entry.loggedAt = newValue == .planned ? entry.loggedAt : (entry.loggedAt ?? Date())
                            syncBack()
                        }
                    )) {
                        ForEach(ObservationEntryStatus.allCases) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.large)
                }

                VStack(alignment: .leading, spacing: 10) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(entry.object?.displayName ?? "Unknown target")
                            .font(AppTypography.bodyEmphasized)
                        if entry.isRemoved {
                            Text("Removed from the source plan")
                                .font(AppTypography.body)
                                .foregroundStyle(.orange)
                        }
                    }
                    Picker("Status", selection: Binding(
                        get: { entry.status },
                        set: { newValue in
                            entry.status = newValue
                            entry.loggedAt = newValue == .planned ? entry.loggedAt : (entry.loggedAt ?? Date())
                            syncBack()
                        }
                    )) {
                        ForEach(ObservationEntryStatus.allCases) { status in
                            Text(status.displayName).tag(status)
                        }
                    }
                    .labelsHidden()
                    .controlSize(.large)
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    Picker("Seeing", selection: Binding(get: { entry.seeing }, set: { entry.seeing = $0; syncBack() })) {
                        ForEach(SeeingCondition.allCases) { seeing in
                            Text(seeing.displayName).tag(seeing)
                        }
                    }
                    .controlSize(.large)
                    Picker("Transparency", selection: Binding(get: { entry.transparency }, set: { entry.transparency = $0; syncBack() })) {
                        ForEach(TransparencyCondition.allCases) { transparency in
                            Text(transparency.displayName).tag(transparency)
                        }
                    }
                    .controlSize(.large)
                }

                VStack(alignment: .leading, spacing: 12) {
                    Picker("Seeing", selection: Binding(get: { entry.seeing }, set: { entry.seeing = $0; syncBack() })) {
                        ForEach(SeeingCondition.allCases) { seeing in
                            Text(seeing.displayName).tag(seeing)
                        }
                    }
                    .controlSize(.large)
                    Picker("Transparency", selection: Binding(get: { entry.transparency }, set: { entry.transparency = $0; syncBack() })) {
                        ForEach(TransparencyCondition.allCases) { transparency in
                            Text(transparency.displayName).tag(transparency)
                        }
                    }
                    .controlSize(.large)
                }
            }

            TextField("Observation notes", text: $entry.notes, axis: .vertical)
                .lineLimit(2...5)
        }
    }

    private func syncBack() {
        do {
            try PlanLogSyncService.syncObservationEntryBackToPlan(entry, context: modelContext)
        } catch {
            message = AppIssueFormatter.persistenceMessage(for: "sync the observation entry back to the plan", error: error)
        }
    }
}

private struct CampaignLogDetailView: View {
    @Bindable var log: CampaignLog

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                GroupBox("Observation Log") {
                    VStack(alignment: .leading, spacing: 10) {
                        Text(log.title)
                            .font(AppTypography.sectionTitle)
                        Text("\(log.startDate.formatted(date: .abbreviated, time: .omitted)) - \(log.endDate.formatted(date: .abbreviated, time: .omitted))")
                            .foregroundStyle(.secondary)
                        Text(log.notes.isEmpty ? "No observation notes yet." : log.notes)
                    }
                }

                GroupBox("Night Sessions") {
                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(log.nightLogs.sorted(by: { $0.observingDate < $1.observingDate })) { night in
                            VStack(alignment: .leading, spacing: 6) {
                                Text(night.title)
                                    .font(AppTypography.bodyEmphasized)
                                Text("\(night.orderedEntries.filter { $0.status == .observed }.count) observed • \(night.orderedEntries.filter { $0.status == .planned }.count) pending • \(night.orderedEntries.filter { $0.status == .cancelled }.count) cancelled")
                                    .foregroundStyle(.secondary)
                            }
                            Divider()
                        }
                    }
                }
            }
            .padding(20)
        }
    }
}
