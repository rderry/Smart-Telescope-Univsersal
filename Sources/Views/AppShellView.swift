import SwiftData
import SwiftUI

enum SidebarSection: String, CaseIterable, Identifiable {
    case home
    case setupLocations
    case databaseMaintenance
    case planObservation
    case multiNightObservation
    case currentPlan
    case logs
    case catalog
    case profiles

    var id: String { rawValue }

    static let topBarSections: [SidebarSection] = [
        .home,
        .setupLocations,
        .profiles,
        .planObservation,
        .multiNightObservation,
        .databaseMaintenance
    ]

    var title: String {
        switch self {
        case .home: "Home"
        case .setupLocations: "Setup Locations"
        case .databaseMaintenance: "Equipment Data Bases"
        case .planObservation: "Single Night Observation"
        case .multiNightObservation: "Multi-night Observation"
        case .currentPlan: "Current Plan"
        case .logs: "Logs"
        case .catalog: "Search Databases"
        case .profiles: "Equipment"
        }
    }

    var systemImage: String {
        switch self {
        case .home: "house"
        case .setupLocations: "mappin.and.ellipse"
        case .databaseMaintenance: "server.rack"
        case .planObservation: "scope"
        case .multiNightObservation: "calendar.badge.clock"
        case .currentPlan: "list.bullet.clipboard"
        case .logs: "book.closed"
        case .catalog: "sparkles.rectangle.stack"
        case .profiles: "slider.horizontal.3"
        }
    }

    var compactTitle: String {
        switch self {
        case .home: "Home"
        case .setupLocations: "Locations"
        case .databaseMaintenance: "Equip DB"
        case .planObservation: "Single Night"
        case .multiNightObservation: "Multi-night"
        case .currentPlan: "Current"
        case .logs: "Logs"
        case .catalog: "Catalog"
        case .profiles: "Equipment"
        }
    }
}

private enum StartupOnlineResourceConsent: String {
    case allow
    case skip
}

struct AppShellView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRuntimeState.self) private var runtimeState
    @AppStorage("startup_online_resource_consent") private var startupOnlineResourceConsentRaw = ""
    @State private var selectedSection: SidebarSection = .home
    @State private var bootstrapError: String?
    @State private var startupSequenceHasRun = false
    @State private var startupRefreshCompleted = false
    @State private var startupConsentPromptIsPresented = false
    @State private var startupOnlineResourceConsent: StartupOnlineResourceConsent?

    var body: some View {
        rootShell
            .overlay(alignment: .topTrailing) {
                if let runtimeBannerText {
                    HStack(alignment: .top, spacing: 8) {
                        Image(systemName: "exclamationmark.triangle.fill")
                        Text(runtimeBannerText)
                            .lineLimit(4)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.leading)
                    }
                        .font(AppTypography.body)
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 8)
                        .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 18, style: .continuous))
                        .padding(.top, 12)
                        .padding(.trailing, 16)
                        .frame(maxWidth: 460, alignment: .trailing)
                }
            }
            .overlay(alignment: .bottomTrailing) {
                BuildBadgeView()
                    .padding(.trailing, 18)
                    .padding(.bottom, 14)
            }
            .overlay(alignment: .bottomLeading) {
                FooterCreditView()
                    .padding(.leading, 18)
                    .padding(.bottom, 14)
            }
            .overlay {
                if runtimeState.isStartupDataRefreshInProgress {
                    StartupDataRefreshSplashView()
                }
            }
            .overlay {
                if startupConsentPromptIsPresented {
                    StartupOnlineResourceConsentView(
                        selection: $startupOnlineResourceConsent
                    ) {
                        handleStartupConsentContinue()
                    }
                }
            }
            .overlay {
                if let noInternetMessage = runtimeState.noInternetMessage {
                    InternetRequiredOverlay(message: noInternetMessage) {
                        Task {
                            await runStartupSequence(force: true)
                        }
                    } skip: {
                        skipStartupOnlineUpdate()
                    }
                }
            }
        .task {
            guard !startupSequenceHasRun else { return }
            startupSequenceHasRun = true
            startupOnlineResourceConsent = StartupOnlineResourceConsent(rawValue: startupOnlineResourceConsentRaw)

            if startupOnlineResourceConsent == .allow {
                await runStartupSequence()
            } else {
                startupConsentPromptIsPresented = true
            }
        }
    }

    @MainActor
    private func handleStartupConsentContinue() {
        guard let startupOnlineResourceConsent else { return }
        startupOnlineResourceConsentRaw = startupOnlineResourceConsent.rawValue
        startupConsentPromptIsPresented = false

        switch startupOnlineResourceConsent {
        case .allow:
            Task {
                await runStartupSequence(force: true)
            }
        case .skip:
            skipStartupOnlineUpdate()
        }
    }

    @MainActor
    private func skipStartupOnlineUpdate() {
        runtimeState.internetConnectivityStatus = .unchecked
        runtimeState.isStartupDataRefreshInProgress = false
        startupRefreshCompleted = true

        Task {
            await bootstrapBundledDataOnly()
        }
    }

    @MainActor
    private func bootstrapBundledDataOnly() async {
        do {
            try BootstrapService.bootstrapIfNeeded(context: modelContext)
            runtimeState.setRefreshWarnings([])
        } catch {
            bootstrapError = error.localizedDescription
        }
    }

    @MainActor
    private func runStartupSequence(force: Bool = false) async {
        if force {
            startupRefreshCompleted = false
        }

        runtimeState.isStartupDataRefreshInProgress = true
        defer {
            runtimeState.isStartupDataRefreshInProgress = false
        }

        runtimeState.internetConnectivityStatus = .checking
        let isConnected = await InternetConnectivityChecker.hasInternetConnection()
        runtimeState.internetConnectivityStatus = isConnected ? .connected : .disconnected
        guard isConnected else { return }
        guard !startupRefreshCompleted else { return }

        startupRefreshCompleted = true

        do {
            let refreshReport = try await DatabaseRefreshService.bootstrapAndRefreshIfNeeded(context: modelContext)
            runtimeState.setRefreshWarnings(refreshReport.warnings)
        } catch {
            bootstrapError = error.localizedDescription
        }
    }

    private var runtimeBannerText: String? {
        let issues = ([bootstrapError].compactMap { $0 }) + runtimeState.activeWarnings
        let nonEmpty = issues
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        guard !nonEmpty.isEmpty else { return nil }
        return nonEmpty.joined(separator: "  ")
    }

    private var navigationPalette: AppNavigationPalette {
        selectedSection.navigationPalette
    }

    @ViewBuilder
    private var rootShell: some View {
        NavigationStack {
            VStack(spacing: 0) {
                appNavigationRibbon

                sectionView(for: selectedSection)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    private var appNavigationRibbon: some View {
        HStack {
            topNavigationBar
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(.horizontal, 18)
        .padding(.top, 8)
        .padding(.bottom, 6)
    }

    private var topNavigationBar: some View {
        let palette = navigationPalette

        return ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                ForEach(SidebarSection.topBarSections) { section in
                    topNavigationButton(for: section, palette: palette)
                }
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(SidebarSection.topBarSections) { section in
                        topNavigationButton(for: section, palette: palette)
                    }
                }
                .padding(.horizontal, 2)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(palette.barFill)
                .overlay(
                    Capsule()
                        .stroke(palette.barStroke, lineWidth: 1)
                )
        )
    }

    private func topNavigationButton(for section: SidebarSection, palette: AppNavigationPalette) -> some View {
        let isSelected = selectedSection == section

        return Button {
            selectedSection = section
        } label: {
            Label(section.compactTitle, systemImage: section.systemImage)
                .font(.system(size: 12.5, weight: .semibold, design: .rounded))
                .lineLimit(1)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 5)
        .background(
            Capsule()
                .fill(isSelected ? palette.selectedButtonFill : palette.buttonFill)
        )
        .overlay(
            Capsule()
                .stroke(
                    isSelected ? palette.selectedButtonStroke : palette.buttonStroke,
                    lineWidth: 1
                )
        )
        .foregroundStyle(isSelected ? palette.selectedText : palette.buttonText)
    }

    @ViewBuilder
    private func sectionView(for section: SidebarSection) -> some View {
        switch section {
        case .home:
            MainLandingPageView(selectedSection: $selectedSection)
        case .setupLocations:
            SetupLocationsWorkspaceView(selectedSection: $selectedSection)
                .workspacePageBackground(style: .metallicGreen)
                .foregroundStyle(.white)
        case .databaseMaintenance:
            DatabaseMaintenanceWorkspaceView(selectedSection: $selectedSection)
                .workspacePageBackground(style: .metallicBlue)
                .foregroundStyle(.white)
        case .planObservation:
            SingleNightObservationWorkspaceView(selectedSection: $selectedSection)
                .workspacePageBackground(style: .midnightBlue)
                .foregroundStyle(.white)
        case .multiNightObservation:
            MultiNightObservationWorkspaceView(selectedSection: $selectedSection)
                .workspacePageBackground(style: .metallicBlue)
                .foregroundStyle(.white)
        case .currentPlan:
            CurrentPlanWorkspaceView(selectedSection: $selectedSection)
                .workspacePageBackground(style: .metallicBlue)
                .foregroundStyle(.white)
        case .logs:
            LogsWorkspaceView(selectedSection: $selectedSection)
                .workspacePageBackground()
                .foregroundStyle(.white)
        case .catalog:
            CatalogWorkspaceView(selectedSection: $selectedSection)
                .workspacePageBackground()
                .foregroundStyle(.white)
        case .profiles:
            ProfilesWorkspaceView(selectedSection: $selectedSection)
                .workspacePageBackground(style: .metallicRed)
                .foregroundStyle(.white)
        }
    }
}

private struct AppNavigationPalette {
    let barFill: AnyShapeStyle
    let barStroke: Color
    let buttonFill: AnyShapeStyle
    let selectedButtonFill: AnyShapeStyle
    let buttonStroke: Color
    let selectedButtonStroke: Color
    let buttonText: Color
    let selectedText: Color

    static let metallicBlue = AppNavigationPalette(
        barFill: AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color(red: 0.00, green: 0.04, blue: 0.13).opacity(0.96),
                    Color(red: 0.02, green: 0.11, blue: 0.28).opacity(0.96),
                    Color(red: 0.00, green: 0.03, blue: 0.11).opacity(0.96)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ),
        barStroke: Color(red: 0.50, green: 0.72, blue: 1.0).opacity(0.38),
        buttonFill: AnyShapeStyle(Color(red: 0.04, green: 0.16, blue: 0.34).opacity(0.82)),
        selectedButtonFill: AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color(red: 0.34, green: 0.62, blue: 0.92),
                    Color(red: 0.13, green: 0.36, blue: 0.70),
                    Color(red: 0.58, green: 0.79, blue: 1.0)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ),
        buttonStroke: Color.white.opacity(0.14),
        selectedButtonStroke: Color(red: 0.78, green: 0.91, blue: 1.0).opacity(0.74),
        buttonText: Color.white.opacity(0.88),
        selectedText: Color.white
    )

    static let metallicRed = AppNavigationPalette(
        barFill: AnyShapeStyle(Color(red: 0.18, green: 0.02, blue: 0.03).opacity(0.96)),
        barStroke: Color(red: 1.0, green: 0.44, blue: 0.44).opacity(0.44),
        buttonFill: AnyShapeStyle(Color(red: 0.40, green: 0.08, blue: 0.10).opacity(0.86)),
        selectedButtonFill: AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color(red: 0.92, green: 0.34, blue: 0.36),
                    Color(red: 0.58, green: 0.10, blue: 0.13),
                    Color(red: 1.0, green: 0.55, blue: 0.56)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ),
        buttonStroke: Color.white.opacity(0.15),
        selectedButtonStroke: Color(red: 1.0, green: 0.72, blue: 0.72).opacity(0.80),
        buttonText: Color.white.opacity(0.90),
        selectedText: Color.white
    )

    static let metallicGreen = AppNavigationPalette(
        barFill: AnyShapeStyle(Color(red: 0.02, green: 0.15, blue: 0.10).opacity(0.96)),
        barStroke: Color(red: 0.48, green: 0.95, blue: 0.70).opacity(0.42),
        buttonFill: AnyShapeStyle(Color(red: 0.06, green: 0.28, blue: 0.19).opacity(0.84)),
        selectedButtonFill: AnyShapeStyle(
            LinearGradient(
                colors: [
                    Color(red: 0.34, green: 0.78, blue: 0.54),
                    Color(red: 0.10, green: 0.43, blue: 0.30),
                    Color(red: 0.62, green: 1.0, blue: 0.78)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        ),
        buttonStroke: Color.white.opacity(0.14),
        selectedButtonStroke: Color(red: 0.78, green: 1.0, blue: 0.86).opacity(0.70),
        buttonText: Color.white.opacity(0.88),
        selectedText: Color.white
    )
}

private extension SidebarSection {
    var navigationPalette: AppNavigationPalette {
        switch self {
        case .setupLocations:
            .metallicGreen
        case .profiles:
            .metallicRed
        case .home, .databaseMaintenance, .planObservation, .multiNightObservation, .currentPlan, .logs, .catalog:
            .metallicBlue
        }
    }
}

struct DatabaseMaintenanceWorkspaceView: View {
    @Binding var selectedSection: SidebarSection

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .center, spacing: 10) {
                    Text("Equipment Data Bases")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.yellow)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)

                    Text("This workspace will manage the equipment catalogs (classic + smart) and the supporting database refresh tools.")
                        .font(AppTypography.body)
                        .foregroundStyle(.white.opacity(0.92))
                        .frame(maxWidth: 760, alignment: .center)
                        .multilineTextAlignment(.center)
                }
                .padding(18)
                .frame(maxWidth: .infinity)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))

                VStack(alignment: .leading, spacing: 12) {
                    Text("Maintenance Actions")
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(Color.yellow)

                    Text("This page is a placeholder for Beta V1.0. The Equipment page currently hosts the live catalog experience; this workspace will evolve into database auditing and refresh controls.")
                        .font(AppTypography.body)
                        .foregroundStyle(.white.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)

                    VStack(spacing: 10) {
                        Button {} label: {
                            Label("Being Built", systemImage: "hammer")
                        }
                        .buttonStyle(.bordered)
                        .disabled(true)

                        Button {} label: {
                            Label("Being Built", systemImage: "hammer")
                        }
                        .buttonStyle(.bordered)
                        .disabled(true)

                        Button {
                            selectedSection = .home
                        } label: {
                            Label("Return Home", systemImage: "house")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 80)
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }
}

private struct StartupOnlineResourceConsentView: View {
    @Binding var selection: StartupOnlineResourceConsent?
    let continueAction: () -> Void
    private let navyText = Color(red: 0.01, green: 0.04, blue: 0.16)

    var body: some View {
        ZStack {
            MetallicBlueBackgroundView()
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Smart Scope Observation Planner")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundStyle(navyText)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    Text("May we use your internet connection to update all databases and other online resources such as manuals, star charts, and related references? No information will be collected. All data will remain on your machine and be used only for calculations.")
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(navyText.opacity(0.92))
                        .lineSpacing(4)
                        .fixedSize(horizontal: false, vertical: true)

                    Text("You may change this in the app settings later.")
                        .font(AppTypography.body)
                        .foregroundStyle(navyText.opacity(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Toggle("Yes, use my internet connection for updates.", isOn: consentBinding(for: .allow))
                    Toggle("No, skip online updates for this launch.", isOn: consentBinding(for: .skip))
                }
                .toggleStyle(.checkbox)
                .font(AppTypography.bodyStrong)
                .foregroundStyle(navyText)

                HStack {
                    Spacer()

                    Button("Continue") {
                        continueAction()
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .disabled(selection == nil)
                    .keyboardShortcut(.defaultAction)
                }
            }
            .padding(36)
            .frame(width: 860, alignment: .topLeading)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(Color.white.opacity(0.24), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.28), radius: 26, y: 14)
            .padding(34)
        }
    }

    private func consentBinding(for value: StartupOnlineResourceConsent) -> Binding<Bool> {
        Binding(
            get: { selection == value },
            set: { isSelected in
                if isSelected {
                    selection = value
                } else if selection == value {
                    selection = nil
                }
            }
        )
    }
}

private struct StartupDataRefreshSplashView: View {
    private let navyText = Color(red: 0.01, green: 0.04, blue: 0.16)

    var body: some View {
        ZStack {
            MetallicBlueBackgroundView()
                .ignoresSafeArea()

            VStack(alignment: .center, spacing: 18) {
                ProgressView()
                    .controlSize(.large)
                    .tint(navyText)

                Text("Please wait while we ensure you have the newest data available.")
                    .font(.system(size: 30, weight: .bold, design: .rounded))
                    .foregroundStyle(navyText)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(34)
            .frame(maxWidth: 760)
            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 34, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 34, style: .continuous)
                    .stroke(Color.white.opacity(0.20), lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.28), radius: 26, y: 14)
            .padding(32)

            FooterCreditView()
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
                .padding(.leading, 18)
                .padding(.bottom, 14)
        }
    }
}

private struct InternetRequiredOverlay: View {
    let message: String
    let retry: () -> Void
    let skip: () -> Void

    var body: some View {
        ZStack {
            Color.black.opacity(0.72)
                .ignoresSafeArea()

            VStack(alignment: .center, spacing: 18) {
                Image(systemName: "wifi.exclamationmark")
                    .font(.system(size: 44, weight: .semibold))
                    .foregroundStyle(Color.yellow)

                Text("Internet Connection Required")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(Color.yellow)
                    .multilineTextAlignment(.center)

                Text(message)
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(Color.white)
                    .multilineTextAlignment(.center)
                    .lineSpacing(5)
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    retry()
                } label: {
                    Label("Retry Internet Check", systemImage: "arrow.clockwise")
                        .font(AppTypography.bodyStrong)
                }
                .buttonStyle(.borderedProminent)

                Button {
                    skip()
                } label: {
                    Label("Skip Online Update", systemImage: "forward.end")
                        .font(AppTypography.bodyStrong)
                }
                .buttonStyle(.bordered)
            }
            .padding(28)
            .frame(maxWidth: 680)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 32, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 32, style: .continuous)
                    .stroke(.white.opacity(0.20), lineWidth: 1)
            )
            .shadow(color: .black.opacity(0.35), radius: 24, y: 12)
            .padding(28)
        }
    }
}

struct MultiNightObservationWorkspaceView: View {
    @Environment(AppRuntimeState.self) private var runtimeState
    @Query(sort: \ObservingSite.name) private var sites: [ObservingSite]
    @Binding var selectedSection: SidebarSection
    @State private var selectedLocationID: UUID?
    @State private var telescopeCaptureStartDate: Date?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                VStack(alignment: .center, spacing: 10) {
                    Text("Multi-night Observation Planner")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.yellow)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)

                    Text("Use this workspace to organize targets, nights, and carry-forward planning across several observation sessions from one selected observing location.")
                        .font(AppTypography.body)
                        .foregroundStyle(.white.opacity(0.92))
                        .frame(maxWidth: 760, alignment: .center)
                        .multilineTextAlignment(.center)
                }
                .padding(18)
                .frame(maxWidth: .infinity)
                .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 30, style: .continuous))

                VStack(alignment: .leading, spacing: 12) {
                    Text("Observation Scope")
                        .font(AppTypography.bodyStrong)
                        .foregroundStyle(Color.yellow)

                    if sites.isEmpty {
                        Text("No saved locations are available yet. Create one first, then return here to begin the multi-night planner.")
                            .font(AppTypography.body)
                            .foregroundStyle(.white.opacity(0.92))
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 12) {
                            Button {
                                runtimeState.pendingLocationSelectionReturnSectionRawValue = SidebarSection.multiNightObservation.rawValue
                                selectedSection = .setupLocations
                            } label: {
                                Label("Create a Location", systemImage: "mappin.and.ellipse")
                            }
                            .buttonStyle(.bordered)

                            Button {
                                selectedSection = .home
                            } label: {
                                Label("Return Home", systemImage: "house")
                            }
                            .buttonStyle(.bordered)
                        }
                    } else {
                        Text("Choose the location you want to use first. This workspace is reserved for planning targets and carry-forward observing work across multiple nights.")
                            .font(AppTypography.body)
                            .foregroundStyle(.white.opacity(0.92))
                            .fixedSize(horizontal: false, vertical: true)

                        VStack(alignment: .leading, spacing: 6) {
                            Text("Default Location")
                                .font(AppTypography.body)
                                .foregroundStyle(.white.opacity(0.84))

                            Menu {
                                ForEach(sites) { site in
                                    Button(site.name) {
                                        selectedLocationBinding.wrappedValue = site.id
                                    }
                                }
                            } label: {
                                HStack(spacing: 8) {
                                    Text(selectedLocationName)
                                        .font(AppTypography.body)
                                        .foregroundStyle(.primary)
                                        .lineLimit(2)
                                        .fixedSize(horizontal: false, vertical: true)

                                    Spacer(minLength: 8)

                                    Image(systemName: "chevron.down")
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 10)
                                .padding(.vertical, 8)
                                .frame(minHeight: 44, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .fill(.ultraThinMaterial)
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                                .stroke(.white.opacity(0.16), lineWidth: 1)
                                        )
                                )
                            }
                            .buttonStyle(.plain)
                        }

                        if let telescopeCaptureStartDate {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Sun Below Horizon Start")
                                    .font(AppTypography.body)
                                    .foregroundStyle(.white.opacity(0.84))

                                Text(formattedCaptureStart(telescopeCaptureStartDate))
                                    .font(AppTypography.bodyStrong)
                                    .foregroundStyle(Color.yellow)
                            }
                        }

                        Button {
                            selectedSection = .home
                        } label: {
                            Label("Return Home", systemImage: "house")
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding(18)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 28, style: .continuous))
            }
            .padding(.horizontal, 18)
            .padding(.top, 12)
            .padding(.bottom, 80)
            .frame(maxWidth: 980, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            syncSelectedLocation()
            applyPendingTelescopeCaptureStartIfNeeded()
        }
        .onChange(of: sites.map(\.id)) { _, _ in
            syncSelectedLocation()
        }
    }

    private var selectedLocationBinding: Binding<UUID?> {
        Binding(
            get: { selectedLocationID },
            set: { newValue in
                selectedLocationID = newValue
                LocationPreferenceStore.setDefaultSiteID(newValue)
            }
        )
    }

    private var selectedLocationName: String {
        if let selectedLocationID,
           let site = sites.first(where: { $0.id == selectedLocationID }) {
            return site.name
        }

        return "Choose the default location"
    }

    private var selectedLocation: ObservingSite? {
        guard let selectedLocationID else { return nil }
        return sites.first { $0.id == selectedLocationID }
    }

    private func syncSelectedLocation() {
        selectedLocationID = LocationPreferenceStore.reconcileDefaultSiteID(using: sites)
    }

    private func applyPendingTelescopeCaptureStartIfNeeded() {
        guard let captureStartDate = runtimeState.pendingTelescopeCaptureStartDate else { return }

        if let destinationRawValue = runtimeState.pendingTelescopeCaptureStartDestinationRawValue,
           destinationRawValue != SidebarSection.multiNightObservation.rawValue {
            return
        }

        telescopeCaptureStartDate = captureStartDate
        runtimeState.pendingTelescopeCaptureStartDate = nil
        runtimeState.pendingTelescopeCaptureStartDestinationRawValue = nil
    }

    private func formattedCaptureStart(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        if let timeZoneIdentifier = selectedLocation?.timeZoneIdentifier,
           let timeZone = TimeZone(identifier: timeZoneIdentifier) {
            formatter.timeZone = timeZone
        }
        return formatter.string(from: date)
    }
}
