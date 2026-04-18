import SwiftData
import SwiftUI
#if canImport(AppKit)
import AppKit
import UniformTypeIdentifiers
#endif

private struct SingleNightTargetChoice: Identifiable, Hashable {
    enum SourceKind: String {
        case deepSky
        case transient
    }

    let id: String
    let sourceKind: SourceKind
    let identifier: String
    let name: String
    let typeName: String
    let constellation: String
    let sourceLabel: String
    let rightAscensionHours: Double
    let declinationDegrees: Double
    let magnitude: Double?

    init(object: DSOObject) {
        id = "dso:\(object.catalogID)"
        sourceKind = .deepSky
        identifier = object.catalogID
        name = object.displayName
        typeName = object.objectType.displayName
        constellation = object.constellation
        sourceLabel = object.sourceDisplayName
        rightAscensionHours = object.rightAscensionHours
        declinationDegrees = object.declinationDegrees
        magnitude = object.magnitude
    }

    init(transient: TransientFeedItem) {
        id = "transient:\(transient.feedID)"
        sourceKind = .transient
        identifier = transient.feedID
        name = transient.displayName
        typeName = transient.transientType.displayName
        constellation = transient.constellation
        sourceLabel = transient.sourceName
        rightAscensionHours = transient.rightAscensionHours
        declinationDegrees = transient.declinationDegrees
        magnitude = transient.magnitude
    }

    var rightAscensionDisplay: String {
        let hours = Int(rightAscensionHours)
        let minutesValue = (rightAscensionHours - Double(hours)) * 60
        let minutes = Int(minutesValue)
        let seconds = Int(((minutesValue - Double(minutes)) * 60).rounded())
        return String(format: "%02dh %02dm %02ds", hours, minutes, seconds)
    }

    var declinationDisplay: String {
        let sign = declinationDegrees >= 0 ? "+" : "-"
        let absolute = abs(declinationDegrees)
        let degrees = Int(absolute)
        let minutesValue = (absolute - Double(degrees)) * 60
        let minutes = Int(minutesValue)
        let seconds = Int(((minutesValue - Double(minutes)) * 60).rounded())
        return String(format: "%@%02d° %02d′ %02d″", sign, degrees, minutes, seconds)
    }

    var magnitudeSummary: String {
        guard let magnitude else { return "Magnitude unavailable" }
        return "Magnitude \(magnitude.formatted(.number.precision(.fractionLength(1))))"
    }

    var apparentMagnitudeSummary: String {
        guard let magnitude else { return "Apparent magnitude unavailable" }
        return "Apparent magnitude \(magnitude.formatted(.number.precision(.fractionLength(1))))"
    }

    var shortenedName: String {
        let maximumLength = 34
        guard name.count > maximumLength else { return name }
        let trimmedPrefix = String(name.prefix(maximumLength))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return "\(trimmedPrefix)..."
    }

    func coordinates(at date: Date) -> SingleNightEquatorialCoordinate {
        let sourceCoordinates = SingleNightEquatorialCoordinate(
            rightAscensionHours: rightAscensionHours,
            declinationDegrees: declinationDegrees
        )

        switch sourceKind {
        case .deepSky:
            return sourceCoordinates.precessedFromJ2000(to: date)
        case .transient:
            return sourceCoordinates
        }
    }
}

private struct SingleNightEquatorialCoordinate {
    let rightAscensionHours: Double
    let declinationDegrees: Double

    var rightAscensionDisplay: String {
        let totalSeconds = Int((Self.normalizedHours(rightAscensionHours) * 3600).rounded()) % 86_400
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        return String(format: "%02dh %02dm %02ds", hours, minutes, seconds)
    }

    var declinationDisplay: String {
        let sign = declinationDegrees >= 0 ? "+" : "-"
        let totalArcSeconds = Int((abs(declinationDegrees) * 3600).rounded())
        let degrees = totalArcSeconds / 3600
        let minutes = (totalArcSeconds % 3600) / 60
        let seconds = totalArcSeconds % 60
        return String(format: "%@%02d° %02d′ %02d″", sign, degrees, minutes, seconds)
    }

    func precessedFromJ2000(to date: Date) -> Self {
        let julianCenturies = (Self.julianDay(for: date) - 2_451_545.0) / 36_525.0
        guard abs(julianCenturies) > 0.000_000_1 else { return self }

        let t = julianCenturies
        let zeta = Self.arcSecondsToRadians((2306.2181 * t) + (0.30188 * t * t) + (0.017998 * t * t * t))
        let z = Self.arcSecondsToRadians((2306.2181 * t) + (1.09468 * t * t) + (0.018203 * t * t * t))
        let theta = Self.arcSecondsToRadians((2004.3109 * t) - (0.42665 * t * t) - (0.041833 * t * t * t))

        let rightAscensionRadians = Self.degreesToRadians(rightAscensionHours * 15)
        let declinationRadians = Self.degreesToRadians(declinationDegrees)
        let shiftedRightAscension = rightAscensionRadians + zeta

        let a = cos(declinationRadians) * sin(shiftedRightAscension)
        let b = (cos(theta) * cos(declinationRadians) * cos(shiftedRightAscension)) - (sin(theta) * sin(declinationRadians))
        let c = (sin(theta) * cos(declinationRadians) * cos(shiftedRightAscension)) + (cos(theta) * sin(declinationRadians))

        let precessedRightAscension = atan2(a, b) + z
        let precessedDeclination = asin(c)

        return SingleNightEquatorialCoordinate(
            rightAscensionHours: Self.normalizedDegrees(Self.radiansToDegrees(precessedRightAscension)) / 15,
            declinationDegrees: Self.radiansToDegrees(precessedDeclination)
        )
    }

    private static func julianDay(for date: Date) -> Double {
        (date.timeIntervalSince1970 / 86_400) + 2_440_587.5
    }

    private static func degreesToRadians(_ value: Double) -> Double {
        value * .pi / 180
    }

    private static func radiansToDegrees(_ value: Double) -> Double {
        value * 180 / .pi
    }

    private static func arcSecondsToRadians(_ value: Double) -> Double {
        degreesToRadians(value / 3600)
    }

    private static func normalizedDegrees(_ value: Double) -> Double {
        var adjusted = value.truncatingRemainder(dividingBy: 360)
        if adjusted < 0 { adjusted += 360 }
        return adjusted
    }

    private static func normalizedHours(_ value: Double) -> Double {
        var adjusted = value.truncatingRemainder(dividingBy: 24)
        if adjusted < 0 { adjusted += 24 }
        return adjusted
    }
}

private struct SingleNightTargetVisibility {
    let visibleFrom: Date
    let zenithDate: Date
    let zenithAltitudeDegrees: Double
    let skyPosition: LocalSkyPosition
}

private struct SingleNightTargetTypeFilterOption: Identifiable {
    let name: String
    let count: Int

    var id: String { name }
}

private enum ObservationMeridiem: String, CaseIterable, Identifiable {
    case am = "AM"
    case pm = "PM"

    var id: String { rawValue }
}

private enum SingleNightTargetSortMode: String, CaseIterable, Identifiable, Equatable {
    case firstViewable
    case zenith
    case targetIdentifier
    case targetName

    var id: String { rawValue }

    var label: String {
        switch self {
        case .firstViewable:
            return "First View"
        case .zenith:
            return "Zenith Time"
        case .targetIdentifier:
            return "Target ID"
        case .targetName:
            return "Target Name"
        }
    }
}

private struct SingleNightLifecycleModifier: ViewModifier {
    let siteIDs: [UUID]
    let objectIDs: [String]
    let transientIDs: [String]
    let selectedLocationID: UUID?
    let observationDateTime: Date
    let observationTimeZoneIdentifier: String
    let observationMeridiem: ObservationMeridiem
    let selectedTargetTypeNames: Set<String>
    let dsoLimitingMagnitudeText: String
    let targetSkyLimitTexts: [String]
    let selectedTargetID: String?
    let addedTargetIDs: [String]
    let weatherSourceRequestKey: String
    let observationWeatherRequestKey: String
    let onAppearAction: () -> Void
    let onSitesChanged: () -> Void
    let onTargetDatabaseChanged: () -> Void
    let onSelectedLocationChanged: () -> Void
    let onObservationDateTimeChanged: () -> Void
    let onFilterInputsChanged: () -> Void
    let onObservationMeridiemChanged: () -> Void
    let onSelectedTargetTypesChanged: () -> Void
    let onSelectedTargetChanged: () -> Void
    let onAddedTargetsChanged: () -> Void
    let onRefreshWeatherSource: () async -> Void
    let onRefreshObservationWeather: () async -> Void
    let onDisappearAction: () -> Void

    func body(content: Content) -> some View {
        content
            .onAppear(perform: onAppearAction)
            .onChange(of: siteIDs) { _, _ in onSitesChanged() }
            .onChange(of: objectIDs) { _, _ in onTargetDatabaseChanged() }
            .onChange(of: transientIDs) { _, _ in onTargetDatabaseChanged() }
            .onChange(of: selectedLocationID) { _, _ in onSelectedLocationChanged() }
            .onChange(of: observationDateTime) { _, _ in onObservationDateTimeChanged() }
            .onChange(of: observationTimeZoneIdentifier) { _, _ in onFilterInputsChanged() }
            .onChange(of: observationMeridiem) { _, _ in onObservationMeridiemChanged() }
            .onChange(of: selectedTargetTypeNames) { _, _ in onSelectedTargetTypesChanged() }
            .onChange(of: dsoLimitingMagnitudeText) { _, _ in onFilterInputsChanged() }
            .onChange(of: targetSkyLimitTexts) { _, _ in onFilterInputsChanged() }
            .onChange(of: selectedTargetID) { _, _ in onSelectedTargetChanged() }
            .onChange(of: addedTargetIDs) { _, _ in onAddedTargetsChanged() }
            .task(id: weatherSourceRequestKey) { await onRefreshWeatherSource() }
            .task(id: observationWeatherRequestKey) { await onRefreshObservationWeather() }
            .onDisappear(perform: onDisappearAction)
    }
}

struct SingleNightObservationWorkspaceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRuntimeState.self) private var runtimeState

    private enum ObservationTimeField: Hashable {
        case time
    }

    @Query(sort: \ObservingSite.name) private var sites: [ObservingSite]
    @Query(sort: \DSOObject.primaryDesignation) private var objects: [DSOObject]
    @Query(sort: \TransientFeedItem.displayName) private var transientItems: [TransientFeedItem]
    @Binding var selectedSection: SidebarSection

    @State private var selectedLocationID: UUID?
    @State private var selectedTargetID: String?
    @State private var addedTargetIDs: [String] = []
    @State private var observationDateTime = Date()
    @State private var observationTimeZoneIdentifier = TimeZone.current.identifier
    @State private var telescopeCaptureStartOverrideDate: Date?
    @State private var observationTimeText = ""
    @State private var observationMeridiem = ObservationMeridiem.am
    @State private var dsoLimitingMagnitudeText = "8"
    @State private var targetAzimuthLowLimitText = ""
    @State private var targetAzimuthHighLimitText = ""
    @State private var targetAltitudeLowLimitText = ""
    @State private var targetAltitudeHighLimitText = ""
    @State private var selectedTargetTypeNames = Set<String>()
    @State private var targetSortMode = SingleNightTargetSortMode.firstViewable
    @State private var visibleTargetMetadata: [String: SingleNightTargetVisibility] = [:]
    @State private var usesVisibilityFilter = false
    @State private var locationPickerIsPresented = false
    @State private var locationPickerSelectionID: UUID?
    @State private var hasInitializedTargetTypeSelection = false
    @State private var didManuallyAdjustTargetTypes = false
    @State private var isRefreshingTargetDatabase = false
    @State private var saveListPromptIsPresented = false
    @State private var saveListNameDraft = ""
    @State private var savedListStatusMessage: String?
    @State private var visibilityRecomputeTask: Task<Void, Never>?
    @State private var observationCountry: ObservationCountryDetails?
    @State private var weatherSource = WeatherSourcePolicy.source(for: nil)
    @State private var observationWeatherSnapshot: ObservationWeatherSnapshot?
    @State private var isResolvingObservationCountry = false
    @State private var isLoadingObservationWeather = false
    @State private var weatherSourceMessage = ""
    @State private var observationWeatherMessage = ""
    @FocusState private var focusedObservationTimeField: ObservationTimeField?
    private let compactBodyFont = Font.system(size: 13, weight: .regular, design: .rounded)
    private let compactStrongFont = Font.system(size: 14, weight: .semibold, design: .rounded)
    private let compactSelectorLabelFont = Font.system(size: 12, weight: .semibold, design: .rounded)
    private let compactCaptionFont = Font.system(size: 11, weight: .semibold, design: .rounded)
    private let heroMetricTitleFont = Font.system(size: 12, weight: .bold, design: .rounded)
    private let heroMetricBodyFont = Font.system(size: 14, weight: .semibold, design: .rounded)
    private let heroMetricCaptionFont = Font.system(size: 12, weight: .semibold, design: .rounded)
    private let cardHeadingTitleFont = Font.system(size: 16, weight: .bold, design: .rounded)
    private let labelColor = Color.yellow
    private let observationTimeTextColor = Color(red: 0.24, green: 0.58, blue: 1.0)
    private let sidebarWidth: CGFloat = 320
    private let contentCardMaxWidth: CGFloat = .infinity
    private let targetFeedVisibleHeight: CGFloat = 86
    private let heroMetricWidth: CGFloat = 248
    private let heroMetricHeight: CGFloat = 116
    private let transientFilterLabel = "Transient"
    private static let defaultDSOLimitingMagnitude = 8.0
    private static let minimumDSOLimitingMagnitude = -2.0
    private static let maximumDSOLimitingMagnitude = 16.0
    private static let defaultTargetAzimuthLowLimit = 0.0
    private static let defaultTargetAzimuthHighLimit = 360.0
    private static let defaultTargetAltitudeLowLimit = 0.0
    private static let defaultTargetAltitudeHighLimit = 90.0
    private static let minimumTargetAzimuthLimit = 0.0
    private static let maximumTargetAzimuthLimit = 360.0
    private static let minimumTargetAltitudeLimit = -90.0
    private static let maximumTargetAltitudeLimit = 90.0

    var body: some View {
        singleNightRoot
    }

    private var singleNightRoot: some View {
        singleNightGeometry
            .modifier(singleNightLifecycleModifier)
            .sheet(isPresented: $saveListPromptIsPresented) {
                SingleNightSaveListSheet(
                    title: "Save for Multi-Night Observation",
                    subtitle: "Name this target list and store it in the Saved Lists Database for multi-night observation planning.",
                    locationName: selectedLocation?.name,
                    targetCount: addedTargets.count,
                    name: $saveListNameDraft
                ) { savedName in
                    saveCurrentListForLaterUse(named: savedName)
                }
            }
            .sheet(isPresented: $locationPickerIsPresented) {
                SingleNightLocationPickerSheet(
                    sites: sortedLocations,
                    selectedLocationID: $locationPickerSelectionID,
                    currentDefaultLocationID: LocationPreferenceStore.defaultSiteID(),
                    onCancel: {
                        locationPickerIsPresented = false
                    },
                    onSetDefault: { siteID in
                        applyLocationSelection(siteID, setAsDefault: true)
                        locationPickerIsPresented = false
                    }
                )
            }
            .alert("Saved Lists", isPresented: savedListAlertIsPresented) {
                Button("OK") {
                    savedListStatusMessage = nil
                }
            } message: {
                Text(savedListStatusMessage ?? "")
            }
    }

    private var singleNightLifecycleModifier: SingleNightLifecycleModifier {
        SingleNightLifecycleModifier(
            siteIDs: sites.map(\.id),
            objectIDs: objects.map(\.catalogID),
            transientIDs: transientItems.map(\.feedID),
            selectedLocationID: selectedLocationID,
            observationDateTime: observationDateTime,
            observationTimeZoneIdentifier: observationTimeZoneIdentifier,
            observationMeridiem: observationMeridiem,
            selectedTargetTypeNames: selectedTargetTypeNames,
            dsoLimitingMagnitudeText: dsoLimitingMagnitudeText,
            targetSkyLimitTexts: targetSkyLimitTexts,
            selectedTargetID: selectedTargetID,
            addedTargetIDs: addedTargetIDs,
            weatherSourceRequestKey: weatherSourceRequestKey,
            observationWeatherRequestKey: observationWeatherRequestKey,
            onAppearAction: handleSingleNightAppear,
            onSitesChanged: handleSitesChanged,
            onTargetDatabaseChanged: handleTargetDatabaseChanged,
            onSelectedLocationChanged: handleSelectedLocationChanged,
            onObservationDateTimeChanged: handleObservationDateTimeChanged,
            onFilterInputsChanged: handleFilterInputsChanged,
            onObservationMeridiemChanged: { applyObservationTimeEntry() },
            onSelectedTargetTypesChanged: handleSelectedTargetTypesChanged,
            onSelectedTargetChanged: persistSingleNightDraft,
            onAddedTargetsChanged: persistSingleNightDraft,
            onRefreshWeatherSource: refreshWeatherSource,
            onRefreshObservationWeather: refreshObservationWeather,
            onDisappearAction: cancelVisibilityRecompute
        )
    }

    private var singleNightGeometry: some View {
        GeometryReader(content: singleNightGeometryContent)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func singleNightGeometryContent(_ proxy: GeometryProxy) -> AnyView {
        AnyView(singleNightContent(proxy: proxy))
    }

    @ViewBuilder
    private func singleNightContent(proxy: GeometryProxy) -> some View {
        VStack(spacing: 8) {
            heroSection
                .padding(.horizontal, 18)
                .padding(.top, 6)

            if proxy.size.width >= 760 {
                wideSingleNightContent(proxy: proxy)
            } else {
                compactSingleNightContent(proxy: proxy)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func wideSingleNightContent(proxy: GeometryProxy) -> some View {
        let sidebarHeight = sidebarHeight(for: proxy.size.height)

        return HStack(alignment: .top, spacing: 12) {
            currentListSidebar(height: sidebarHeight)
                .frame(width: sidebarWidth)

            VStack(alignment: .leading, spacing: 10) {
                centeredTargetFilterCard(maxHeight: targetFilterMaximumHeight(for: proxy.size.height, compact: false))
                centeredTargetSelectionCard
            }
            .padding(.trailing, 18)
            .frame(maxWidth: .infinity, minHeight: sidebarHeight, maxHeight: sidebarHeight, alignment: .topLeading)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func compactSingleNightContent(proxy: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            currentListSidebar(height: max(proxy.size.height * 0.30, 260))
            centeredTargetFilterCard(maxHeight: targetFilterMaximumHeight(for: proxy.size.height, compact: true))
            centeredTargetSelectionCard
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 52)
        .frame(maxWidth: 1180, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func handleSingleNightAppear() {
        restoreSingleNightDraft()
        applyPendingTelescopeCaptureStartIfNeeded()
        syncSelectedLocation()
        syncObservationTimeZoneFromLocation()
        syncObservationTimeFieldsFromDate(force: telescopeCaptureStartOverrideDate != nil)
        syncSelectedTargetTypes()
        recomputeVisibleTargets()
        persistSingleNightDraft()
    }

    private func handleSitesChanged() {
        syncSelectedLocation()
        syncObservationTimeZoneFromLocation()
        recomputeVisibleTargets()
        persistSingleNightDraft()
    }

    private func handleTargetDatabaseChanged() {
        syncSelectedTargetTypes()
        recomputeVisibleTargets()
        persistSingleNightDraft()
    }

    private func handleSelectedLocationChanged() {
        syncObservationTimeZoneFromLocation()
        recomputeVisibleTargets()
        persistSingleNightDraft()
    }

    private func handleObservationDateTimeChanged() {
        let normalizedDate = normalizedObservationDate(observationDateTime)
        if normalizedDate != observationDateTime {
            observationDateTime = normalizedDate
            return
        }

        clearTelescopeCaptureStartOverrideIfNeeded()
        syncObservationTimeFieldsFromDate()
        scheduleVisibleTargetRecompute()
        persistSingleNightDraft()
    }

    private func handleSelectedTargetTypesChanged() {
        syncSelectedTarget()
        persistSingleNightDraft()
    }

    private func handleFilterInputsChanged() {
        scheduleVisibleTargetRecompute()
        persistSingleNightDraft()
    }

    private func cancelVisibilityRecompute() {
        visibilityRecomputeTask?.cancel()
    }

    private func sidebarHeight(for availableHeight: CGFloat) -> CGFloat {
        min(max(availableHeight - 292, 300), max(300, availableHeight - 156))
    }

    private func targetFilterMaximumHeight(for availableHeight: CGFloat, compact: Bool) -> CGFloat {
        let reservedHeight: CGFloat = compact ? 540 : 430
        let minimumHeight: CGFloat = compact ? 300 : 300
        let maximumHeight: CGFloat = compact ? 420 : 390
        return min(max(availableHeight - reservedHeight, minimumHeight), maximumHeight)
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    heroLocationControl
                        .frame(width: 188, alignment: .topLeading)

                    VStack(alignment: .center, spacing: 4) {
                        Text("Single Night Observation")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.yellow)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .multilineTextAlignment(.center)
                            .shadow(color: Color.black.opacity(0.35), radius: 8, y: 2)

                        Text("Use the default location, then choose a target from the combined object database and review its live sky position.")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.92))
                            .frame(maxWidth: 760, alignment: .center)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.center)

                        heroObservationInfoBlocks
                            .frame(maxWidth: 760, alignment: .center)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    singleNightMoonInfoBlock
                        .frame(width: 212, alignment: .trailing)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)

                VStack(alignment: .leading, spacing: 6) {
                    heroLocationControl
                        .frame(maxWidth: 260, alignment: .leading)

                    Text("Single Night Observation")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.yellow)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .shadow(color: Color.black.opacity(0.35), radius: 8, y: 2)

                    Text("Use the default location, then choose a target from the combined object database and review its live sky position.")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                        .frame(maxWidth: 760, alignment: .center)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.center)

                    heroObservationInfoBlocks
                        .frame(maxWidth: 760, alignment: .center)

                    singleNightMoonInfoBlock
                        .frame(maxWidth: 620, alignment: .trailing)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity)

            HStack {
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(singleNightCardBackground(cornerRadius: 28, fill: .regularMaterial))
        .shadow(color: .black.opacity(0.10), radius: 18, y: 10)
    }

    private var heroLocationControl: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("LOCATION")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(labelColor.opacity(0.84))

            Text(selectedLocation?.name ?? (sites.isEmpty ? "No saved location" : "Choose a location"))
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.94))
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .fixedSize(horizontal: false, vertical: true)

            if sites.isEmpty {
                Button {
                    cancelSingleNightPlan()
                } label: {
                    Label("Cancel", systemImage: "xmark")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            } else {
                HStack(spacing: 6) {
                    Button {
                        presentLocationPicker()
                    } label: {
                        Label("Change", systemImage: "location")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.mini)

                    Button {
                        cancelSingleNightPlan()
                    } label: {
                        Text("Cancel")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(singleNightCardBackground(cornerRadius: 18, fill: .thinMaterial))
    }

    private func currentListSidebar(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "list.bullet.rectangle.portrait")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(labelColor.opacity(0.92))

                Text("Current List Database")
                    .font(compactStrongFont)
                    .foregroundStyle(labelColor.opacity(0.92))
                    .lineLimit(1)
            }

            if addedTargets.isEmpty {
                Text("Added target identifiers and types will appear here.")
                    .font(compactBodyFont)
                    .foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(addedTargets) { target in
                            VStack(alignment: .leading, spacing: 3) {
                                Text("\(target.identifier) • \(target.typeName)")
                                    .font(compactStrongFont)
                                    .foregroundStyle(.white.opacity(0.95))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)

                                Text("Source: \(target.sourceLabel)")
                                    .font(compactCaptionFont)
                                    .foregroundStyle(.white.opacity(0.72))
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.72)
                            }
                            .padding(.horizontal, 9)
                            .padding(.vertical, 8)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(singleNightCardBackground(cornerRadius: 14, fill: .thinMaterial))
                            .overlay(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .stroke(
                                        selectedTargetID == target.id
                                            ? Color.accentColor.opacity(0.50)
                                            : Color.clear,
                                        lineWidth: 1.2
                                    )
                            )
                            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                            .onTapGesture {
                                selectedTargetID = target.id
                            }
                            .contextMenu {
                                Button("Remove", systemImage: "trash") {
                                    removeTargetFromCurrentList(target.id)
                                }

                                Button("Move Up", systemImage: "arrow.up") {
                                    moveTargetInCurrentList(target.id, offset: -1)
                                }
                                .disabled(!canMoveTarget(target.id, offset: -1))

                                Button("Move Down", systemImage: "arrow.down") {
                                    moveTargetInCurrentList(target.id, offset: 1)
                                }
                                .disabled(!canMoveTarget(target.id, offset: 1))
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .scrollTargetLayout()
                }
                .scrollIndicators(.visible)
                .scrollTargetBehavior(.viewAligned)
                .frame(maxHeight: .infinity, alignment: .top)
            }

            Spacer(minLength: 0)

            VStack(spacing: 8) {
                Button {
                    promptSaveCurrentListForLaterUse()
                } label: {
                    Label {
                        Text("Save for Multi-Night Observation")
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    } icon: {
                        Image(systemName: "tray.and.arrow.down")
                    }
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(addedTargets.isEmpty)

                Button {
                    printCurrentList()
                } label: {
                    Label("Print", systemImage: "printer")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(addedTargets.isEmpty)

                Button {
                    saveCurrentListAsPDF()
                } label: {
                    Label("Save to PDF", systemImage: "doc.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .disabled(addedTargets.isEmpty)

                Button("Clear All", role: .destructive) {
                    clearCurrentList()
                }
                .buttonStyle(.bordered)
                .disabled(addedTargets.isEmpty)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
        .background(singleNightCardBackground())
    }

    private var centeredTargetSelectionCard: some View {
        targetSelectionCard
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func centeredTargetFilterCard(maxHeight: CGFloat) -> some View {
        targetFilterCard(maxHeight: maxHeight)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private func targetFilterCard(maxHeight: CGFloat) -> some View {
        ScrollView(.vertical) {
            targetFilterCardContent
                .padding(10)
        }
        .scrollIndicators(.visible)
        .frame(maxWidth: contentCardMaxWidth, maxHeight: maxHeight, alignment: .topLeading)
        .background(singleNightCardBackground())
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private var targetFilterCardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    cardHeading(
                        title: "Target Database Filters",
                        centered: true
                    )

                    VStack(alignment: .trailing, spacing: 8) {
                        Text(lastTargetDatabaseUpdateText)
                            .font(compactBodyFont)
                            .foregroundStyle(.white.opacity(0.86))
                            .multilineTextAlignment(.trailing)

                        Button {
                            Task {
                                await refreshTargetDatabase()
                            }
                        } label: {
                            if isRefreshingTargetDatabase {
                                Label("Refreshing…", systemImage: "arrow.triangle.2.circlepath")
                            } else {
                                Label("Refresh Target Database", systemImage: "arrow.clockwise")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isRefreshingTargetDatabase)
                    }
                    .frame(minWidth: 220, alignment: .trailing)
                }

                VStack(alignment: .leading, spacing: 10) {
                    cardHeading(
                        title: "Target Database Filters",
                        centered: true
                    )

                    HStack {
                        Text(lastTargetDatabaseUpdateText)
                            .font(compactBodyFont)
                            .foregroundStyle(.white.opacity(0.86))
                            .fixedSize(horizontal: false, vertical: true)
                        Spacer(minLength: 0)
                    }

                    HStack {
                        Spacer(minLength: 0)
                        Button {
                            Task {
                                await refreshTargetDatabase()
                            }
                        } label: {
                            if isRefreshingTargetDatabase {
                                Label("Refreshing…", systemImage: "arrow.triangle.2.circlepath")
                            } else {
                                Label("Refresh Target Database", systemImage: "arrow.clockwise")
                            }
                        }
                        .buttonStyle(.bordered)
                        .disabled(isRefreshingTargetDatabase)
                    }
                }
            }

            telescopeImagingStartTimeControl
            targetSortOptionsControl

            if availableTargetTypeOptions.isEmpty {
                Text("No target types are available yet.")
                    .font(compactBodyFont)
                    .foregroundStyle(.white.opacity(0.84))
            } else {
                LazyVGrid(
                    columns: [
                        GridItem(.adaptive(minimum: 160), spacing: 10)
                    ],
                    alignment: .leading,
                    spacing: 6
                ) {
                    ForEach(availableTargetTypeOptions) { option in
                        Toggle("\(option.name) (\(option.count))", isOn: targetTypeBinding(for: option.name))
                            .toggleStyle(.checkbox)
                            .font(compactBodyFont)
                            .foregroundStyle(.white.opacity(0.92))
                    }
                }
            }
        }
        .frame(maxWidth: contentCardMaxWidth, alignment: .leading)
    }

    private var telescopeImagingStartTimeControl: some View {
        VStack(alignment: .center, spacing: 8) {
            Text("Observation Location Restraints and Telescope Beginning of Observation Window")
                .font(compactSelectorLabelFont)
                .foregroundStyle(labelColor.opacity(0.92))
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.82)
                .frame(maxWidth: .infinity, alignment: .center)

            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 190), spacing: 12, alignment: .center)
                ],
                alignment: .center,
                spacing: 8
            ) {
                observationDateEntry
                telescopeImagingStartFields
                dsoLimitingMagnitudeControl
                targetAzimuthLimitControl
                targetAltitudeLimitControl
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(singleNightCardBackground(cornerRadius: 18, fill: .ultraThinMaterial))
    }

    private var telescopeImagingStartFields: some View {
        HStack(alignment: .top, spacing: 8) {
            observationTimeEntry
                .frame(width: 116, alignment: .leading)

            observationMeridiemMenu
        }
        .frame(minWidth: 170, maxWidth: .infinity, alignment: .center)
    }

    private var dsoLimitingMagnitudeControl: some View {
        VStack(alignment: .center, spacing: 6) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .center, spacing: 10) {
                    Text("DSO Limiting Magnitude")
                        .font(compactSelectorLabelFont)
                        .foregroundStyle(labelColor.opacity(0.92))
                        .multilineTextAlignment(.center)

                    TextField("8", text: $dsoLimitingMagnitudeText)
                        .textFieldStyle(.roundedBorder)
                        .foregroundStyle(observationTimeTextColor)
                        .frame(width: 72)
                        .onSubmit {
                            normalizeDSOLimitingMagnitudeText()
                        }

                    Stepper(
                        value: dsoLimitingMagnitudeBinding,
                        in: Self.minimumDSOLimitingMagnitude ... Self.maximumDSOLimitingMagnitude,
                        step: 0.5
                    ) {
                        Text("Adjust DSO limiting magnitude")
                    }
                    .labelsHidden()

                    Text("or brighter")
                        .font(compactBodyFont)
                        .foregroundStyle(.white.opacity(0.84))
                }

                VStack(alignment: .center, spacing: 6) {
                    Text("DSO Limiting Magnitude")
                        .font(compactSelectorLabelFont)
                        .foregroundStyle(labelColor.opacity(0.92))
                        .multilineTextAlignment(.center)

                    HStack(spacing: 10) {
                        TextField("8", text: $dsoLimitingMagnitudeText)
                            .textFieldStyle(.roundedBorder)
                            .foregroundStyle(observationTimeTextColor)
                            .frame(width: 72)
                            .onSubmit {
                                normalizeDSOLimitingMagnitudeText()
                            }

                        Stepper(
                            value: dsoLimitingMagnitudeBinding,
                            in: Self.minimumDSOLimitingMagnitude ... Self.maximumDSOLimitingMagnitude,
                            step: 0.5
                        ) {
                            Text("Adjust DSO limiting magnitude")
                        }
                        .labelsHidden()

                        Text("or brighter")
                            .font(compactBodyFont)
                            .foregroundStyle(.white.opacity(0.84))
                    }
                }
            }

        }
        .frame(minWidth: 190, maxWidth: .infinity, alignment: .center)
    }

    private var targetAzimuthLimitControl: some View {
        targetLimitGroup(
            title: "Azimuth Limits",
            lowTitle: "Low",
            highTitle: "High",
            lowText: $targetAzimuthLowLimitText,
            highText: $targetAzimuthHighLimitText,
            lowValue: targetAzimuthLowLimitBinding,
            highValue: targetAzimuthHighLimitBinding
        )
    }

    private var targetAltitudeLimitControl: some View {
        targetLimitGroup(
            title: "Altitude Limits",
            lowTitle: "Low",
            highTitle: "High",
            lowText: $targetAltitudeLowLimitText,
            highText: $targetAltitudeHighLimitText,
            lowValue: targetAltitudeLowLimitBinding,
            highValue: targetAltitudeHighLimitBinding
        )
    }

    private var targetSortOptionsControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Sort Targets")
                .font(compactSelectorLabelFont)
                .foregroundStyle(labelColor.opacity(0.92))

            LazyVGrid(
                columns: [
                    GridItem(.adaptive(minimum: 132), spacing: 10)
                ],
                alignment: .leading,
                spacing: 6
            ) {
                ForEach(SingleNightTargetSortMode.allCases) { option in
                    Toggle(option.label, isOn: targetSortBinding(for: option))
                        .toggleStyle(.checkbox)
                        .font(compactBodyFont)
                        .foregroundStyle(.white.opacity(0.92))
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(singleNightCardBackground(cornerRadius: 18, fill: .ultraThinMaterial))
    }

    private func targetLimitGroup(
        title: String,
        lowTitle: String,
        highTitle: String,
        lowText: Binding<String>,
        highText: Binding<String>,
        lowValue: Binding<Double>,
        highValue: Binding<Double>
    ) -> some View {
        VStack(alignment: .center, spacing: 6) {
            Text(title)
                .font(compactSelectorLabelFont)
                .foregroundStyle(labelColor.opacity(0.92))
                .multilineTextAlignment(.center)

            HStack(alignment: .top, spacing: 8) {
                targetDegreeLimitField(title: lowTitle, text: lowText, value: lowValue)
                targetDegreeLimitField(title: highTitle, text: highText, value: highValue)
            }
        }
        .frame(minWidth: 190, maxWidth: .infinity, alignment: .center)
    }

    private func targetDegreeLimitField(
        title: String,
        text: Binding<String>,
        value: Binding<Double>
    ) -> some View {
        VStack(alignment: .center, spacing: 4) {
            Text(title)
                .font(compactCaptionFont)
                .foregroundStyle(.white.opacity(0.72))
                .multilineTextAlignment(.center)

            HStack(spacing: 6) {
                TextField("", text: text)
                    .textFieldStyle(.roundedBorder)
                    .foregroundStyle(observationTimeTextColor)
                    .frame(width: 58)
                    .onSubmit {
                        normalizeTargetSkyLimitTexts()
                    }

                Stepper(value: value, step: 2) {
                    Text("\(title) degrees")
                }
                .labelsHidden()
            }
        }
    }

    private var targetSelectionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardHeading(
                title: "Targets",
                centered: true
            )

            if combinedTargets.isEmpty {
                Text("No targets match the selected target types, magnitude, sky limits, and visibility window yet.")
                    .font(compactBodyFont)
                    .foregroundStyle(.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                targetSelectionHeaderControls
                    .frame(maxWidth: .infinity, alignment: .center)

                targetFeedList
            }
        }
        .padding(10)
        .frame(maxWidth: contentCardMaxWidth, maxHeight: .infinity, alignment: .topLeading)
        .background(singleNightCardBackground())
    }

    private var targetFeedList: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Text("Target Feed")
                    .font(compactSelectorLabelFont)
                    .foregroundStyle(labelColor.opacity(0.92))

                Spacer(minLength: 0)

                Text("\(combinedTargets.count) matches")
                    .font(compactCaptionFont)
                    .foregroundStyle(.white.opacity(0.72))
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 7) {
                    ForEach(sortedTargets) { target in
                        targetFeedRow(target)
                    }
                }
                .padding(.vertical, 2)
                .scrollTargetLayout()
            }
            .scrollIndicators(.visible)
            .scrollTargetBehavior(.viewAligned)
            .frame(height: targetFeedVisibleHeight, alignment: .topLeading)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(singleNightCardBackground(cornerRadius: 22, fill: .ultraThinMaterial))
    }

    private func targetFeedRow(_ target: SingleNightTargetChoice) -> some View {
        let isSelected = selectedTargetID == target.id

        return HStack(alignment: .center, spacing: 8) {
            Toggle("", isOn: targetObservationListBinding(for: target))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .fixedSize()

            targetFeedRowContent(for: target)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(singleNightCardBackground(cornerRadius: 14, fill: .thinMaterial))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isSelected ? Color.accentColor.opacity(0.62) : Color.clear, lineWidth: 1.2)
        )
        .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .onTapGesture {
            selectedTargetID = target.id
        }
    }

    private func targetFeedRowContent(for target: SingleNightTargetChoice) -> some View {
        let visibilityText = targetVisibilitySummary(for: target)

        return ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 10) {
                targetFeedField(
                    target.identifier,
                    minimumWidth: 70,
                    idealWidth: 84,
                    maximumWidth: 92,
                    font: compactStrongFont
                )

                targetFeedField(
                    target.shortenedName,
                    minimumWidth: 118,
                    idealWidth: 220,
                    maximumWidth: 240,
                    font: compactStrongFont
                )
                    .layoutPriority(3)

                targetFeedField(
                    target.typeName,
                    minimumWidth: 82,
                    idealWidth: 116,
                    maximumWidth: 130,
                    font: compactBodyFont
                )

                targetFeedField(
                    target.constellation,
                    minimumWidth: 38,
                    idealWidth: 48,
                    maximumWidth: 54,
                    font: compactBodyFont
                )

                if let visibilityText {
                    targetFeedTimeField(visibilityText, maximumWidth: 250)
                        .layoutPriority(2)
                }

                Spacer(minLength: 0)

                targetMagnitudeBadge(for: target)
                    .fixedSize(horizontal: true, vertical: false)
            }

            HStack(alignment: .center, spacing: 8) {
                targetFeedField(
                    target.identifier,
                    minimumWidth: 62,
                    idealWidth: 74,
                    maximumWidth: 82,
                    font: compactStrongFont
                )

                targetFeedField(
                    target.shortenedName,
                    minimumWidth: 96,
                    idealWidth: 170,
                    maximumWidth: 190,
                    font: compactStrongFont
                )
                    .layoutPriority(3)

                if let visibilityText {
                    targetFeedTimeField(visibilityText, maximumWidth: 190)
                        .layoutPriority(2)
                }

                Spacer(minLength: 0)

                targetMagnitudeBadge(for: target)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private func targetMagnitudeBadge(for target: SingleNightTargetChoice) -> some View {
        Text(target.magnitude.map { "Mag \($0.formatted(.number.precision(.fractionLength(1))))" } ?? "Mag --")
            .font(compactStrongFont)
            .foregroundStyle(labelColor.opacity(0.94))
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .background(singleNightCardBackground(cornerRadius: 12, fill: .ultraThinMaterial))
    }

    private func targetFeedField(
        _ text: String,
        minimumWidth: CGFloat,
        idealWidth: CGFloat,
        maximumWidth: CGFloat,
        font: Font
    ) -> some View {
        Text(text)
            .font(font)
            .foregroundStyle(.white.opacity(0.90))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .truncationMode(.tail)
            .frame(
                minWidth: minimumWidth,
                idealWidth: idealWidth,
                maxWidth: maximumWidth,
                alignment: .leading
            )
    }

    private func targetFeedTimeField(_ text: String, maximumWidth: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 14, weight: .semibold, design: .rounded))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.70)
            .truncationMode(.tail)
            .frame(minWidth: 118, idealWidth: maximumWidth, maxWidth: maximumWidth, alignment: .leading)
    }

    private var targetIdentifierMenu: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Target Identifier")
                .font(compactSelectorLabelFont)
                .foregroundStyle(labelColor.opacity(0.92))
                .frame(maxWidth: .infinity, alignment: .leading)

            Menu {
                ForEach(identifierSortedTargets) { target in
                    Button {
                        selectedTargetID = target.id
                    } label: {
                        Label(target.identifier, systemImage: addedTargetIDs.contains(target.id) ? "checkmark.circle.fill" : "circle")
                    }
                    .disabled(addedTargetIDs.contains(target.id))
                }
            } label: {
                selectionMenuLabel(
                    title: selectedTarget?.identifier,
                    placeholder: "Choose a target identifier",
                    expands: true,
                    compact: true
                )
            }
            .buttonStyle(.plain)
        }
        .frame(minWidth: 220, maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
    }

    private var targetNameMenu: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Target Name")
                .font(compactSelectorLabelFont)
                .foregroundStyle(labelColor.opacity(0.92))
                .frame(maxWidth: .infinity, alignment: .leading)

            Menu {
                ForEach(nameSortedTargets) { target in
                    Button {
                        selectedTargetID = target.id
                    } label: {
                        Label(target.name, systemImage: addedTargetIDs.contains(target.id) ? "checkmark.circle.fill" : "circle")
                    }
                    .disabled(addedTargetIDs.contains(target.id))
                }
            } label: {
                selectionMenuLabel(
                    title: selectedTarget?.name,
                    placeholder: "Choose a target name",
                    expands: true,
                    compact: true
                )
            }
            .buttonStyle(.plain)
        }
        .frame(minWidth: 280, maxWidth: .infinity, alignment: .leading)
        .layoutPriority(2)
    }

    private var targetSelectionHeaderControls: some View {
        ViewThatFits(in: .horizontal) {
            targetObjectMenus
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                targetObjectMenus
            }
        }
    }

    private var targetObjectMenus: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 10) {
                targetIdentifierMenu
                targetNameMenu
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                targetIdentifierMenu
                targetNameMenu
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var observationScheduleControls: some View {
        HStack(alignment: .center, spacing: 8) {
            observationDateEntry

            observationTimeZoneMenu
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var observationDateEntry: some View {
        VStack(alignment: .center, spacing: 6) {
            Text("Observation Date")
                .font(compactSelectorLabelFont)
                .foregroundStyle(labelColor.opacity(0.92))
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity, alignment: .center)

            DatePicker(
                "Observation Date",
                selection: observationDateBinding,
                displayedComponents: .date
            )
            .labelsHidden()
            .datePickerStyle(.field)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(minWidth: 170, maxWidth: .infinity, alignment: .center)
    }

    private var observationTimeEntry: some View {
        VStack(alignment: .center, spacing: 6) {
            Text("Start Time")
                .font(compactSelectorLabelFont)
                .foregroundStyle(observationTimeTextColor)
                .multilineTextAlignment(.center)

            HStack(alignment: .center, spacing: 6) {
                TextField("HH:MM", text: $observationTimeText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 78)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(observationTimeTextColor)
                    .tint(observationTimeTextColor)
                    .focused($focusedObservationTimeField, equals: .time)
                    .onSubmit {
                        applyObservationTimeEntry()
                    }
            }
        }
        .onChange(of: observationTimeText) { _, newValue in
            let filtered = sanitizedObservationTimeInput(newValue)
            if filtered != newValue {
                observationTimeText = filtered
                return
            }
            applyObservationTimeEntry(normalizeFields: false)
        }
        .onChange(of: focusedObservationTimeField) { _, newValue in
            if newValue == nil {
                applyObservationTimeEntry()
            }
        }
    }

    private var observationMeridiemMenu: some View {
        VStack(alignment: .center, spacing: 6) {
            Text("AM/PM")
                .font(compactSelectorLabelFont)
                .foregroundStyle(observationTimeTextColor)
                .multilineTextAlignment(.center)

            Menu {
                ForEach(ObservationMeridiem.allCases) { meridiem in
                    Button(meridiem.rawValue) {
                        observationMeridiem = meridiem
                    }
                }
            } label: {
                selectionMenuLabel(
                    title: observationMeridiem.rawValue,
                    placeholder: "AM",
                    expands: false,
                    maxWidth: 52,
                    compact: true
                )
            }
            .buttonStyle(.plain)
        }
        .frame(width: 56, alignment: .leading)
    }

    private var observationTimeZoneMenu: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Time Zone")
                .font(compactSelectorLabelFont)
                .foregroundStyle(labelColor.opacity(0.92))

            Menu {
                ForEach(availableTimeZoneIdentifiers, id: \.self) { timeZoneIdentifier in
                    Button(timeZoneDisplayName(for: timeZoneIdentifier)) {
                        observationTimeZoneIdentifier = timeZoneIdentifier
                    }
                }
            } label: {
                selectionMenuLabel(
                    title: timeZoneMenuLabel(for: observationTimeZoneIdentifier),
                    placeholder: "Choose a time zone",
                    expands: true,
                    compact: true
                )
            }
            .buttonStyle(.plain)
        }
        .frame(minWidth: 180, maxWidth: .infinity, alignment: .leading)
        .layoutPriority(1)
    }

    private var observationDateBinding: Binding<Date> {
        Binding(
            get: { observationDateTime },
            set: { applyObservationDateEntry($0) }
        )
    }

    private var allTargets: [SingleNightTargetChoice] {
        let deepSkyTargets = objects.map(SingleNightTargetChoice.init(object:))
        let transientTargets = transientItems.map(SingleNightTargetChoice.init(transient:))
        return deepSkyTargets + transientTargets
    }

    private var magnitudeFilteredTargets: [SingleNightTargetChoice] {
        allTargets.filter(targetPassesDSOLimitingMagnitude)
    }

    private var targetDatabaseFilteredTargets: [SingleNightTargetChoice] {
        if usesVisibilityFilter {
            let visibleIDs = Set(visibleTargetMetadata.keys)
            return magnitudeFilteredTargets.filter { visibleIDs.contains($0.id) }
        }

        return magnitudeFilteredTargets
    }

    private var combinedTargets: [SingleNightTargetChoice] {
        guard !selectedTargetTypeNames.isEmpty else { return [] }
        return targetDatabaseFilteredTargets.filter { targetMatchesSelectedTypes($0) }
    }

    private var sortedTargets: [SingleNightTargetChoice] {
        combinedTargets.sorted(by: compareTargetsForSelectedSort)
    }

    private var identifierSortedTargets: [SingleNightTargetChoice] {
        combinedTargets.sorted(by: compareTargetsByVisibilityThenIdentifier)
    }

    private var nameSortedTargets: [SingleNightTargetChoice] {
        combinedTargets.sorted(by: compareTargetsByVisibilityThenName)
    }

    private var selectedLocation: ObservingSite? {
        guard let selectedLocationID else { return nil }
        return sites.first(where: { $0.id == selectedLocationID })
    }

    private var selectedTarget: SingleNightTargetChoice? {
        guard let selectedTargetID else { return nil }
        return combinedTargets.first(where: { $0.id == selectedTargetID })
    }

    private var selectedLocationName: String {
        selectedLocation?.name ?? "Choose a saved location"
    }

    private var weatherSourceRequestKey: String {
        guard let site = selectedLocation else { return "no-site" }
        let cachedCountry = [site.countryCode ?? "", site.countryName ?? ""].joined(separator: "-")
        return "\(site.id.uuidString)-\(site.latitude)-\(site.longitude)-\(cachedCountry)"
    }

    private var observationWeatherRequestKey: String {
        guard
            let site = selectedLocation,
            let nightStart = solarEvents.start,
            let nightEnd = solarEvents.end
        else {
            return "no-weather-window"
        }

        let roundedStart = Int(nightStart.timeIntervalSince1970 / 60)
        let roundedEnd = Int(nightEnd.timeIntervalSince1970 / 60)
        return "\(site.id.uuidString)-\(site.latitude)-\(site.longitude)-\(roundedStart)-\(roundedEnd)"
    }

    private var sortedLocations: [ObservingSite] {
        sites.sorted { lhs, rhs in
            lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private var addedTargets: [SingleNightTargetChoice] {
        addedTargetIDs.compactMap { targetID in
            allTargets.first(where: { $0.id == targetID })
        }
    }

    private var isSelectedTargetAdded: Bool {
        guard let selectedTargetID else { return false }
        return addedTargetIDs.contains(selectedTargetID)
    }

    private var selectedObservationCoordinates: SingleNightEquatorialCoordinate? {
        selectedTarget?.coordinates(at: referenceDate)
    }

    private var selectedObservationSkyPosition: LocalSkyPosition? {
        guard let selectedLocation, let selectedTarget else { return nil }
        let coordinates = selectedTarget.coordinates(at: referenceDate)
        return SkyCoordinateService.localSkyPosition(
            rightAscensionHours: coordinates.rightAscensionHours,
            declinationDegrees: coordinates.declinationDegrees,
            site: selectedLocation,
            at: referenceDate
        )
    }

    private var solarEvents: SunBelowHorizonEvents {
        guard let selectedLocation else {
            return .unavailable
        }

        let calculatedEvents = SolarHorizonService.sunBelowHorizonEvents(for: selectedLocation, on: referenceDate)
        guard let calculatedStart = calculatedEvents.start else {
            return calculatedEvents
        }

        let imagingStartDate = normalizedObservationDate(telescopeCaptureStartOverrideDate ?? referenceDate)
        return SunBelowHorizonEvents(
            start: max(calculatedStart, imagingStartDate),
            end: calculatedEvents.end
        )
    }

    private func observationInfoSummary(skyPosition: LocalSkyPosition) -> String {
        "Selected \(formattedSolarEvent(referenceDate)) • \(formattedWholeAngle(skyPosition.azimuthDegrees))° • \(skyPosition.magneticCardinalDirection)"
    }

    private func syncSelectedLocation() {
        if let selectedLocationID,
           sites.contains(where: { $0.id == selectedLocationID }) {
            return
        }

        if let draftLocationID = runtimeState.singleNightObservationDraft?.selectedLocationID,
           sites.contains(where: { $0.id == draftLocationID }) {
            selectedLocationID = draftLocationID
            return
        }

        selectedLocationID = LocationPreferenceStore.reconcileDefaultSiteID(using: sites)
    }

    private func presentLocationPicker() {
        locationPickerSelectionID = selectedLocationID ?? LocationPreferenceStore.reconcileDefaultSiteID(using: sites)
        locationPickerIsPresented = true
    }

    private func applyLocationSelection(_ siteID: UUID, setAsDefault: Bool) {
        selectedLocationID = siteID
        if setAsDefault {
            LocationPreferenceStore.setDefaultSiteID(siteID)
        }
        syncObservationTimeZoneFromLocation()
        recomputeVisibleTargets()
        persistSingleNightDraft()
    }

    private func syncObservationTimeZoneFromLocation() {
        guard let locationTimeZoneIdentifier = selectedLocation?.timeZoneIdentifier,
              TimeZone(identifier: locationTimeZoneIdentifier) != nil else {
            return
        }

        observationTimeZoneIdentifier = locationTimeZoneIdentifier
    }

    private func syncSelectedTarget() {
        guard !combinedTargets.isEmpty else {
            selectedTargetID = nil
            return
        }

        if let selectedTargetID,
           combinedTargets.contains(where: { $0.id == selectedTargetID }) {
            return
        }

        selectedTargetID = sortedTargets.first?.id
    }

    private func syncAddedTargets() {
        let validIDs = Set(allTargets.map(\.id))
        addedTargetIDs.removeAll { !validIDs.contains($0) }
    }

    private func syncSelectedTargetTypes() {
        let availableSet = Set(availableTargetTypes)

        if !hasInitializedTargetTypeSelection || (!didManuallyAdjustTargetTypes && !availableSet.isEmpty) {
            selectedTargetTypeNames = availableSet
            hasInitializedTargetTypeSelection = true
            return
        }

        selectedTargetTypeNames = selectedTargetTypeNames.intersection(availableSet)
    }

    private func scheduleVisibleTargetRecompute() {
        visibilityRecomputeTask?.cancel()
        visibilityRecomputeTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            guard !Task.isCancelled else { return }
            recomputeVisibleTargets()
            persistSingleNightDraft()
        }
    }

    private func recomputeVisibleTargets() {
        visibilityRecomputeTask?.cancel()
        visibilityRecomputeTask = nil
        guard let selectedLocation,
              let nightStart = solarEvents.start,
              let nightEnd = solarEvents.end else {
            visibleTargetMetadata = [:]
            usesVisibilityFilter = false
            syncSelectedTarget()
            syncAddedTargets()
            return
        }

        guard nightEnd > nightStart else {
            visibleTargetMetadata = [:]
            usesVisibilityFilter = true
            syncSelectedTarget()
            syncAddedTargets()
            return
        }

        var metadata: [String: SingleNightTargetVisibility] = [:]
        for target in magnitudeFilteredTargets {
            if let visibility = visibilityWindow(
                for: target,
                site: selectedLocation,
                nightStart: nightStart,
                nightEnd: nightEnd
            ) {
                metadata[target.id] = visibility
            }
        }

        visibleTargetMetadata = metadata
        usesVisibilityFilter = true
        syncSelectedTarget()
        syncAddedTargets()
    }

    private func visibilityWindow(
        for target: SingleNightTargetChoice,
        site: ObservingSite,
        nightStart: Date,
        nightEnd: Date
    ) -> SingleNightTargetVisibility? {
        let stepInterval: TimeInterval = 10 * 60
        var sampleDate = nightStart
        var firstVisibleDate: Date?
        var firstVisibleSkyPosition: LocalSkyPosition?
        var zenithDate: Date?
        var zenithAltitude = -Double.infinity

        while sampleDate <= nightEnd {
            let coordinates = target.coordinates(at: sampleDate)
            let skyPosition = SkyCoordinateService.localSkyPosition(
                rightAscensionHours: coordinates.rightAscensionHours,
                declinationDegrees: coordinates.declinationDegrees,
                site: site,
                at: sampleDate
            )

            if targetPassesSkyLimits(skyPosition) {
                if firstVisibleDate == nil {
                    firstVisibleDate = sampleDate
                    firstVisibleSkyPosition = skyPosition
                }

                if skyPosition.altitudeDegrees > zenithAltitude {
                    zenithAltitude = skyPosition.altitudeDegrees
                    zenithDate = sampleDate
                }
            }

            sampleDate = sampleDate.addingTimeInterval(stepInterval)
        }

        guard
            let firstVisibleDate,
            let firstVisibleSkyPosition,
            let zenithDate
        else {
            return nil
        }

        return SingleNightTargetVisibility(
            visibleFrom: firstVisibleDate,
            zenithDate: zenithDate,
            zenithAltitudeDegrees: zenithAltitude,
            skyPosition: firstVisibleSkyPosition
        )
    }

    private func addSelectedTargetToCurrentList() {
        guard
            let currentTargetID = selectedTargetID,
            let target = targetChoice(for: currentTargetID)
        else { return }

        addTargetToCurrentList(target)
        selectedTargetID = nextAvailableTargetID(after: currentTargetID)
    }

    private func targetObservationListBinding(for target: SingleNightTargetChoice) -> Binding<Bool> {
        Binding(
            get: { addedTargetIDs.contains(target.id) },
            set: { isAdded in
                selectedTargetID = target.id
                if isAdded {
                    addTargetToCurrentList(target)
                } else {
                    removeTargetFromCurrentList(target.id)
                }
            }
        )
    }

    private func addTargetToCurrentList(_ target: SingleNightTargetChoice) {
        guard !addedTargetIDs.contains(target.id) else { return }
        retainTargetLocally(target)
        addedTargetIDs.append(target.id)
    }

    private func removeTargetFromCurrentList(_ targetID: String) {
        if let target = targetChoice(for: targetID) {
            releaseTargetLocalRetention(target)
        }

        addedTargetIDs.removeAll { $0 == targetID }
    }

    private func clearCurrentList() {
        addedTargetIDs
            .compactMap { targetChoice(for: $0) }
            .forEach(releaseTargetLocalRetention)
        addedTargetIDs.removeAll()
    }

    private func targetChoice(for targetID: String) -> SingleNightTargetChoice? {
        allTargets.first { $0.id == targetID }
    }

    private func retainTargetLocally(_ target: SingleNightTargetChoice) {
        switch target.sourceKind {
        case .deepSky:
            guard let object = objects.first(where: { $0.catalogID == target.identifier }) else { return }
            object.locallyRetainedAt = object.locallyRetainedAt ?? Date()
            object.localRetentionReason = "Added to the current single night observation list."
        case .transient:
            guard let item = transientItems.first(where: { $0.feedID == target.identifier }) else { return }
            item.locallyRetainedAt = item.locallyRetainedAt ?? Date()
            item.localRetentionReason = "Added to the current single night observation list."
        }

        try? modelContext.save()
    }

    private func releaseTargetLocalRetention(_ target: SingleNightTargetChoice) {
        switch target.sourceKind {
        case .deepSky:
            guard let object = objects.first(where: { $0.catalogID == target.identifier }) else { return }
            object.locallyRetainedAt = nil
            object.localRetentionReason = nil
        case .transient:
            guard let item = transientItems.first(where: { $0.feedID == target.identifier }) else { return }
            item.locallyRetainedAt = nil
            item.localRetentionReason = nil
        }

        try? modelContext.save()
    }

    private func restoreSingleNightDraft() {
        guard let draft = runtimeState.singleNightObservationDraft else { return }
        selectedLocationID = draft.selectedLocationID
        selectedTargetID = draft.selectedTargetID
        addedTargetIDs = draft.addedTargetIDs
        observationDateTime = draft.observationDateTime
        observationTimeZoneIdentifier = draft.observationTimeZoneIdentifier
        telescopeCaptureStartOverrideDate = draft.telescopeCaptureStartOverrideDate
        dsoLimitingMagnitudeText = draft.dsoLimitingMagnitudeText
        targetAzimuthLowLimitText = draft.targetAzimuthLowLimitText
        targetAzimuthHighLimitText = draft.targetAzimuthHighLimitText
        targetAltitudeLowLimitText = draft.targetAltitudeLowLimitText
        targetAltitudeHighLimitText = draft.targetAltitudeHighLimitText
        selectedTargetTypeNames = draft.selectedTargetTypeNames
        targetSortMode = SingleNightTargetSortMode(rawValue: draft.targetSortModeRawValue) ?? .firstViewable
        hasInitializedTargetTypeSelection = draft.hasInitializedTargetTypeSelection
        didManuallyAdjustTargetTypes = draft.didManuallyAdjustTargetTypes
    }

    private func persistSingleNightDraft() {
        runtimeState.singleNightObservationDraft = SingleNightObservationDraft(
            selectedLocationID: selectedLocationID,
            selectedTargetID: selectedTargetID,
            addedTargetIDs: addedTargetIDs,
            observationDateTime: observationDateTime,
            observationTimeZoneIdentifier: observationTimeZoneIdentifier,
            telescopeCaptureStartOverrideDate: telescopeCaptureStartOverrideDate,
            dsoLimitingMagnitudeText: dsoLimitingMagnitudeText,
            targetAzimuthLowLimitText: targetAzimuthLowLimitText,
            targetAzimuthHighLimitText: targetAzimuthHighLimitText,
            targetAltitudeLowLimitText: targetAltitudeLowLimitText,
            targetAltitudeHighLimitText: targetAltitudeHighLimitText,
            selectedTargetTypeNames: selectedTargetTypeNames,
            targetSortModeRawValue: targetSortMode.rawValue,
            hasInitializedTargetTypeSelection: hasInitializedTargetTypeSelection,
            didManuallyAdjustTargetTypes: didManuallyAdjustTargetTypes
        )
    }

    private func applyPendingTelescopeCaptureStartIfNeeded() {
        guard let captureStartDate = runtimeState.pendingTelescopeCaptureStartDate else { return }

        if let destinationRawValue = runtimeState.pendingTelescopeCaptureStartDestinationRawValue,
           destinationRawValue != SidebarSection.planObservation.rawValue {
            return
        }

        let normalizedDate = normalizedObservationDate(captureStartDate)
        telescopeCaptureStartOverrideDate = normalizedDate
        observationDateTime = normalizedDate
        runtimeState.pendingTelescopeCaptureStartDate = nil
        runtimeState.pendingTelescopeCaptureStartDestinationRawValue = nil
    }

    private func clearTelescopeCaptureStartOverrideIfNeeded() {
        guard let telescopeCaptureStartOverrideDate else { return }

        let normalizedOverride = normalizedObservationDate(telescopeCaptureStartOverrideDate)
        let normalizedObservation = normalizedObservationDate(observationDateTime)
        if abs(normalizedOverride.timeIntervalSince(normalizedObservation)) > 60 {
            self.telescopeCaptureStartOverrideDate = nil
        }
    }

    private func cancelSingleNightPlan() {
        runtimeState.singleNightObservationDraft = nil
        selectedTargetID = nil
        addedTargetIDs.removeAll()
        observationDateTime = Date()
        observationTimeZoneIdentifier = TimeZone.current.identifier
        telescopeCaptureStartOverrideDate = nil
        observationTimeText = ""
        dsoLimitingMagnitudeText = formattedMagnitudeLimit(Self.defaultDSOLimitingMagnitude)
        targetAzimuthLowLimitText = ""
        targetAzimuthHighLimitText = ""
        targetAltitudeLowLimitText = ""
        targetAltitudeHighLimitText = ""
        selectedTargetTypeNames.removeAll()
        targetSortMode = .firstViewable
        visibleTargetMetadata = [:]
        usesVisibilityFilter = false
        hasInitializedTargetTypeSelection = false
        didManuallyAdjustTargetTypes = false
        selectedLocationID = LocationPreferenceStore.reconcileDefaultSiteID(using: sites)
        syncObservationTimeZoneFromLocation()
        syncSelectedTargetTypes()
        recomputeVisibleTargets()
        selectedSection = .home
    }

    private var weatherSourceSubtitle: String {
        if let observationCountry {
            return "\(observationCountry.countryName) public source • \(weatherSource.website)"
        }

        if isResolvingObservationCountry {
            return "Resolving country from the observation location."
        }

        if !weatherSourceMessage.isEmpty {
            return "Global fallback • \(weatherSource.website)"
        }

        return "Adapts when a location is selected."
    }

    @MainActor
    private func refreshWeatherSource() async {
        guard let site = selectedLocation else {
            observationCountry = nil
            weatherSource = WeatherSourcePolicy.source(for: nil)
            weatherSourceMessage = ""
            isResolvingObservationCountry = false
            return
        }

        if let countryCode = normalizedText(site.countryCode),
           let countryName = normalizedText(site.countryName) {
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
            try? modelContext.save()
        } catch {
            observationCountry = nil
            weatherSource = WeatherSourcePolicy.source(for: nil)
            weatherSourceMessage = AppIssueFormatter.remoteServiceMessage(service: "Observation country lookup", error: error)
        }

        isResolvingObservationCountry = false
    }

    @MainActor
    private func refreshObservationWeather() async {
        guard
            let site = selectedLocation,
            let nightStart = solarEvents.start,
            let nightEnd = solarEvents.end
        else {
            observationWeatherSnapshot = nil
            observationWeatherMessage = "Weather appears after a location and observation window are available."
            isLoadingObservationWeather = false
            return
        }

        isLoadingObservationWeather = true
        observationWeatherMessage = ""

        do {
            observationWeatherSnapshot = try await ObservationWeatherService.fetchSnapshot(
                for: ObservationWeatherRequest(
                    siteName: site.name,
                    latitude: site.latitude,
                    longitude: site.longitude,
                    timeZoneIdentifier: site.timeZoneIdentifier,
                    sunsetDate: nightStart,
                    nightEndDate: nightEnd
                )
            )
        } catch {
            observationWeatherSnapshot = nil
            observationWeatherMessage = AppIssueFormatter.remoteServiceMessage(service: "Observation weather", error: error)
        }

        isLoadingObservationWeather = false
    }

    private func refreshTargetDatabase() async {
        guard !isRefreshingTargetDatabase else { return }

        isRefreshingTargetDatabase = true
        let report = await DatabaseRefreshService.refreshAllNow(context: modelContext, now: Date())
        runtimeState.setRefreshWarnings(report.warnings)

        isRefreshingTargetDatabase = false
        syncSelectedTargetTypes()
        recomputeVisibleTargets()
    }

    private func canMoveTarget(_ targetID: String, offset: Int) -> Bool {
        guard let index = addedTargetIDs.firstIndex(of: targetID) else { return false }
        let destination = index + offset
        return addedTargetIDs.indices.contains(destination)
    }

    private func moveTargetInCurrentList(_ targetID: String, offset: Int) {
        guard let index = addedTargetIDs.firstIndex(of: targetID) else { return }
        let destination = index + offset
        guard addedTargetIDs.indices.contains(destination) else { return }
        let moved = addedTargetIDs.remove(at: index)
        addedTargetIDs.insert(moved, at: destination)
    }

    private func nextAvailableTargetID(after currentID: String?) -> String? {
        let candidates = sortedTargets.filter { !addedTargetIDs.contains($0.id) }
        guard !candidates.isEmpty else { return currentID }
        if let currentID,
           let currentIndex = candidates.firstIndex(where: { $0.id == currentID }),
           candidates.indices.contains(currentIndex + 1) {
            return candidates[currentIndex + 1].id
        }
        return candidates.first?.id
    }

    private func printCurrentList() {
        SingleNightObservationPrintService.printCurrentList(
            location: selectedLocation,
            targets: addedTargets,
            referenceDate: referenceDate
        )
    }

    private func saveCurrentListAsPDF() {
        SingleNightObservationPrintService.saveCurrentListAsPDF(
            location: selectedLocation,
            targets: addedTargets,
            referenceDate: referenceDate
        )
    }

    private func promptSaveCurrentListForLaterUse() {
        saveListNameDraft = ""
        saveListPromptIsPresented = true
    }

    private func saveCurrentListForLaterUse(named name: String) {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedName.isEmpty else { return }
        guard !addedTargets.isEmpty else { return }

        let list = SavedTargetList(
            name: trimmedName,
            defaultSiteID: selectedLocationID
        )

        let items = addedTargets.enumerated().map { index, target in
            SavedTargetListItem(
                orderIndex: index,
                targetID: target.id,
                identifier: target.identifier,
                displayName: target.name,
                typeName: target.typeName,
                constellation: target.constellation,
                sourceLabel: target.sourceLabel,
                rightAscensionHours: target.rightAscensionHours,
                declinationDegrees: target.declinationDegrees,
                magnitude: target.magnitude,
                savedList: list
            )
        }

        list.items = items
        modelContext.insert(list)

        do {
            try modelContext.save()
            saveListPromptIsPresented = false
            savedListStatusMessage = "Saved \"\(trimmedName)\" to the Saved Lists Database with \(items.count) targets for multi-night observation."
        } catch {
            savedListStatusMessage = "Unable to save the list: \(error.localizedDescription)"
        }
    }

    private var savedListAlertIsPresented: Binding<Bool> {
        Binding(
            get: { savedListStatusMessage != nil },
            set: { isPresented in
                if !isPresented {
                    savedListStatusMessage = nil
                }
            }
        )
    }

    private var referenceDate: Date {
        let displayComponents = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: observationDateTime)
        let timeZone = observationTimeZone
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        return calendar.date(from: displayComponents) ?? observationDateTime
    }

    private func normalizedObservationDate(_ date: Date) -> Date {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return calendar.date(from: components) ?? date
    }

    private func syncObservationTimeFieldsFromDate(force: Bool = false) {
        guard force || !observationTimeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = observationTimeZone
        let components = calendar.dateComponents([.hour, .minute], from: observationDateTime)
        let hour24 = components.hour ?? 0
        observationTimeText = String(format: "%02d:%02d", civilianHour(from24Hour: hour24), components.minute ?? 0)
        observationMeridiem = hour24 < 12 ? .am : .pm
    }

    private func sanitizedObservationTimeInput(_ value: String) -> String {
        let allowed = value.filter { $0.isNumber || $0 == ":" }
        guard allowed.contains(":") else {
            let digits = String(allowed.filter(\.isNumber).prefix(4))
            guard digits.count > 2 else { return digits }

            let splitIndex = digits.count == 3 ? digits.index(after: digits.startIndex) : digits.index(digits.startIndex, offsetBy: 2)
            return "\(digits[..<splitIndex]):\(digits[splitIndex...])"
        }

        let parts = allowed.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let hour = String((parts.first ?? "").filter(\.isNumber).prefix(2))
        let minute = parts.count > 1 ? String(parts[1].filter(\.isNumber).prefix(2)) : ""
        return "\(hour):\(minute)"
    }

    private func parsedObservationTimeEntry() -> (hour: Int, minute: Int)? {
        let parts = observationTimeText
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)

        guard parts.count == 2,
              let hour = Int(parts[0]),
              let minute = Int(parts[1]),
              (0 ... 23).contains(hour),
              (0 ... 59).contains(minute) else {
            return nil
        }

        return (hour, minute)
    }

    private func parsedObservationClockTime() -> (hour24: Int, displayHour: Int, minute: Int, usesMilitaryTime: Bool)? {
        guard let parsedTime = parsedObservationTimeEntry() else {
            return nil
        }

        let hour = parsedTime.hour
        let minute = parsedTime.minute
        if (0 ... 23).contains(hour),
           hour == 0 || hour > 12 {
            return (hour, hour, minute, true)
        }

        guard (1 ... 12).contains(hour) else {
            return nil
        }

        return (hour24(fromCivilianHour: hour, meridiem: observationMeridiem), hour, minute, false)
    }

    private func civilianHour(from24Hour hour: Int) -> Int {
        let hour = hour % 24
        let civilianHour = hour % 12
        return civilianHour == 0 ? 12 : civilianHour
    }

    private func hour24(fromCivilianHour hour: Int, meridiem: ObservationMeridiem) -> Int {
        switch meridiem {
        case .am:
            return hour == 12 ? 0 : hour
        case .pm:
            return hour == 12 ? 12 : hour + 12
        }
    }

    private func applyObservationTimeEntry(normalizeFields: Bool = true) {
        guard let parsedTime = parsedObservationClockTime() else {
            return
        }

        let hour = parsedTime.displayHour
        let minute = parsedTime.minute
        let hour24 = parsedTime.hour24
        observationMeridiem = hour24 < 12 ? .am : .pm
        if normalizeFields {
            observationTimeText = String(format: "%02d:%02d", parsedTime.usesMilitaryTime ? hour24 : hour, minute)
        }

        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = observationTimeZone
        var components = calendar.dateComponents([.year, .month, .day], from: observationDateTime)
        components.hour = hour24
        components.minute = minute
        components.second = 0

        if let updatedDate = calendar.date(from: components),
           updatedDate != observationDateTime {
            telescopeCaptureStartOverrideDate = updatedDate
            observationDateTime = updatedDate
        } else {
            telescopeCaptureStartOverrideDate = observationDateTime
            scheduleVisibleTargetRecompute()
        }
    }

    private func applyObservationDateEntry(_ selectedDate: Date) {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = observationTimeZone

        let dateComponents = calendar.dateComponents([.year, .month, .day], from: selectedDate)
        let timeComponents = calendar.dateComponents([.hour, .minute], from: observationDateTime)

        var mergedComponents = DateComponents()
        mergedComponents.year = dateComponents.year
        mergedComponents.month = dateComponents.month
        mergedComponents.day = dateComponents.day
        mergedComponents.hour = timeComponents.hour
        mergedComponents.minute = timeComponents.minute
        mergedComponents.second = 0

        if let updatedDate = calendar.date(from: mergedComponents),
           updatedDate != observationDateTime {
            observationDateTime = updatedDate
        } else {
            scheduleVisibleTargetRecompute()
        }
    }

    private func cardHeading(title: String, subtitle: String? = nil, centered: Bool = false) -> some View {
        let horizontalAlignment: HorizontalAlignment = centered ? .center : .leading
        let textAlignment: TextAlignment = centered ? .center : .leading
        let frameAlignment: Alignment = centered ? .center : .leading

        return VStack(alignment: horizontalAlignment, spacing: 6) {
            Text(title)
                .font(centered ? cardHeadingTitleFont : compactStrongFont)
                .foregroundStyle(labelColor.opacity(0.92))
                .multilineTextAlignment(textAlignment)
                .frame(maxWidth: .infinity, alignment: frameAlignment)

            if let subtitle {
                Text(subtitle)
                    .font(compactBodyFont)
                    .foregroundStyle(.white.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(textAlignment)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
            }
        }
        .frame(maxWidth: .infinity, alignment: frameAlignment)
    }

    @ViewBuilder
    private func selectionMenuLabel(
        title: String?,
        placeholder: String,
        expands: Bool = true,
        maxWidth: CGFloat? = nil,
        compact: Bool = false
    ) -> some View {
        if expands {
            selectionMenuLabelBody(title: title, placeholder: placeholder, compact: compact)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            selectionMenuLabelBody(title: title, placeholder: placeholder, compact: compact)
                .frame(maxWidth: maxWidth, alignment: .leading)
        }
    }

    private func selectionMenuLabelBody(title: String?, placeholder: String, compact: Bool) -> some View {
        HStack(alignment: .top, spacing: compact ? 6 : 8) {
            Text(title ?? placeholder)
                .font(compact ? .system(size: 11, weight: .regular, design: .rounded) : compactBodyFont)
                .foregroundStyle(.white.opacity(0.96))
                .lineLimit(1)
                .minimumScaleFactor(compact ? 0.72 : 0.78)
                .truncationMode(.tail)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)

            Spacer(minLength: compact ? 2 : 8)

            Image(systemName: "chevron.down")
                .font(.system(size: compact ? 9 : 12, weight: .semibold))
                .foregroundStyle(.white.opacity(0.68))
                .padding(.top, compact ? 2 : 4)
        }
        .padding(.horizontal, compact ? 7 : 12)
        .padding(.vertical, compact ? 5 : 7)
        .frame(minHeight: compact ? 34 : 44, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(.ultraThinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(.white.opacity(0.16), lineWidth: 1)
                )
        )
        .contentShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func compareTargetsByVisibilityThenIdentifier(_ lhs: SingleNightTargetChoice, _ rhs: SingleNightTargetChoice) -> Bool {
        let lhsVisibleFrom = visibleTargetMetadata[lhs.id]?.visibleFrom
        let rhsVisibleFrom = visibleTargetMetadata[rhs.id]?.visibleFrom

        if let dateOrder = compareOptionalDates(lhsVisibleFrom, rhsVisibleFrom, ascending: true) {
            return dateOrder
        }

        return compareTargetsByIdentifier(lhs, rhs)
    }

    private func compareTargetsByVisibilityThenName(_ lhs: SingleNightTargetChoice, _ rhs: SingleNightTargetChoice) -> Bool {
        let lhsVisibleFrom = visibleTargetMetadata[lhs.id]?.visibleFrom
        let rhsVisibleFrom = visibleTargetMetadata[rhs.id]?.visibleFrom

        if let dateOrder = compareOptionalDates(lhsVisibleFrom, rhsVisibleFrom, ascending: true) {
            return dateOrder
        }

        let nameComparison = lhs.name.localizedStandardCompare(rhs.name)
        if nameComparison == .orderedSame {
            return compareTargetsByIdentifier(lhs, rhs)
        }
        return nameComparison == .orderedAscending
    }

    private func compareTargetsForSelectedSort(_ lhs: SingleNightTargetChoice, _ rhs: SingleNightTargetChoice) -> Bool {
        let lhsVisibility = visibleTargetMetadata[lhs.id]
        let rhsVisibility = visibleTargetMetadata[rhs.id]

        switch targetSortMode {
        case .firstViewable:
            if let dateOrder = compareOptionalDates(lhsVisibility?.visibleFrom, rhsVisibility?.visibleFrom, ascending: true) {
                return dateOrder
            }
        case .zenith:
            if let dateOrder = compareOptionalDates(lhsVisibility?.zenithDate, rhsVisibility?.zenithDate, ascending: true) {
                return dateOrder
            }
        case .targetIdentifier:
            return compareTargetsByIdentifier(lhs, rhs)
        case .targetName:
            return compareTargetsByName(lhs, rhs)
        }

        return compareTargetsByIdentifier(lhs, rhs)
    }

    private func compareOptionalDates(_ lhs: Date?, _ rhs: Date?, ascending: Bool) -> Bool? {
        switch (lhs, rhs) {
        case let (.some(lhsDate), .some(rhsDate)) where lhsDate != rhsDate:
            return ascending ? lhsDate < rhsDate : lhsDate > rhsDate
        case (.some, nil):
            return true
        case (nil, .some):
            return false
        default:
            return nil
        }
    }

    private func compareTargetsByIdentifier(_ lhs: SingleNightTargetChoice, _ rhs: SingleNightTargetChoice) -> Bool {
        let identifierComparison = lhs.identifier.localizedStandardCompare(rhs.identifier)
        if identifierComparison == .orderedSame {
            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
        return identifierComparison == .orderedAscending
    }

    private func compareTargetsByName(_ lhs: SingleNightTargetChoice, _ rhs: SingleNightTargetChoice) -> Bool {
        let nameComparison = lhs.name.localizedStandardCompare(rhs.name)
        if nameComparison == .orderedSame {
            return compareTargetsByIdentifier(lhs, rhs)
        }
        return nameComparison == .orderedAscending
    }

    private func targetVisibilitySummary(for target: SingleNightTargetChoice) -> String? {
        guard let visibility = visibleTargetMetadata[target.id] else { return nil }

        let firstVisibleText = formattedSolarEvent(visibility.visibleFrom)
        let zenithText = formattedSolarEvent(visibility.zenithDate)
        let altitudeText = formattedWholeAngle(visibility.zenithAltitudeDegrees)

        return "First \(firstVisibleText) • Zenith \(zenithText) @ \(altitudeText)°"
    }

    private func targetMetricBlock(title: String, value: String) -> some View {
        VStack(alignment: .center, spacing: 7) {
            Text(title.uppercased())
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(labelColor.opacity(0.82))
                .multilineTextAlignment(.center)

            Text(value)
                .font(.system(size: 14, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: 92, alignment: .center)
        .background(singleNightCardBackground(cornerRadius: 18, fill: .thinMaterial))
    }

    private var viewingInfoMetricBlock: some View {
        VStack(alignment: .center, spacing: 4) {
            Text("VIEWING INFO")
                .font(heroMetricTitleFont)
                .foregroundStyle(labelColor.opacity(0.92))
                .multilineTextAlignment(.center)

            Text(
                "Sun Below Horizon \(formattedSolarEvent(solarEvents.start)) to \(formattedSolarEvent(solarEvents.end))"
            )
                .font(heroMetricBodyFont)
                .foregroundStyle(.white)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.76)

            Text(
                "Sun Below Horizon GMT \(formattedSolarEventGMT(solarEvents.start)) to \(formattedSolarEventGMT(solarEvents.end))"
            )
                .font(heroMetricCaptionFont)
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.70)
                .multilineTextAlignment(.center)
        }
    }

    private func compactInlineMetric(_ text: String) -> some View {
        Text(text)
            .font(compactBodyFont)
            .foregroundStyle(.white.opacity(0.84))
            .lineLimit(1)
            .minimumScaleFactor(0.88)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(singleNightCardBackground(cornerRadius: 14, fill: .thinMaterial))
    }

    private func singleNightCardBackground(
        cornerRadius: CGFloat = 30,
        fill: Material = .thinMaterial
    ) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(fill)

            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .fill(Color(red: 0.03, green: 0.08, blue: 0.26).opacity(0.42))
        }
        .compositingGroup()
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .stroke(.white.opacity(0.16), lineWidth: 1)
        )
    }

    private var currentSingleNightMoonPhase: MoonPhaseSnapshot {
        MoonPhaseService.approximateSnapshot(for: referenceDate)
    }

    private var heroObservationInfoBlocks: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 8) {
                heroMetricFrame(viewingInfoMetricBlock)
                heroMetricFrame(observationWeatherMetricBlock)
                heroMetricFrame(weatherSourceMetricBlock)
            }

            VStack(alignment: .center, spacing: 8) {
                heroMetricFrame(viewingInfoMetricBlock)
                heroMetricFrame(observationWeatherMetricBlock)
                heroMetricFrame(weatherSourceMetricBlock)
            }
        }
    }

    private func heroMetricFrame<Content: View>(_ content: Content) -> some View {
        content
            .padding(8)
            .frame(width: heroMetricWidth, height: heroMetricHeight, alignment: .center)
            .background(singleNightCardBackground(cornerRadius: 18, fill: .thinMaterial))
    }

    private var observationWeatherMetricBlock: some View {
        VStack(alignment: .center, spacing: 4) {
            Text("WEATHER AT SUNSET")
                .font(heroMetricTitleFont)
                .foregroundStyle(labelColor.opacity(0.92))
                .multilineTextAlignment(.center)

            if isLoadingObservationWeather {
                ProgressView()
                    .controlSize(.small)
            } else if let observationWeatherSnapshot {
                HStack(spacing: 5) {
                    Image(systemName: cloudSymbolName(for: observationWeatherSnapshot.cloudCoverPercent))
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.94))

                    Text("Cloud \(observationWeatherSnapshot.cloudCoverPercent)%")
                        .font(heroMetricBodyFont)
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
                .fixedSize(horizontal: false, vertical: true)

                Text(
                    "Sunset \(formattedTemperature(observationWeatherSnapshot.sunsetTemperatureFahrenheit)) • Low \(formattedTemperature(observationWeatherSnapshot.overnightLowTemperatureFahrenheit))"
                )
                .font(heroMetricCaptionFont)
                .foregroundStyle(.white.opacity(0.90))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.76)
            } else {
                Text(observationWeatherMessage.isEmpty ? "Forecast unavailable" : observationWeatherMessage)
                    .font(heroMetricCaptionFont)
                    .foregroundStyle(.white.opacity(0.90))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.76)
            }
        }
    }

    private func cloudSymbolName(for cloudCoverPercent: Int) -> String {
        switch cloudCoverPercent {
        case 0 ..< 20:
            return "sun.max"
        case 20 ..< 55:
            return "cloud.sun"
        case 55 ..< 85:
            return "cloud"
        default:
            return "cloud.fill"
        }
    }

    private var weatherSourceMetricBlock: some View {
        VStack(alignment: .center, spacing: 4) {
            Text("WEATHER / SUNRISE SOURCE")
                .font(heroMetricTitleFont)
                .foregroundStyle(labelColor.opacity(0.92))
                .multilineTextAlignment(.center)

            if isResolvingObservationCountry {
                ProgressView()
                    .controlSize(.small)
            } else {
                Text(weatherSource.name)
                    .font(heroMetricBodyFont)
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.76)
            }

            Text(weatherSourceSubtitle)
                .font(heroMetricCaptionFont)
                .foregroundStyle(.white.opacity(0.90))
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
                .minimumScaleFactor(0.76)
        }
    }

    private var singleNightMoonInfoBlock: some View {
        HStack(alignment: .center, spacing: 10) {
            Spacer(minLength: 0)

            VStack(alignment: .leading, spacing: 4) {
                Text("MOON INFO")
                    .font(compactCaptionFont)
                    .foregroundStyle(labelColor)

                Text(currentSingleNightMoonPhase.phaseName)
                    .font(compactStrongFont)
                    .foregroundStyle(labelColor)
                    .fixedSize(horizontal: false, vertical: true)

                Text(selectedLocation?.name ?? "Choose a saved location")
                    .font(compactBodyFont)
                    .foregroundStyle(labelColor)
                    .fixedSize(horizontal: false, vertical: true)

                Text(selectedLocation.map { "Bortle \($0.normalizedBortleClass)" } ?? "Bortle unavailable")
                    .font(compactBodyFont)
                    .foregroundStyle(labelColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            CraterMoonPhaseIconButton(
                snapshot: currentSingleNightMoonPhase,
                backgroundStyle: .midnightBlue,
                size: 58,
                locationName: selectedLocation?.name,
                bortleText: selectedLocation.map { "Bortle \($0.normalizedBortleClass)" }
            )
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .trailing)
        .background(singleNightCardBackground(cornerRadius: 20, fill: .thinMaterial))
    }

    private var dsoLimitingMagnitude: Double {
        clampedDSOLimitingMagnitude(Double(dsoLimitingMagnitudeText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? Self.defaultDSOLimitingMagnitude)
    }

    private var targetSkyLimitTexts: [String] {
        [
            targetAzimuthLowLimitText,
            targetAzimuthHighLimitText,
            targetAltitudeLowLimitText,
            targetAltitudeHighLimitText
        ]
    }

    private var dsoLimitingMagnitudeBinding: Binding<Double> {
        Binding(
            get: { dsoLimitingMagnitude },
            set: { newValue in
                dsoLimitingMagnitudeText = formattedMagnitudeLimit(clampedDSOLimitingMagnitude(newValue))
            }
        )
    }

    private var targetAzimuthLowLimit: Double {
        clampedTargetDegreeLimit(
            Double(targetAzimuthLowLimitText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? Self.defaultTargetAzimuthLowLimit,
            in: Self.minimumTargetAzimuthLimit ... Self.maximumTargetAzimuthLimit
        )
    }

    private var targetAzimuthHighLimit: Double {
        clampedTargetDegreeLimit(
            Double(targetAzimuthHighLimitText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? Self.defaultTargetAzimuthHighLimit,
            in: Self.minimumTargetAzimuthLimit ... Self.maximumTargetAzimuthLimit
        )
    }

    private var targetAltitudeLowLimit: Double {
        clampedTargetDegreeLimit(
            Double(targetAltitudeLowLimitText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? Self.defaultTargetAltitudeLowLimit,
            in: Self.minimumTargetAltitudeLimit ... Self.maximumTargetAltitudeLimit
        )
    }

    private var targetAltitudeHighLimit: Double {
        clampedTargetDegreeLimit(
            Double(targetAltitudeHighLimitText.trimmingCharacters(in: .whitespacesAndNewlines)) ?? Self.defaultTargetAltitudeHighLimit,
            in: Self.minimumTargetAltitudeLimit ... Self.maximumTargetAltitudeLimit
        )
    }

    private var targetAzimuthLowLimitBinding: Binding<Double> {
        targetDegreeLimitBinding(
            text: $targetAzimuthLowLimitText,
            defaultValue: Self.defaultTargetAzimuthLowLimit,
            range: Self.minimumTargetAzimuthLimit ... Self.maximumTargetAzimuthLimit
        )
    }

    private var targetAzimuthHighLimitBinding: Binding<Double> {
        targetDegreeLimitBinding(
            text: $targetAzimuthHighLimitText,
            defaultValue: Self.defaultTargetAzimuthHighLimit,
            range: Self.minimumTargetAzimuthLimit ... Self.maximumTargetAzimuthLimit
        )
    }

    private var targetAltitudeLowLimitBinding: Binding<Double> {
        targetDegreeLimitBinding(
            text: $targetAltitudeLowLimitText,
            defaultValue: Self.defaultTargetAltitudeLowLimit,
            range: Self.minimumTargetAltitudeLimit ... Self.maximumTargetAltitudeLimit
        )
    }

    private var targetAltitudeHighLimitBinding: Binding<Double> {
        targetDegreeLimitBinding(
            text: $targetAltitudeHighLimitText,
            defaultValue: Self.defaultTargetAltitudeHighLimit,
            range: Self.minimumTargetAltitudeLimit ... Self.maximumTargetAltitudeLimit
        )
    }

    private var availableTargetTypes: [String] {
        availableTargetTypeOptions.map(\.name)
    }

    private var availableTargetTypeOptions: [SingleNightTargetTypeFilterOption] {
        let presentTypes = Set(allTargets.map(\.typeName))
        let counts = targetTypeCounts(for: targetDatabaseFilteredTargets)
        let requestedOrder = [
            DSOType.galaxy.displayName,
            DSOType.emissionNebula.displayName,
            DSOType.reflectionNebula.displayName,
            DSOType.planetaryNebula.displayName,
            DSOType.darkNebula.displayName,
            DSOType.supernovaRemnant.displayName,
            TransientType.supernova.displayName,
            DSOType.openCluster.displayName,
            DSOType.globularCluster.displayName,
            TransientType.comet.displayName,
            TransientType.asteroid.displayName,
            DSOType.asterism.displayName,
            transientFilterLabel
        ]
        let orderedTypes = requestedOrder.filter { presentTypes.contains($0) || $0 == transientFilterLabel }
        let extraTypes = presentTypes.subtracting(orderedTypes).sorted()
        let includesTransientTargets = allTargets.contains { $0.sourceKind == .transient }
        let visibleOrderedTypes = orderedTypes.filter { $0 != transientFilterLabel || includesTransientTargets }
        return (visibleOrderedTypes + extraTypes)
            .map { SingleNightTargetTypeFilterOption(name: $0, count: counts[$0] ?? 0) }
    }

    private func targetTypeCounts(for targets: [SingleNightTargetChoice]) -> [String: Int] {
        var counts: [String: Int] = [:]
        for target in targets {
            counts[target.typeName, default: 0] += 1
            if target.sourceKind == .transient {
                counts[transientFilterLabel, default: 0] += 1
            }
        }
        return counts
    }

    private func targetTypeBinding(for typeName: String) -> Binding<Bool> {
        Binding(
            get: { selectedTargetTypeNames.contains(typeName) },
            set: { isSelected in
                didManuallyAdjustTargetTypes = true
                if isSelected {
                    selectedTargetTypeNames.insert(typeName)
                } else {
                    selectedTargetTypeNames.remove(typeName)
                }
            }
        )
    }

    private func targetSortBinding(for option: SingleNightTargetSortMode) -> Binding<Bool> {
        Binding(
            get: { targetSortMode == option },
            set: { isSelected in
                guard isSelected else { return }
                targetSortMode = option
                syncSelectedTarget()
                persistSingleNightDraft()
            }
        )
    }

    private func targetMatchesSelectedTypes(_ target: SingleNightTargetChoice) -> Bool {
        if selectedTargetTypeNames.contains(target.typeName) {
            return true
        }

        if selectedTargetTypeNames.contains(transientFilterLabel), target.sourceKind == .transient {
            return true
        }

        return false
    }

    private func targetPassesDSOLimitingMagnitude(_ target: SingleNightTargetChoice) -> Bool {
        guard target.sourceKind == .deepSky else { return true }
        guard let magnitude = target.magnitude else { return true }
        return magnitude <= dsoLimitingMagnitude
    }

    private func targetPassesSkyLimits(_ skyPosition: LocalSkyPosition) -> Bool {
        let lowAltitude = min(targetAltitudeLowLimit, targetAltitudeHighLimit)
        let highAltitude = max(targetAltitudeLowLimit, targetAltitudeHighLimit)
        guard skyPosition.altitudeDegrees >= lowAltitude,
              skyPosition.altitudeDegrees <= highAltitude else {
            return false
        }

        return azimuth(
            skyPosition.azimuthDegrees,
            isWithinLowLimit: targetAzimuthLowLimit,
            highLimit: targetAzimuthHighLimit
        )
    }

    private func azimuth(_ azimuthDegrees: Double, isWithinLowLimit lowLimit: Double, highLimit: Double) -> Bool {
        let low = normalizedAzimuthLimit(lowLimit)
        let high = normalizedAzimuthLimit(highLimit)

        if abs(highLimit - lowLimit) >= 360 || (lowLimit <= 0 && highLimit >= 360) {
            return true
        }

        let azimuth = normalizedAzimuthLimit(azimuthDegrees)
        if low <= high {
            return azimuth >= low && azimuth <= high
        }

        return azimuth >= low || azimuth <= high
    }

    private func normalizeDSOLimitingMagnitudeText() {
        dsoLimitingMagnitudeText = formattedMagnitudeLimit(dsoLimitingMagnitude)
    }

    private func normalizeTargetSkyLimitTexts() {
        targetAzimuthLowLimitText = formattedDegreeLimit(targetAzimuthLowLimit)
        targetAzimuthHighLimitText = formattedDegreeLimit(targetAzimuthHighLimit)
        targetAltitudeLowLimitText = formattedDegreeLimit(targetAltitudeLowLimit)
        targetAltitudeHighLimitText = formattedDegreeLimit(targetAltitudeHighLimit)
    }

    private func clampedDSOLimitingMagnitude(_ value: Double) -> Double {
        min(max(value, Self.minimumDSOLimitingMagnitude), Self.maximumDSOLimitingMagnitude)
    }

    private func clampedTargetDegreeLimit(_ value: Double, in range: ClosedRange<Double>) -> Double {
        min(max(value, range.lowerBound), range.upperBound)
    }

    private func normalizedAzimuthLimit(_ value: Double) -> Double {
        var adjusted = value.truncatingRemainder(dividingBy: 360)
        if adjusted < 0 { adjusted += 360 }
        return adjusted
    }

    private func targetDegreeLimitBinding(
        text: Binding<String>,
        defaultValue: Double,
        range: ClosedRange<Double>
    ) -> Binding<Double> {
        Binding(
            get: {
                clampedTargetDegreeLimit(
                    Double(text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines)) ?? defaultValue,
                    in: range
                )
            },
            set: { newValue in
                text.wrappedValue = formattedDegreeLimit(clampedTargetDegreeLimit(newValue, in: range))
            }
        )
    }

    private func formattedMagnitudeLimit(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0 ... 1)))
    }

    private func formattedDegreeLimit(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0 ... 1)))
    }

    private var lastTargetDatabaseUpdateText: String {
        if let lastSuccessfulRefresh = DatabaseRefreshService.lastSuccessfulRefreshDate() {
            return "Last Update \(formattedUpdateDate(lastSuccessfulRefresh))"
        }

        if let bundledFeedDate = transientItems.map(\.lastUpdated).max() {
            return "Last Update \(formattedUpdateDate(bundledFeedDate))"
        }

        return "Last Update not yet available"
    }

    private func formattedUpdateDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .shortened)
    }

    private func locationAddressSummary(for site: ObservingSite) -> String {
        if let formattedAddress = normalizedText(site.formattedAddress) {
            return formattedAddress
        }

        if let countryName = normalizedText(site.countryName) {
            return countryName
        }

        return "Address not yet stored for this location."
    }

    private func locationCoordinateSummary(for site: ObservingSite) -> String {
        "Lat \(formattedCoordinate(site.latitude)) • Lon \(formattedCoordinate(site.longitude))"
    }

    private func locationLatitudeSummary(for site: ObservingSite) -> String {
        "Lat \(formattedCoordinate(site.latitude))"
    }

    private func locationLongitudeSummary(for site: ObservingSite) -> String {
        "Lon \(formattedCoordinate(site.longitude))"
    }

    private func locationAltitudeSummary(for site: ObservingSite) -> String {
        let altitudeFeet = site.elevationMeters * 3.28084
        return "Elevation \(site.elevationMeters.formatted(.number.precision(.fractionLength(0)))) m / \(altitudeFeet.formatted(.number.precision(.fractionLength(0)))) ft"
    }

    private func formattedCoordinate(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(5)))
    }

    private func formattedAngle(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(1)))
    }

    private func formattedWholeAngle(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }

    private func formattedTemperature(_ value: Double) -> String {
        "\(value.formatted(.number.precision(.fractionLength(0))))°F"
    }

    private func formattedSolarEvent(_ date: Date?) -> String {
        guard let date else { return "--" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        formatter.timeZone = observationTimeZone
        return formatter.string(from: date)
    }

    private func formattedSolarEventGMT(_ date: Date?) -> String {
        guard let date else { return "--" }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "HH:mm"
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter.string(from: date)
    }

    private var observationTimeZone: TimeZone {
        TimeZone(identifier: observationTimeZoneIdentifier) ?? .current
    }

    private var availableTimeZoneIdentifiers: [String] {
        let preferredIdentifiers = [
            observationTimeZoneIdentifier,
            selectedLocation?.timeZoneIdentifier,
            TimeZone.current.identifier,
            "America/Denver",
            "America/Los_Angeles",
            "America/Chicago",
            "America/New_York",
            "UTC"
        ]
        .compactMap { $0 }

        let remainingIdentifiers = TimeZone.knownTimeZoneIdentifiers.filter { identifier in
            !preferredIdentifiers.contains(identifier)
        }

        return preferredIdentifiers + remainingIdentifiers
    }

    private func timeZoneDisplayName(for identifier: String) -> String {
        guard let timeZone = TimeZone(identifier: identifier) else { return identifier }
        let abbreviation = timeZone.abbreviation(for: referenceDate) ?? identifier
        return "\(abbreviation) • \(identifier)"
    }

    private func timeZoneMenuLabel(for identifier: String) -> String {
        guard let timeZone = TimeZone(identifier: identifier) else { return identifier }
        let abbreviation = timeZone.abbreviation(for: referenceDate) ?? identifier
        let shortName = identifier
            .split(separator: "/")
            .last
            .map { String($0).replacingOccurrences(of: "_", with: " ") }
            ?? identifier
        return "\(abbreviation) • \(shortName)"
    }

    private func normalizedText(_ text: String?) -> String? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

}

private struct SingleNightSaveListSheet: View {
    let title: String
    let subtitle: String
    let locationName: String?
    let targetCount: Int
    @Binding var name: String
    let onSave: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    private var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.yellow)

                Text(subtitle)
                    .font(AppTypography.body)
                    .foregroundStyle(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 12) {
                infoPill(title: "Targets", value: "\(targetCount)")
                infoPill(title: "Default Location", value: locationName ?? "Not selected")
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Saved List Name")
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(.white)

                TextField("Enter a name (example: Spring Galaxies)", text: $name)
                    .textFieldStyle(.roundedBorder)
            }

            HStack {
                Spacer(minLength: 0)

                Button("Cancel") {
                    dismiss()
                }
                .buttonStyle(.bordered)

                Button {
                    onSave(trimmedName)
                } label: {
                    Label("Save List", systemImage: "tray.and.arrow.down")
                }
                .buttonStyle(.borderedProminent)
                .disabled(trimmedName.isEmpty || targetCount == 0)
            }
        }
        .padding(22)
        .frame(minWidth: 560)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )
        )
        .padding(24)
    }

    private func infoPill(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title.uppercased())
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.70))
            Text(value)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            Capsule()
                .fill(.thinMaterial)
                .overlay(
                    Capsule()
                        .stroke(.white.opacity(0.16), lineWidth: 1)
                )
        )
    }
}

private struct SingleNightLocationPickerSheet: View {
    let sites: [ObservingSite]
    @Binding var selectedLocationID: UUID?
    let currentDefaultLocationID: UUID?
    let onCancel: () -> Void
    let onSetDefault: (UUID) -> Void

    private var selectedSite: ObservingSite? {
        guard let selectedLocationID else { return nil }
        return sites.first(where: { $0.id == selectedLocationID })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Change Location")
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.yellow)

                Text("Select one saved observing location, then set it as the default for this plan.")
                    .font(AppTypography.body)
                    .foregroundStyle(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 8) {
                    ForEach(sites) { site in
                        locationRow(site)
                    }
                }
                .padding(.trailing, 4)
            }
            .frame(minHeight: 220, maxHeight: 360)

            HStack {
                if let selectedSite {
                    Text("Selected: \(selectedSite.name)")
                        .font(AppTypography.body)
                        .foregroundStyle(.white.opacity(0.84))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                } else {
                    Text("Select a location before setting the default.")
                        .font(AppTypography.body)
                        .foregroundStyle(.white.opacity(0.74))
                }

                Spacer(minLength: 0)

                Button("Cancel") {
                    onCancel()
                }
                .buttonStyle(.bordered)

                Button {
                    if let selectedLocationID {
                        onSetDefault(selectedLocationID)
                    }
                } label: {
                    Label("Set to Default", systemImage: "checkmark.circle.fill")
                }
                .buttonStyle(.borderedProminent)
                .disabled(selectedLocationID == nil)
            }
        }
        .padding(22)
        .frame(minWidth: 580, minHeight: 420)
        .background(
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 28, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )
        )
        .padding(24)
    }

    private func locationRow(_ site: ObservingSite) -> some View {
        let isSelected = selectedLocationID == site.id
        let isDefault = currentDefaultLocationID == site.id

        return Toggle(isOn: locationSelectionBinding(for: site)) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(site.name)
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(.white.opacity(0.96))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    if isDefault {
                        Text("Current Default")
                            .font(.system(size: 10, weight: .semibold, design: .rounded))
                            .foregroundStyle(Color.yellow.opacity(0.92))
                    }
                }

                Text(locationDetail(for: site))
                    .font(.system(size: 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.76))
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .toggleStyle(.checkbox)
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isSelected ? Color.accentColor.opacity(0.24) : Color.white.opacity(0.06))
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(isSelected ? Color.accentColor.opacity(0.42) : Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }

    private func locationSelectionBinding(for site: ObservingSite) -> Binding<Bool> {
        Binding(
            get: { selectedLocationID == site.id },
            set: { isSelected in
                if isSelected {
                    selectedLocationID = site.id
                } else if selectedLocationID == site.id {
                    selectedLocationID = nil
                }
            }
        )
    }

    private func locationDetail(for site: ObservingSite) -> String {
        let address = normalizedText(site.formattedAddress) ?? normalizedText(site.countryName) ?? "Address not stored"
        let elevationFeet = site.elevationMeters * 3.28084
        return "\(address) • Lat \(site.latitude.formatted(.number.precision(.fractionLength(5)))) • Lon \(site.longitude.formatted(.number.precision(.fractionLength(5)))) • Elevation \(site.elevationMeters.formatted(.number.precision(.fractionLength(0)))) m / \(elevationFeet.formatted(.number.precision(.fractionLength(0)))) ft"
    }

    private func normalizedText(_ text: String?) -> String? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

#if canImport(AppKit)
private struct SingleNightObservationPrintLayout {
    struct TableRow {
        let cells: [String]
    }

    let pageWidth: CGFloat
    let pageHeight: CGFloat
    let margin: CGFloat
    let lineHeight: CGFloat
    let rowHeight: CGFloat
    let title: String
    let printedAt: String
    let referenceDate: String
    let detailLines: [String]
    let headerCells: [String]
    let columnWidths: [CGFloat]
    let pageRows: [[TableRow]]
}

private final class SingleNightObservationPrintableView: NSView {
    private let layout: SingleNightObservationPrintLayout

    override var isFlipped: Bool { true }

    init(layout: SingleNightObservationPrintLayout) {
        self.layout = layout
        let totalPages = max(layout.pageRows.count, 1)
        super.init(
            frame: NSRect(
                x: 0,
                y: 0,
                width: layout.pageWidth,
                height: layout.pageHeight * CGFloat(totalPages)
            )
        )
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func knowsPageRange(_ range: NSRangePointer) -> Bool {
        range.pointee = NSRange(location: 1, length: max(layout.pageRows.count, 1))
        return true
    }

    override func rectForPage(_ page: Int) -> NSRect {
        NSRect(
            x: 0,
            y: CGFloat(page - 1) * layout.pageHeight,
            width: layout.pageWidth,
            height: layout.pageHeight
        )
    }

    override func draw(_ dirtyRect: NSRect) {
        super.draw(dirtyRect)

        for pageIndex in 0 ..< max(layout.pageRows.count, 1) {
            let pageRect = NSRect(
                x: 0,
                y: CGFloat(pageIndex) * layout.pageHeight,
                width: layout.pageWidth,
                height: layout.pageHeight
            )

            guard dirtyRect.intersects(pageRect) else { continue }
            drawPage(at: pageRect, pageIndex: pageIndex)
        }
    }

    private func drawPage(at pageRect: NSRect, pageIndex: Int) {
        NSColor.white.setFill()
        pageRect.fill()

        let bodyAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor.black
        ]

        let titleAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 12, weight: .bold),
            .foregroundColor: NSColor.black
        ]

        let centeredBodyAttributes: [NSAttributedString.Key: Any] = [
            .font: NSFont.monospacedSystemFont(ofSize: 10, weight: .regular),
            .foregroundColor: NSColor.black,
            .paragraphStyle: centeredParagraphStyle()
        ]

        var currentY = pageRect.minY + layout.margin
        let originX = pageRect.minX + layout.margin
        let drawWidth = layout.pageWidth - (layout.margin * 2)

        drawCenteredLine(layout.title, attributes: titleAttributes, x: originX, y: currentY, width: drawWidth)
        currentY += layout.lineHeight
        drawCenteredLine(layout.printedAt, attributes: centeredBodyAttributes, x: originX, y: currentY, width: drawWidth)
        currentY += layout.lineHeight
        drawCenteredLine(layout.referenceDate, attributes: centeredBodyAttributes, x: originX, y: currentY, width: drawWidth)
        currentY += layout.lineHeight

        if pageIndex == 0 {
            for detail in layout.detailLines {
                drawLine(detail, attributes: bodyAttributes, x: originX, y: currentY, width: drawWidth)
                currentY += layout.lineHeight
            }
        }

        currentY += 6
        let tableOrigin = CGPoint(x: originX, y: currentY)
        let rows = layout.pageRows.indices.contains(pageIndex) ? layout.pageRows[pageIndex] : []
        drawTable(
            at: tableOrigin,
            headers: layout.headerCells,
            rows: rows,
            bodyAttributes: bodyAttributes
        )
    }

    private func drawLine(
        _ text: String,
        attributes: [NSAttributedString.Key: Any],
        x: CGFloat,
        y: CGFloat,
        width: CGFloat
    ) {
        let attributed = NSAttributedString(string: text, attributes: attributes)
        attributed.draw(
            in: NSRect(
                x: x,
                y: y,
                width: width,
                height: max(layout.rowHeight, layout.lineHeight)
            )
        )
    }

    private func drawCenteredLine(
        _ text: String,
        attributes: [NSAttributedString.Key: Any],
        x: CGFloat,
        y: CGFloat,
        width: CGFloat
    ) {
        let attributed = NSAttributedString(string: text, attributes: attributes)
        attributed.draw(
            in: NSRect(
                x: x,
                y: y,
                width: width,
                height: layout.lineHeight
            )
        )
    }

    private func drawTable(
        at origin: CGPoint,
        headers: [String],
        rows: [SingleNightObservationPrintLayout.TableRow],
        bodyAttributes: [NSAttributedString.Key: Any]
    ) {
        let columnWidths = layout.columnWidths
        let tableWidth = columnWidths.reduce(0, +)
        let tableHeight = layout.rowHeight * CGFloat(rows.count + 1)
        let tableRect = NSRect(x: origin.x, y: origin.y, width: tableWidth, height: tableHeight)

        NSColor(calibratedWhite: 0.95, alpha: 1.0).setFill()
        NSRect(x: tableRect.minX, y: tableRect.minY, width: tableRect.width, height: layout.rowHeight).fill()

        NSColor.black.setStroke()
        let borderPath = NSBezierPath(rect: tableRect)
        borderPath.lineWidth = 1
        borderPath.stroke()

        var xCursor = origin.x
        for (index, width) in columnWidths.enumerated() {
            let headerRect = NSRect(x: xCursor, y: origin.y, width: width, height: layout.rowHeight)
            drawCell(
                text: headers.indices.contains(index) ? headers[index] : "",
                in: headerRect,
                attributes: bodyAttributes,
                centered: true
            )

            if index > 0 {
                let divider = NSBezierPath()
                divider.move(to: CGPoint(x: xCursor, y: tableRect.minY))
                divider.line(to: CGPoint(x: xCursor, y: tableRect.maxY))
                divider.lineWidth = 0.8
                divider.stroke()
            }

            xCursor += width
        }

        for rowIndex in rows.indices {
            let rowTopY = origin.y + layout.rowHeight * CGFloat(rowIndex + 1)
            let divider = NSBezierPath()
            divider.move(to: CGPoint(x: tableRect.minX, y: rowTopY))
            divider.line(to: CGPoint(x: tableRect.maxX, y: rowTopY))
            divider.lineWidth = 0.8
            divider.stroke()

            var cellX = origin.x
            for (columnIndex, width) in columnWidths.enumerated() {
                let cellRect = NSRect(x: cellX, y: rowTopY, width: width, height: layout.rowHeight)
                let value = rows[rowIndex].cells.indices.contains(columnIndex) ? rows[rowIndex].cells[columnIndex] : ""
                drawCell(text: value, in: cellRect, attributes: bodyAttributes, centered: false)
                cellX += width
            }
        }
    }

    private func drawCell(
        text: String,
        in rect: NSRect,
        attributes: [NSAttributedString.Key: Any],
        centered: Bool
    ) {
        let style = NSMutableParagraphStyle()
        style.alignment = centered ? .center : .left
        style.lineBreakMode = .byTruncatingTail

        var cellAttributes = attributes
        cellAttributes[.paragraphStyle] = style

        let insetRect = rect.insetBy(dx: 4, dy: 2)
        let attributed = NSAttributedString(string: text, attributes: cellAttributes)
        attributed.draw(in: insetRect)
    }

    private func centeredParagraphStyle() -> NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        style.alignment = .center
        style.lineBreakMode = .byTruncatingTail
        return style
    }
}

private enum SingleNightObservationPrintService {
    @MainActor
    static func printCurrentList(
        location: ObservingSite?,
        targets: [SingleNightTargetChoice],
        referenceDate: Date
    ) {
        let printedAt = Date()
        let layout = buildLayout(
            location: location,
            targets: targets,
            referenceDate: referenceDate,
            printedAt: printedAt
        )
        let printInfo = makePrintInfo(for: layout)

        _ = writePDFData(
            for: layout,
            printInfo: printInfo,
            to: temporaryPDFURL(printedAt: printedAt)
        )

        let printableView = SingleNightObservationPrintableView(layout: layout)
        let operation = NSPrintOperation(view: printableView, printInfo: printInfo)
        operation.showsPrintPanel = true
        operation.showsProgressPanel = true
        operation.run()
    }

    @MainActor
    static func saveCurrentListAsPDF(
        location: ObservingSite?,
        targets: [SingleNightTargetChoice],
        referenceDate: Date
    ) {
        let printedAt = Date()
        let layout = buildLayout(
            location: location,
            targets: targets,
            referenceDate: referenceDate,
            printedAt: printedAt
        )
        let printInfo = makePrintInfo(for: layout)

        let panel = NSSavePanel()
        panel.canCreateDirectories = true
        panel.allowedContentTypes = [.pdf]
        panel.nameFieldStringValue = suggestedPDFFileName(printedAt: printedAt)
        panel.title = "Save Current Single Night List as PDF"
        panel.prompt = "Save PDF"

        guard panel.runModal() == .OK, let url = panel.url else { return }
        _ = writePDFData(for: layout, printInfo: printInfo, to: url)
    }

    private static func buildLayout(
        location: ObservingSite?,
        targets: [SingleNightTargetChoice],
        referenceDate: Date,
        printedAt: Date
    ) -> SingleNightObservationPrintLayout {
        let pageWidth: CGFloat = 612
        let pageHeight: CGFloat = 792
        let margin: CGFloat = 18
        let lineHeight: CGFloat = 15
        let rowHeight: CGFloat = 17
        let printableHeight = pageHeight - (margin * 2)
        let title = "Current Single Night List"
        let printedAtText = "Printed \(printedAt.formatted(date: .abbreviated, time: .shortened))"
        let observationDateText = "Observation \(referenceDate.formatted(date: .abbreviated, time: .shortened))"

        var detailLines: [String] = [
            "Observation Location: \(location?.name ?? "Not selected")",
            "Address: \(location.map(locationAddressSummary(for:)) ?? "Not available")"
        ]

        if let location {
            detailLines.append(
                "Coordinates: Lat \(location.latitude.formatted(.number.precision(.fractionLength(5))))  Lon \(location.longitude.formatted(.number.precision(.fractionLength(5))))"
            )
            detailLines.append("Elevation: \(location.elevationMeters.formatted(.number.precision(.fractionLength(0)))) m")
            detailLines.append("Bortle: \(location.normalizedBortleClass)")
        }

        let solarEvents = solarEvents(for: location, referenceDate: referenceDate)
        if let nightStart = solarEvents.start,
           let nightEnd = solarEvents.end {
            detailLines.append("Sun Below Horizon: \(formattedSolarEvent(nightStart, location: location)) to \(formattedSolarEvent(nightEnd, location: location))")
        }

        let headerCells = ["Identifier", "Name", "Type", "Obs Time", "Azimuth", "Altitude"]
        let columnWidths: [CGFloat] = [92, 170, 92, 74, 96, 52]

        let rowLines: [SingleNightObservationPrintLayout.TableRow]
        if targets.isEmpty {
            rowLines = [
                .init(cells: ["No targets", "No targets have been added yet.", "", "", "", ""])
            ]
        } else {
            rowLines = targets.map { target in
                let coordinates = target.coordinates(at: referenceDate)
                let skyPosition = location.map {
                    SkyCoordinateService.localSkyPosition(
                        rightAscensionHours: coordinates.rightAscensionHours,
                        declinationDegrees: coordinates.declinationDegrees,
                        site: $0,
                        at: referenceDate
                    )
                }
                let azimuthText = skyPosition.map {
                    "\(formattedWholeAngle($0.azimuthDegrees))° \($0.magneticCardinalDirection)"
                } ?? "--"
                let altitudeText = skyPosition.map {
                    "\(formattedWholeAngle($0.altitudeDegrees))°"
                } ?? "--"
                let observationTimeText = formattedObservationTime(referenceDate)

                return .init(
                    cells: [
                        target.identifier,
                        target.name,
                        target.typeName,
                        observationTimeText,
                        azimuthText,
                        altitudeText
                    ]
                )
            }
        }

        let firstPageStaticHeight =
            (lineHeight * CGFloat(3 + detailLines.count + 2)) + 4
        let laterPageStaticHeight =
            lineHeight * CGFloat(3 + 2) + 4
        let firstPageRowCapacity = max(Int((printableHeight - firstPageStaticHeight) / rowHeight), 1)
        let laterPageRowCapacity = max(Int((printableHeight - laterPageStaticHeight) / rowHeight), 1)

        var remainingRows = rowLines[...]
        var pages: [[SingleNightObservationPrintLayout.TableRow]] = []

        if !remainingRows.isEmpty {
            let firstPageCount = min(firstPageRowCapacity, remainingRows.count)
            pages.append(Array(remainingRows.prefix(firstPageCount)))
            remainingRows.removeFirst(firstPageCount)
        }

        while !remainingRows.isEmpty {
            let pageCount = min(laterPageRowCapacity, remainingRows.count)
            pages.append(Array(remainingRows.prefix(pageCount)))
            remainingRows.removeFirst(pageCount)
        }

        if pages.isEmpty {
            pages = [[]]
        }

        return SingleNightObservationPrintLayout(
            pageWidth: pageWidth,
            pageHeight: pageHeight,
            margin: margin,
            lineHeight: lineHeight,
            rowHeight: rowHeight,
            title: title,
            printedAt: printedAtText,
            referenceDate: observationDateText,
            detailLines: detailLines,
            headerCells: headerCells,
            columnWidths: columnWidths,
            pageRows: pages
        )
    }

    @MainActor
    private static func writePDFData(
        for layout: SingleNightObservationPrintLayout,
        printInfo: NSPrintInfo,
        to url: URL
    ) -> Bool {
        let printableView = SingleNightObservationPrintableView(layout: layout)
        let data = NSMutableData()
        let operation = NSPrintOperation.pdfOperation(
            with: printableView,
            inside: printableView.bounds,
            to: data,
            printInfo: printInfo
        )
        operation.showsPrintPanel = false
        operation.showsProgressPanel = false

        guard operation.run() else { return false }

        do {
            try (data as Data).write(to: url, options: .atomic)
            return true
        } catch {
            NSSound.beep()
            return false
        }
    }

    @MainActor
    private static func makePrintInfo(for layout: SingleNightObservationPrintLayout) -> NSPrintInfo {
        let printInfo = NSPrintInfo.shared.copy() as! NSPrintInfo
        printInfo.paperSize = NSSize(width: layout.pageWidth, height: layout.pageHeight)
        printInfo.leftMargin = layout.margin
        printInfo.rightMargin = layout.margin
        printInfo.topMargin = layout.margin
        printInfo.bottomMargin = layout.margin
        printInfo.horizontalPagination = .automatic
        printInfo.verticalPagination = .automatic
        printInfo.isHorizontallyCentered = false
        printInfo.isVerticallyCentered = false
        return printInfo
    }

    private static func temporaryPDFURL(printedAt: Date) -> URL {
        FileManager.default.temporaryDirectory
            .appendingPathComponent(suggestedPDFFileName(printedAt: printedAt))
    }

    private static func suggestedPDFFileName(printedAt: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH-mm"
        return "Current Single Night List \(formatter.string(from: printedAt)).pdf"
    }

    private static func locationAddressSummary(for site: ObservingSite) -> String {
        let address = site.formattedAddress?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let country = site.countryName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return address.isEmpty ? (country.isEmpty ? "Not available" : country) : address
    }

    private static func solarEvents(for location: ObservingSite?, referenceDate: Date) -> SunBelowHorizonEvents {
        guard let location else {
            return .unavailable
        }
        return SolarHorizonService.sunBelowHorizonEvents(for: location, on: referenceDate)
    }

    private static func formattedSolarEvent(_ date: Date, location: ObservingSite?) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        if let identifier = location?.timeZoneIdentifier,
           let timeZone = TimeZone(identifier: identifier) {
            formatter.timeZone = timeZone
        }
        return formatter.string(from: date)
    }

    private static func formattedWholeAngle(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }

    private static func formattedObservationTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}

private struct SingleNightObservationPrintDocument: View {
    private struct PrintRow: Identifiable {
        let id: String
        let identifierText: String
        let nameText: String
        let typeText: String
        let azimuthText: String
        let altitudeText: String
        let estimatedHeight: CGFloat
    }

    private struct PrintPage: Identifiable {
        let id: Int
        let isFirstPage: Bool
        let rows: [PrintRow]
    }

    let location: ObservingSite?
    let targets: [SingleNightTargetChoice]
    let referenceDate: Date
    let printedAt: Date

    private let pageWidth: CGFloat = 612
    private let pageHeight: CGFloat = 792
    private let pageMargin: CGFloat = 18
    private let pageSpacing: CGFloat = 0
    private let identifierColumnWidth: CGFloat = 88
    private let nameColumnWidth: CGFloat = 188
    private let typeColumnWidth: CGFloat = 82
    private let azimuthColumnWidth: CGFloat = 118
    private let altitudeColumnWidth: CGFloat = 44

    private let pages: [PrintPage]

    init(
        location: ObservingSite?,
        targets: [SingleNightTargetChoice],
        referenceDate: Date,
        printedAt: Date
    ) {
        self.location = location
        self.targets = targets
        self.referenceDate = referenceDate
        self.printedAt = printedAt

        let locationLines = Self.locationLines(for: location, referenceDate: referenceDate)
        let rows = Self.buildPrintRows(
            targets: targets,
            location: location,
            referenceDate: referenceDate,
            identifierColumnWidth: identifierColumnWidth,
            nameColumnWidth: nameColumnWidth,
            typeColumnWidth: typeColumnWidth,
            azimuthColumnWidth: azimuthColumnWidth,
            altitudeColumnWidth: altitudeColumnWidth
        )

        pages = Self.paginatedPages(
            rows: rows,
            locationLines: locationLines,
            printedAt: printedAt,
            pageHeight: pageHeight,
            pageMargin: pageMargin,
            pageWidth: pageWidth
        )
    }

    var pageCount: Int {
        pages.count
    }

    var body: some View {
        VStack(spacing: pageSpacing) {
            ForEach(pages) { page in
                printPage(page)
            }
        }
        .frame(width: pageWidth, alignment: .topLeading)
    }

    private func printPage(_ page: PrintPage) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: page.isFirstPage ? 14 : 10) {
                if page.isFirstPage {
                    Text("Current Single Night List")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)

                    Text(printedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 14, weight: .semibold, design: .rounded))
                        .foregroundStyle(.black.opacity(0.72))

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(Self.locationLines(for: location, referenceDate: referenceDate), id: \.self) { line in
                            Text(line)
                                .foregroundStyle(.black)
                        }
                    }
                    .font(.system(size: 14, weight: .regular, design: .rounded))

                    Divider()

                    Text("Current List Database")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                } else {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Current Single Night List")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.black)

                        Spacer(minLength: 0)

                        Text("Page \(page.id) of \(pages.count)")
                            .font(.system(size: 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.black.opacity(0.72))
                    }

                    Text(printedAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundStyle(.black.opacity(0.72))
                }

                if page.rows.isEmpty {
                    Text("No targets have been added yet.")
                        .font(.system(size: 13, weight: .regular, design: .rounded))
                        .foregroundStyle(.black.opacity(0.72))
                        .padding(.top, 6)
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        printTableHeader

                        ForEach(Array(page.rows.enumerated()), id: \.element.id) { offset, row in
                            if offset > 0 {
                                Divider()
                            }
                            printTableRow(row)
                        }
                    }
                }
            }
            .padding(pageMargin)
            .frame(width: pageWidth, height: pageHeight, alignment: .topLeading)
        }
    }

    private var printTableHeader: some View {
        HStack(alignment: .top, spacing: 8) {
            printHeaderCell("Identifier", width: identifierColumnWidth)
            printHeaderCell("Name", width: nameColumnWidth)
            printHeaderCell("Type", width: typeColumnWidth)
            printHeaderCell("Azimuth", width: azimuthColumnWidth)
            printHeaderCell("Altitude", width: altitudeColumnWidth)
        }
        .padding(.vertical, 4)
    }

    private func printTableRow(_ row: PrintRow) -> some View {
        return HStack(alignment: .top, spacing: 8) {
            printBodyCell(
                row.identifierText,
                width: identifierColumnWidth,
                prominent: true
            )

            printBodyCell(
                row.nameText,
                width: nameColumnWidth,
                prominent: true
            )

            printBodyCell(
                row.typeText,
                width: typeColumnWidth
            )

            printBodyCell(
                row.azimuthText,
                width: azimuthColumnWidth
            )

            printBodyCell(
                row.altitudeText,
                width: altitudeColumnWidth
            )
        }
        .padding(.vertical, 4)
        .frame(height: row.estimatedHeight, alignment: .topLeading)
    }

    private func printHeaderCell(_ text: String, width: CGFloat) -> some View {
        Text(text)
            .font(.system(size: 12, weight: .bold, design: .rounded))
            .foregroundStyle(.black)
            .frame(width: width, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func printBodyCell(_ text: String, width: CGFloat, prominent: Bool = false) -> some View {
        Text(text)
            .font(.system(size: prominent ? 13 : 12, weight: prominent ? .semibold : .regular, design: .rounded))
            .foregroundStyle(.black)
            .frame(width: width, alignment: .leading)
            .lineLimit(1)
            .truncationMode(.tail)
    }

    private static func locationLines(for location: ObservingSite?, referenceDate: Date) -> [String] {
        var lines = [
            "Observation Location: \(location?.name ?? "Not selected")",
            "Address: \(location.map(locationAddressSummary(for:)) ?? "Not available")"
        ]

        if let location {
            lines.append(
                "Coordinates: Lat \(location.latitude.formatted(.number.precision(.fractionLength(5)))) • Lon \(location.longitude.formatted(.number.precision(.fractionLength(5))))"
            )
            lines.append(
                "Elevation: \(location.elevationMeters.formatted(.number.precision(.fractionLength(0)))) m"
            )
            lines.append("Bortle: \(location.normalizedBortleClass)")
        }

        let solarEvents = solarEvents(for: location, referenceDate: referenceDate)
        if let nightStart = solarEvents.start,
           let nightEnd = solarEvents.end {
            lines.append("Sun Below Horizon: \(formattedSolarEvent(nightStart, location: location)) to \(formattedSolarEvent(nightEnd, location: location))")
        }

        return lines
    }

    private static func locationAddressSummary(for site: ObservingSite) -> String {
        let address = site.formattedAddress?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let country = site.countryName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return address.isEmpty ? (country.isEmpty ? "Not available" : country) : address
    }

    private static func solarEvents(for location: ObservingSite?, referenceDate: Date) -> SunBelowHorizonEvents {
        guard let location else {
            return .unavailable
        }
        return SolarHorizonService.sunBelowHorizonEvents(for: location, on: referenceDate)
    }

    private static func formattedSolarEvent(_ date: Date, location: ObservingSite?) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        if let identifier = location?.timeZoneIdentifier,
           let timeZone = TimeZone(identifier: identifier) {
            formatter.timeZone = timeZone
        }
        return formatter.string(from: date)
    }

    private static func formattedWholeAngle(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }

    private static func buildPrintRows(
        targets: [SingleNightTargetChoice],
        location: ObservingSite?,
        referenceDate: Date,
        identifierColumnWidth: CGFloat,
        nameColumnWidth: CGFloat,
        typeColumnWidth: CGFloat,
        azimuthColumnWidth: CGFloat,
        altitudeColumnWidth: CGFloat
    ) -> [PrintRow] {
        targets.map { target in
            let coordinates = target.coordinates(at: referenceDate)
            let skyPosition = location.map {
                SkyCoordinateService.localSkyPosition(
                    rightAscensionHours: coordinates.rightAscensionHours,
                    declinationDegrees: coordinates.declinationDegrees,
                    site: $0,
                    at: referenceDate
                )
            }

            let row = PrintRow(
                id: target.id,
                identifierText: target.identifier,
                nameText: target.name,
                typeText: target.typeName,
                azimuthText: skyPosition.map { "\(formattedWholeAngle($0.azimuthDegrees))° \($0.magneticCardinalDirection)" } ?? "--",
                altitudeText: skyPosition.map { "\(formattedWholeAngle($0.altitudeDegrees))°" } ?? "--",
                estimatedHeight: 0
            )

            let estimatedHeight = estimatedRowHeight(
                row: row,
                identifierColumnWidth: identifierColumnWidth,
                nameColumnWidth: nameColumnWidth,
                typeColumnWidth: typeColumnWidth,
                azimuthColumnWidth: azimuthColumnWidth,
                altitudeColumnWidth: altitudeColumnWidth
            )

            return PrintRow(
                id: row.id,
                identifierText: row.identifierText,
                nameText: row.nameText,
                typeText: row.typeText,
                azimuthText: row.azimuthText,
                altitudeText: row.altitudeText,
                estimatedHeight: estimatedHeight
            )
        }
    }

    private static func paginatedPages(
        rows: [PrintRow],
        locationLines: [String],
        printedAt: Date,
        pageHeight: CGFloat,
        pageMargin: CGFloat,
        pageWidth: CGFloat
    ) -> [PrintPage] {
        let contentWidth = pageWidth - (pageMargin * 2)
        let contentHeight = pageHeight - (pageMargin * 2)
        let firstPageAvailableHeight = contentHeight - firstPageHeaderHeight(
            locationLines: locationLines,
            printedAt: printedAt,
            contentWidth: contentWidth
        )
        let continuationPageAvailableHeight = contentHeight - continuationHeaderHeight(
            printedAt: printedAt,
            contentWidth: contentWidth
        )

        guard !rows.isEmpty else {
            return [PrintPage(id: 1, isFirstPage: true, rows: [])]
        }

        var pages: [PrintPage] = []
        var currentRows: [PrintRow] = []
        var remainingHeight = firstPageAvailableHeight
        var isFirstPage = true
        var pageNumber = 1

        for row in rows {
            let rowHeight = row.estimatedHeight
            let fitsOnCurrentPage = currentRows.isEmpty || rowHeight <= remainingHeight

            if !fitsOnCurrentPage {
                pages.append(PrintPage(id: pageNumber, isFirstPage: isFirstPage, rows: currentRows))
                pageNumber += 1
                isFirstPage = false
                currentRows = []
                remainingHeight = continuationPageAvailableHeight
            }

            currentRows.append(row)
            remainingHeight -= rowHeight
        }

        pages.append(PrintPage(id: pageNumber, isFirstPage: isFirstPage, rows: currentRows))
        return pages
    }

    private static func firstPageHeaderHeight(
        locationLines: [String],
        printedAt: Date,
        contentWidth: CGFloat
    ) -> CGFloat {
        var total: CGFloat = 0
        total += 30
        total += textHeight(
            printedAt.formatted(date: .abbreviated, time: .shortened),
            width: contentWidth,
            font: .systemFont(ofSize: 14, weight: .semibold)
        )
        total += 14
        total += locationLines.reduce(0) { partial, line in
            partial + textHeight(
                line,
                width: contentWidth,
                font: .systemFont(ofSize: 14, weight: .regular)
            ) + 4
        }
        total += 14
        total += 22
        total += 26
        return total
    }

    private static func continuationHeaderHeight(
        printedAt: Date,
        contentWidth: CGFloat
    ) -> CGFloat {
        var total: CGFloat = 0
        total += 22
        total += textHeight(
            printedAt.formatted(date: .abbreviated, time: .shortened),
            width: contentWidth,
            font: .systemFont(ofSize: 12, weight: .semibold)
        )
        total += 24
        return total
    }

    private static func estimatedRowHeight(
        row: PrintRow,
        identifierColumnWidth: CGFloat,
        nameColumnWidth: CGFloat,
        typeColumnWidth: CGFloat,
        azimuthColumnWidth: CGFloat,
        altitudeColumnWidth: CGFloat
    ) -> CGFloat {
        let identifierHeight = textHeight(
            row.identifierText,
            width: identifierColumnWidth,
            font: .systemFont(ofSize: 13, weight: .semibold)
        )
        let nameHeight = textHeight(
            row.nameText,
            width: nameColumnWidth,
            font: .systemFont(ofSize: 13, weight: .semibold)
        )
        let typeHeight = textHeight(
            row.typeText,
            width: typeColumnWidth,
            font: .systemFont(ofSize: 12, weight: .regular)
        )
        let azimuthHeight = textHeight(
            row.azimuthText,
            width: azimuthColumnWidth,
            font: .systemFont(ofSize: 12, weight: .regular)
        )
        let altitudeHeight = textHeight(
            row.altitudeText,
            width: altitudeColumnWidth,
            font: .systemFont(ofSize: 12, weight: .regular)
        )
        return max(identifierHeight, nameHeight, typeHeight, azimuthHeight, altitudeHeight, 16)
    }

    private static func textHeight(_ text: String, width: CGFloat, font: NSFont) -> CGFloat {
        let rect = (text as NSString).boundingRect(
            with: NSSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: [.font: font]
        )
        return ceil(rect.height)
    }
}
#endif
