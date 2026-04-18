import SwiftData
import SwiftUI

struct PlanObservationWorkspaceView: View {
    @Environment(AppRuntimeState.self) private var runtimeState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \NightPlan.observingDate, order: .reverse) private var nightPlans: [NightPlan]
    @Query(sort: \ObservingSite.name) private var sites: [ObservingSite]
    @Query(sort: \EquipmentProfile.name) private var equipmentProfiles: [EquipmentProfile]
    @Query(sort: \DSOObject.primaryDesignation) private var catalogObjects: [DSOObject]
    @Binding var selectedSection: SidebarSection

    @State private var selectedPlanID: UUID?
    @State private var workspaceMessage = ""

    var body: some View {
        VStack(spacing: 0) {
            plannerCommandBar

            HSplitView {
                currentObjectsSidebar
                    .frame(minWidth: 290, idealWidth: 350, maxWidth: 420)

                if let selectedPlan {
                    ObservationPlanDetailView(
                        plan: selectedPlan,
                        allSites: sites,
                        allEquipment: equipmentProfiles,
                        allObjects: catalogObjects,
                        workspaceMessage: $workspaceMessage
                    )
                    .id(selectedPlan.id)
                } else {
                    ContentUnavailableView {
                        Label("Create your first observation plan", systemImage: "scope")
                    } description: {
                        Text("Start with the date, observing site, and equipment, then add ranked targets for the night.")
                    } actions: {
                        Button("New Observation Plan") {
                            addPlan()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .padding(.top, 8)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
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
            if runtimeState.pendingSingleNightPlanRequest {
                runtimeState.pendingSingleNightPlanRequest = false
                addPlan()
            } else if selectedPlanID == nil {
                selectedPlanID = nightPlans.first?.id
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

            selectedPlanID = ids.first
        }
    }

    private var plannerCommandBar: some View {
        HStack(spacing: 12) {
            Button("Cancel") {
                selectedSection = .home
            }
            .buttonStyle(.bordered)
            .controlSize(.large)

            Button {
                addPlan()
            } label: {
                Label("New Plan", systemImage: "plus")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 20)
        .padding(.bottom, 8)
    }

    private var selectedPlan: NightPlan? {
        nightPlans.first(where: { $0.id == selectedPlanID }) ?? nightPlans.first
    }

    private var currentObjectsSidebar: some View {
        VStack(alignment: .leading, spacing: 16) {
            currentObjectsSummary

            currentObjectsList
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var currentObjectsSummary: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Current Objects")
                .font(AppTypography.bodyEmphasized)
                .foregroundStyle(.primary)

            if let selectedPlan {
                Text(selectedPlan.displayTitle)
                    .font(AppTypography.body)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Text("\(selectedPlan.orderedTargets.count) in this plan")
                    .font(AppTypography.body)
                    .foregroundStyle(.tertiary)
            } else {
                Text("Create a plan to start building an object list.")
                    .font(AppTypography.body)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var currentObjectsList: some View {
        if let selectedPlan, !selectedPlan.orderedTargets.isEmpty {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 10) {
                    ForEach(selectedPlan.orderedTargets) { target in
                        CurrentObjectSidebarRow(target: target)
                    }
                }
                .padding(14)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        } else {
            ContentUnavailableView(
                "No objects in the current plan",
                systemImage: "sparkles",
                description: Text("Add catalog objects or suggestions and they will appear here.")
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 20, style: .continuous))
        }
    }

    private func addPlan() {
        let now = Date()
        let calendar = Calendar.current
        let observingDate = calendar.startOfDay(for: now)
        let start = calendar.date(bySettingHour: 21, minute: 0, second: 0, of: observingDate) ?? now
        let end = calendar.date(byAdding: .hour, value: 4, to: start) ?? start.addingTimeInterval(4 * 3600)

        let plan = NightPlan(
            title: "Plan \(observingDate.formatted(date: .abbreviated, time: .omitted))",
            observingDate: observingDate,
            startTime: start,
            endTime: end,
            site: LocationPreferenceStore.preferredSite(from: sites),
            equipment: equipmentProfiles.first
        )

        modelContext.insert(plan)

        do {
            try modelContext.save()
            selectedPlanID = plan.id
            workspaceMessage = "Created a new plan in the plan database."
        } catch {
            workspaceMessage = AppIssueFormatter.persistenceMessage(for: "create the observation plan", error: error)
        }
    }

}

private struct CurrentObjectSidebarRow: View {
    let target: PlannedTarget

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(target.object?.displayName ?? "Unknown object")
                .font(AppTypography.bodyEmphasized)
                .foregroundStyle(.primary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            Text(target.object?.objectType.displayName ?? "Type not assigned")
                .font(AppTypography.body)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct ObservationPlanDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Bindable var plan: NightPlan
    let allSites: [ObservingSite]
    let allEquipment: [EquipmentProfile]
    let allObjects: [DSOObject]
    @Binding var workspaceMessage: String

    @State private var catalogQuery = ""
    @State private var lookupTime = Date()
    @State private var suggestedTargets: [PlannedTargetSuggestion] = []
    @State private var hasGeneratedSuggestions = false
    @State private var lookupResultIndex = 0
    @State private var moonPhaseSnapshot: MoonPhaseSnapshot?
    @State private var isLoadingMoonPhase = false
    @State private var moonPhaseMessage = ""
    @State private var observationCountry: ObservationCountryDetails?
    @State private var weatherSource = WeatherSourcePolicy.source(for: nil)
    @State private var isResolvingObservationCountry = false
    @State private var weatherSourceMessage = ""

    private var resolvedSite: ObservingSite? {
        guard let site = plan.site else { return nil }
        let modelID = site.persistentModelID
        return allSites.first(where: { $0.persistentModelID == modelID })
    }

    private var resolvedEquipment: EquipmentProfile? {
        guard let equipment = plan.equipment else { return nil }
        let modelID = equipment.persistentModelID
        return allEquipment.first(where: { $0.persistentModelID == modelID })
    }

    private var selectableEquipment: [EquipmentProfile] {
        EquipmentCatalogService.sortedProfiles(allEquipment.filter(\.isPlanCompatibleDefault))
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                summaryStrip
                configurationCard
                discoveryCard
            }
            .padding(24)
            .frame(maxWidth: 1120, alignment: .leading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onChange(of: plan.title) { _, _ in persistPlanChanges() }
        .onChange(of: plan.observingDate) { _, newValue in
            alignTimeWindow(to: newValue)
            alignLookupTime(to: newValue)
            persistPlanChanges()
        }
        .onChange(of: plan.startTime) { _, _ in persistPlanChanges() }
        .onChange(of: plan.endTime) { _, _ in persistPlanChanges() }
        .onChange(of: plan.notes) { _, _ in persistPlanChanges() }
        .onChange(of: plan.eyepiece) { _, _ in persistPlanChanges() }
        .onChange(of: plan.otherEquipment) { _, _ in persistPlanChanges() }
        .onChange(of: resolvedSite?.id) { _, _ in
            suggestedTargets = []
            hasGeneratedSuggestions = false
            persistPlanChanges()
        }
        .onChange(of: resolvedEquipment?.id) { _, _ in persistPlanChanges() }
        .onChange(of: catalogQuery) { _, _ in
            lookupResultIndex = 0
        }
        .onChange(of: lookupResults.map(\.catalogID)) { _, ids in
            guard !ids.isEmpty else {
                lookupResultIndex = 0
                return
            }

            lookupResultIndex = min(lookupResultIndex, ids.count - 1)
        }
        .onAppear {
            sanitizeReferencedModels()
            lookupTime = plan.startTime
        }
        .task(id: moonPhaseRequestKey) {
            await refreshMoonPhase()
        }
        .task(id: weatherSourceRequestKey) {
            await refreshWeatherSource()
        }
    }

    private var observationDurationHours: Double {
        max(plan.endTime.timeIntervalSince(plan.startTime), 0) / 3600
    }

    private var trimmedCatalogQuery: String {
        catalogQuery.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var lookupResults: [DSOObject] {
        let candidates: [DSOObject]

        if trimmedCatalogQuery.isEmpty {
            candidates = allObjects
        } else {
            candidates = allObjects.filter { object in
                object.catalogID.localizedCaseInsensitiveContains(trimmedCatalogQuery)
                || object.primaryDesignation.localizedCaseInsensitiveContains(trimmedCatalogQuery)
                || object.commonName.localizedCaseInsensitiveContains(trimmedCatalogQuery)
                || object.constellation.localizedCaseInsensitiveContains(trimmedCatalogQuery)
                || object.objectType.displayName.localizedCaseInsensitiveContains(trimmedCatalogQuery)
                || object.alternateDesignations.contains(where: { $0.localizedCaseInsensitiveContains(trimmedCatalogQuery) })
            }
        }

        return candidates
            .sorted { lhs, rhs in
                if lhs.magnitude == rhs.magnitude {
                    return lhs.displayName < rhs.displayName
                }
                return lhs.magnitude < rhs.magnitude
            }
            .prefix(12)
            .map { $0 }
    }

    private var visibleSuggestedTargets: [PlannedTargetSuggestion] {
        let existingIDs = Set(plan.plannedTargets.compactMap { $0.object?.catalogID })
        return suggestedTargets.filter { !existingIDs.contains($0.object.catalogID) }
    }

    private var currentLookupObject: DSOObject? {
        guard !lookupResults.isEmpty else { return nil }
        let safeIndex = min(max(lookupResultIndex, 0), lookupResults.count - 1)
        return lookupResults[safeIndex]
    }

    private var moonPhaseRequestKey: String {
        let siteIdentifier = resolvedSite?.id.uuidString ?? "no-site"
        let dateKey = plan.observingDate.formatted(date: .numeric, time: .omitted)
        return "\(siteIdentifier)-\(dateKey)"
    }

    private var weatherSourceRequestKey: String {
        guard let site = resolvedSite else { return "no-site" }
        let cachedCountry = [site.countryCode ?? "", site.countryName ?? ""].joined(separator: "-")
        return "\(site.id.uuidString)-\(site.latitude)-\(site.longitude)-\(cachedCountry)"
    }

    private var summaryStrip: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                summaryMetrics
            }
            .padding(.horizontal, 2)
        }
        .padding(.vertical, 2)
    }

    private var summaryMetrics: some View {
        Group {
            ObservationMetricChip(
                title: "Status",
                value: plan.hasLinkedLog ? "Log Linked" : "Saved",
                systemImage: plan.hasLinkedLog ? "checkmark.circle.fill" : "circle.dotted"
            )

            ObservationMetricChip(
                title: "Duration",
                value: "\(observationDurationHours.formatted(.number.precision(.fractionLength(1)))) hrs",
                systemImage: "clock"
            )

            ObservationMetricChip(
                title: "Targets",
                value: "\(plan.orderedTargets.count)",
                systemImage: "sparkles"
            )

            BortleMoonMetricChip(
                site: resolvedSite,
                moonPhase: moonPhaseSnapshot,
                isLoadingMoonPhase: isLoadingMoonPhase,
                message: moonPhaseMessage,
                backgroundStyle: .metallicBlue
            )
        }
    }

    private var configurationCard: some View {
        GroupBox("Plan Details") {
            VStack(alignment: .leading, spacing: 14) {
                TextField("Plan Name", text: $plan.title)

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { timeInputs }
                    VStack(alignment: .leading, spacing: 12) { timeInputs }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 16) { profileInputs }
                    VStack(alignment: .leading, spacing: 12) { profileInputs }
                }

                weatherSourceRow

                ViewThatFits(in: .horizontal) {
                    HStack(spacing: 12) { actionButtons }
                    VStack(alignment: .leading, spacing: 12) { actionButtons }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var timeInputs: some View {
        Group {
            labeledDateField("Date", selection: $plan.observingDate, components: .date, width: 220)
            labeledDateField("Start Time", selection: $plan.startTime, components: .hourAndMinute, width: 170)
            labeledDateField("End Time", selection: $plan.endTime, components: .hourAndMinute, width: 170)
        }
    }

    private func labeledDateField(
        _ title: String,
        selection: Binding<Date>,
        components: DatePickerComponents,
        width: CGFloat
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTypography.body)
                .foregroundStyle(.secondary)

            DatePicker("", selection: selection, displayedComponents: components)
                .labelsHidden()
                .datePickerStyle(.field)
                .frame(width: width, alignment: .leading)
        }
    }

    private var profileInputs: some View {
        Group {
            Picker("Observation Location", selection: Binding(get: { resolvedSite?.id }, set: { newValue in
                plan.site = allSites.first(where: { $0.id == newValue })
            })) {
                Text("None").tag(Optional<UUID>.none)
                ForEach(allSites) { site in
                    Text(site.name).tag(Optional(site.id))
                }
            }

            Picker("Telescope", selection: Binding(get: { resolvedEquipment?.id }, set: { newValue in
                plan.equipment = selectableEquipment.first(where: { $0.id == newValue })
            })) {
                Text("None").tag(Optional<UUID>.none)
                ForEach(selectableEquipment) { equipment in
                    Text(equipment.name).tag(Optional(equipment.id))
                }
            }

            TextField("Eye Piece", text: $plan.eyepiece)
            TextField("Other Equipment", text: $plan.otherEquipment)
        }
    }

    private var actionButtons: some View {
        Group {
            Button("Generate Suggestions") {
                generateSuggestions()
            }
            .disabled(resolvedSite == nil || allObjects.isEmpty)
            .controlSize(.large)

            Button("Put in Plan") {
                savePlanToDatabase()
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Button("Print Plan") {
                printPlan()
            }
            .controlSize(.large)

            Label(
                plan.hasLinkedLog
                    ? "Targets can be updated in the observation log one at a time."
                    : "Save the plan here, then send targets to the observation log one at a time.",
                systemImage: plan.hasLinkedLog ? "link" : "tray.and.arrow.down"
            )
            .font(AppTypography.body)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private var weatherSourceRow: some View {
        if resolvedSite != nil {
            Label {
                VStack(alignment: .leading, spacing: 3) {
                    Text(weatherSource.name)
                        .font(AppTypography.bodyEmphasized)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(weatherSourceSubtitle)
                        .font(AppTypography.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                if isResolvingObservationCountry {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Image(systemName: weatherSource.systemImage)
                        .foregroundStyle(Color.accentColor)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var discoveryCard: some View {
        GroupBox("Database Lookup") {
            VStack(alignment: .leading, spacing: 14) {
                Text("Search the object database and preview altitude, azimuth, magnitude, and object type for a manually chosen lookup time.")
                    .foregroundStyle(.secondary)

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 12) { discoveryInputs }
                    VStack(alignment: .leading, spacing: 12) { discoveryInputs }
                }

                if lookupResults.isEmpty {
                    Text("No catalog objects match `\(catalogQuery)`.")
                        .font(AppTypography.body)
                        .foregroundStyle(.secondary)
                } else if let currentLookupObject {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(alignment: .center, spacing: 12) {
                            Text(trimmedCatalogQuery.isEmpty ? "Database Object" : "Lookup Result")
                                .font(AppTypography.bodyEmphasized)

                            Spacer()

                            if lookupResults.count > 1 {
                                HStack(spacing: 10) {
                                    Button {
                                        lookupResultIndex = max(lookupResultIndex - 1, 0)
                                    } label: {
                                        Label("Previous", systemImage: "chevron.left")
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(lookupResultIndex == 0)

                                    Text("\(lookupResultIndex + 1) of \(lookupResults.count)")
                                        .font(AppTypography.body)
                                        .foregroundStyle(.secondary)

                                    Button {
                                        lookupResultIndex = min(lookupResultIndex + 1, lookupResults.count - 1)
                                    } label: {
                                        Label("Next", systemImage: "chevron.right")
                                    }
                                    .buttonStyle(.bordered)
                                    .disabled(lookupResultIndex >= lookupResults.count - 1)
                                }
                            }
                        }

                        if trimmedCatalogQuery.isEmpty {
                            Text("Showing one starter object at a time. Use search or the step controls to move through the list.")
                                .font(AppTypography.body)
                                .foregroundStyle(.secondary)
                        }

                        DatabaseLookupResultRowView(
                            object: currentLookupObject,
                            site: resolvedSite,
                            lookupDate: lookupTime,
                            onAdd: { addObject(currentLookupObject) }
                        )
                    }
                }

                if hasGeneratedSuggestions {
                    if visibleSuggestedTargets.isEmpty {
                        Text("No new suggestions are available for this plan right now.")
                            .font(AppTypography.body)
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            HStack {
                                Text("Suggested Targets")
                                    .font(AppTypography.bodyEmphasized)

                                Spacer()

                                Button("Add All") {
                                    addSuggestions(visibleSuggestedTargets)
                                }
                                .buttonStyle(.borderedProminent)
                            }

                            ForEach(visibleSuggestedTargets.prefix(6)) { suggestion in
                                suggestionRow(suggestion)
                            }
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var discoveryInputs: some View {
        Group {
            TextField("Catalog id or common name", text: $catalogQuery)

            DatePicker("Lookup Time", selection: $lookupTime, displayedComponents: [.hourAndMinute])
        }
    }

    private func suggestionRow(_ suggestion: PlannedTargetSuggestion) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.object.displayName)
                    .font(AppTypography.bodyEmphasized)
                Text(suggestion.summary)
                    .font(AppTypography.body)
                    .foregroundStyle(.secondary)
                Text("Best time \(suggestion.bestTime.formatted(date: .omitted, time: .shortened))")
                    .font(AppTypography.body)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 12)

            Button("Add") {
                addSuggestion(suggestion)
            }
            .buttonStyle(.bordered)
        }
        .padding(12)
        .controlSize(.large)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func generateSuggestions() {
        sanitizeReferencedModels()
        hasGeneratedSuggestions = true
        suggestedTargets = PlannerService.recommendTargets(for: plan, objects: allObjects)
        workspaceMessage = suggestedTargets.isEmpty
            ? "No viable targets found for the selected site and time window."
            : "Generated \(suggestedTargets.count) ranked targets for review."
    }

    private func addObject(_ object: DSOObject) {
        guard !plan.plannedTargets.contains(where: { $0.object?.catalogID == object.catalogID }) else {
            workspaceMessage = "`\(object.catalogID)` is already part of this observation plan."
            return
        }

        let target = PlannedTarget(
            orderIndex: plan.plannedTargets.count,
            plannerScore: 50,
            status: .planned,
            syncState: plan.hasLinkedLog ? .changed : .draft,
            object: object,
            nightPlan: plan
        )

        modelContext.insert(target)
        plan.plannedTargets.append(target)
        catalogQuery = ""
        persistPlanChanges()
        workspaceMessage = "Added `\(object.catalogID)` to the saved plan."
    }

    private func addSuggestion(_ suggestion: PlannedTargetSuggestion) {
        guard !plan.plannedTargets.contains(where: { $0.object?.catalogID == suggestion.object.catalogID }) else {
            workspaceMessage = "`\(suggestion.object.catalogID)` is already part of this observation plan."
            return
        }

        let target = PlannedTarget(
            orderIndex: plan.plannedTargets.count,
            plannerScore: suggestion.score,
            recommendedStart: suggestion.bestTime.addingTimeInterval(-1800),
            recommendedEnd: suggestion.bestTime.addingTimeInterval(1800),
            status: .planned,
            syncState: plan.hasLinkedLog ? .changed : .draft,
            object: suggestion.object,
            nightPlan: plan
        )

        modelContext.insert(target)
        plan.plannedTargets.append(target)
        persistPlanChanges()
        workspaceMessage = "Added suggested target `\(suggestion.object.catalogID)`."
    }

    private func addSuggestions(_ suggestions: [PlannedTargetSuggestion]) {
        let addedTargets = PlannerService.applySuggestions(suggestions, to: plan)
        addedTargets.forEach(modelContext.insert)
        persistPlanChanges()
        workspaceMessage = addedTargets.isEmpty
            ? "All suggested targets were already in the plan."
            : "Added \(addedTargets.count) suggested targets."
    }

    private func savePlanToDatabase() {
        do {
            try ObservationPlanService.savePlan(plan, context: modelContext)
            workspaceMessage = "Saved `\(plan.displayTitle)` to the plan database."
        } catch {
            workspaceMessage = AppIssueFormatter.persistenceMessage(for: "save the observation plan", error: error)
        }
    }

    private func printPlan() {
        ObservationPlanPrintService.printPlan(plan)
        workspaceMessage = "Opened the print panel for `\(plan.displayTitle)`."
    }

    private func alignTimeWindow(to newDate: Date) {
        let calendar = Calendar.current
        let startComponents = calendar.dateComponents([.hour, .minute, .second], from: plan.startTime)
        let endComponents = calendar.dateComponents([.hour, .minute, .second], from: plan.endTime)

        if let adjustedStart = calendar.date(bySettingHour: startComponents.hour ?? 21, minute: startComponents.minute ?? 0, second: startComponents.second ?? 0, of: newDate) {
            plan.startTime = adjustedStart
        }

        if let adjustedEnd = calendar.date(bySettingHour: endComponents.hour ?? 1, minute: endComponents.minute ?? 0, second: endComponents.second ?? 0, of: newDate) {
            if adjustedEnd <= plan.startTime {
                plan.endTime = adjustedEnd.addingTimeInterval(4 * 3600)
            } else {
                plan.endTime = adjustedEnd
            }
        }
    }

    private func alignLookupTime(to newDate: Date) {
        let calendar = Calendar.current
        let lookupComponents = calendar.dateComponents([.hour, .minute, .second], from: lookupTime)

        if let adjustedLookupTime = calendar.date(
            bySettingHour: lookupComponents.hour ?? 21,
            minute: lookupComponents.minute ?? 0,
            second: lookupComponents.second ?? 0,
            of: newDate
        ) {
            lookupTime = adjustedLookupTime
        }
    }

    private func sanitizeReferencedModels() {
        if plan.site != nil, resolvedSite == nil {
            plan.site = nil
        }

        if plan.equipment != nil, resolvedEquipment == nil {
            plan.equipment = nil
        }
    }

    private func persistPlanChanges() {
        do {
            try modelContext.save()
        } catch {
            workspaceMessage = AppIssueFormatter.persistenceMessage(for: "save plan changes", error: error)
        }
    }

    private var weatherSourceSubtitle: String {
        if let observationCountry {
            return "Weather source for \(observationCountry.countryName) observations • \(weatherSource.website)"
        }

        if isResolvingObservationCountry {
            return "Resolving country from the observation location."
        }

        if !weatherSourceMessage.isEmpty {
            return "Using global fallback while country lookup is unavailable • \(weatherSource.website)"
        }

        return "Weather source will adapt once an observation location is selected."
    }

    @MainActor
    private func refreshMoonPhase() async {
        guard let site = resolvedSite else {
            moonPhaseSnapshot = nil
            moonPhaseMessage = ""
            isLoadingMoonPhase = false
            return
        }

        isLoadingMoonPhase = true
        moonPhaseMessage = ""

        do {
            let requestDetails = MoonPhaseRequest(
                date: plan.observingDate,
                latitude: site.latitude,
                longitude: site.longitude,
                timeZoneIdentifier: site.timeZoneIdentifier
            )

            moonPhaseSnapshot = try await MoonPhaseService.fetchMoonPhase(for: requestDetails)
        } catch {
            moonPhaseSnapshot = nil
            moonPhaseMessage = AppIssueFormatter.remoteServiceMessage(service: "Moon phase lookup", error: error)
        }

        isLoadingMoonPhase = false
    }

    @MainActor
    private func refreshWeatherSource() async {
        guard let site = resolvedSite else {
            observationCountry = nil
            weatherSource = WeatherSourcePolicy.source(for: nil)
            weatherSourceMessage = ""
            isResolvingObservationCountry = false
            return
        }

        if let countryCode = normalizedText(site.countryCode), let countryName = normalizedText(site.countryName) {
            observationCountry = ObservationCountryDetails(countryCode: countryCode, countryName: countryName)
            weatherSource = WeatherSourcePolicy.source(for: countryCode)
            weatherSourceMessage = ""
            isResolvingObservationCountry = false
            return
        }

        isResolvingObservationCountry = true
        weatherSourceMessage = ""

        do {
            let request = ObservationCountryRequest(latitude: site.latitude, longitude: site.longitude)
            let resolvedCountry = try await ObservationCountryService.shared.resolveCountry(for: request)
            observationCountry = resolvedCountry
            weatherSource = WeatherSourcePolicy.source(for: resolvedCountry.countryCode)
            site.countryCode = resolvedCountry.countryCode
            site.countryName = resolvedCountry.countryName
            persistPlanChanges()
        } catch {
            observationCountry = nil
            weatherSource = WeatherSourcePolicy.source(for: nil)
            weatherSourceMessage = AppIssueFormatter.remoteServiceMessage(service: "Observation country lookup", error: error)
        }

        isResolvingObservationCountry = false
    }

    private func normalizedText(_ value: String?) -> String? {
        guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }

        return trimmed
    }
}

private struct DatabaseLookupResultRowView: View {
    let object: DSOObject
    let site: ObservingSite?
    let lookupDate: Date
    let onAdd: () -> Void

    private var skyPosition: LocalSkyPosition? {
        guard let site else { return nil }
        return SkyCoordinateService.localSkyPosition(for: object, site: site, at: lookupDate)
    }

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                details
                Spacer(minLength: 12)
                addButton
            }

            VStack(alignment: .leading, spacing: 12) {
                details
                addButton
            }
        }
        .padding(12)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var details: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(object.displayName)
                .font(AppTypography.bodyEmphasized)

            Text("Type \(object.objectType.displayName) • Magnitude \(object.magnitude.formatted(.number.precision(.fractionLength(1))))")
                .font(AppTypography.body)
                .foregroundStyle(.secondary)

            if let skyPosition {
                Text(
                    "Altitude \(skyPosition.altitudeDegrees.formatted(.number.precision(.fractionLength(1))))° • Azimuth \(skyPosition.azimuthDegrees.formatted(.number.precision(.fractionLength(1))))° \(skyPosition.magneticCardinalDirection)"
                )
                .font(AppTypography.body)
                .foregroundStyle(.secondary)
            } else {
                Text("Select an observing site to calculate altitude and azimuth.")
                    .font(AppTypography.body)
                    .foregroundStyle(.secondary)
            }

            Text("\(object.catalogID) • \(object.constellation)")
                .font(AppTypography.body)
                .foregroundStyle(.tertiary)
        }
    }

    private var addButton: some View {
        Button("Add Target") {
            onAdd()
        }
        .buttonStyle(.bordered)
        .controlSize(.large)
    }
}

private struct ObservationObjectInsightView: View {
    let object: DSOObject
    let site: ObservingSite?
    let observationDate: Date
    let highlightRecommendedWindow: Bool
    let recommendedStart: Date?
    let recommendedEnd: Date?

    private var timingEstimate: VesperaObservationTimingEstimate {
        VesperaObservationTimingService.estimate(for: object)
    }

    private var skyPosition: LocalSkyPosition? {
        guard let site else { return nil }
        return SkyCoordinateService.localSkyPosition(for: object, site: site, at: observationDate)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("\(object.catalogID) • \(object.objectType.displayName) • \(object.constellation)")
                .font(AppTypography.body)
                .foregroundStyle(.secondary)

            Text("RA \(object.rightAscensionDisplay) • Dec \(object.declinationDisplay)")
                .font(AppTypography.body)
                .foregroundStyle(.secondary)

            if let skyPosition {
                Text(
                    "Altitude \(skyPosition.altitudeDegrees.formatted(.number.precision(.fractionLength(1))))° • Azimuth \(skyPosition.azimuthDegrees.formatted(.number.precision(.fractionLength(1))))° \(skyPosition.magneticCardinalDirection)"
                )
                    .font(AppTypography.body)
                    .foregroundStyle(.secondary)
            } else {
                Text("Select a site to calculate local sky position.")
                    .font(AppTypography.body)
                    .foregroundStyle(.secondary)
            }

            Text("Brightness \(object.magnitude.formatted(.number.precision(.fractionLength(1)))) • Size \(Int(object.angularSizeArcMinutes))′")
                .font(AppTypography.body)
                .foregroundStyle(.secondary)

            if highlightRecommendedWindow, let recommendedStart, let recommendedEnd {
                Text("Recommended window \(recommendedStart.formatted(date: .omitted, time: .shortened)) - \(recommendedEnd.formatted(date: .omitted, time: .shortened))")
                    .font(AppTypography.body)
                    .foregroundStyle(.secondary)
            }

            Text("Vespera shortest \(timingEstimate.withoutDualBandFilter.shortestMinutes) min • Median \(timingEstimate.withoutDualBandFilter.medianMinutes) min")
                .font(AppTypography.body)
                .foregroundStyle(.secondary)
        }
    }
}

private struct ObservationMetricChip: View {
    let title: String
    let value: String
    let systemImage: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(AppTypography.bodyEmphasized)
                .foregroundStyle(Color.accentColor)

            VStack(alignment: .leading, spacing: 2) {
                Text(title.uppercased())
                    .font(AppTypography.bodyEmphasized)
                    .foregroundStyle(.tertiary)

                Text(value)
                    .font(AppTypography.bodyEmphasized)
                    .lineLimit(2)
                    .minimumScaleFactor(0.85)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

private struct BortleMoonMetricChip: View {
    let site: ObservingSite?
    let moonPhase: MoonPhaseSnapshot?
    let isLoadingMoonPhase: Bool
    let message: String
    let backgroundStyle: WorkspaceBackgroundStyle

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("BORTLE SCALE")
                .font(AppTypography.bodyEmphasized)
                .foregroundStyle(.tertiary)

            Text(site?.bortleSummary ?? "Select a site")
                .font(AppTypography.bodyEmphasized)
                .lineLimit(2)
                .minimumScaleFactor(0.85)

            if site != nil {
                HStack(spacing: 8) {
                    if isLoadingMoonPhase {
                        ProgressView()
                            .controlSize(.small)
                    } else {
                        if let moonPhase {
                            CraterMoonPhaseIconButton(
                                snapshot: moonPhase,
                                backgroundStyle: backgroundStyle,
                                size: 26,
                                locationName: site?.name,
                                bortleText: site?.bortleSummary
                            )
                        } else {
                            Image(systemName: "moon.stars.fill")
                                .foregroundStyle(Color.accentColor)
                        }
                    }

                    Text(moonLineText)
                        .font(AppTypography.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.85)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var moonLineText: String {
        if let moonPhase {
            return moonPhase.phaseName
        }

        if isLoadingMoonPhase {
            return "Loading moon phase"
        }

        if !message.isEmpty {
            return "Moon phase unavailable"
        }

        return "Moon phase pending"
    }
}
