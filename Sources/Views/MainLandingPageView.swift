// Copyright BigSkyAstro Richard Derry.
import SwiftData
import SwiftUI

private let homeActionButtonBlue = Color(red: 0.02, green: 0.24, blue: 0.72)
private let homeHeroTitleColor = Color.yellow
private let homeMoonBadgeTextColor = Color(red: 0.02, green: 0.16, blue: 0.44)

struct MainLandingPageView: View {
    @Environment(AppRuntimeState.self) private var runtimeState
    @Query(sort: \ObservingSite.name) private var sites: [ObservingSite]
    @Query(sort: \EquipmentProfile.name) private var equipmentProfiles: [EquipmentProfile]
    @Binding var selectedSection: SidebarSection
    @State private var selectedSingleNightLocationID: UUID?
    @State private var selectedEquipmentProfileID: UUID?
    private let homePrimaryCardHeight: CGFloat = 340
    private let homeCardHeight: CGFloat = 300
    private let homeCardWidth: CGFloat = 372

    var body: some View {
        ZStack(alignment: .topLeading) {
            LandingBackgroundView()
                .ignoresSafeArea()
                .tahoeBackgroundExtension()

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    heroSection
                    workflowSection
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 14)
                .frame(maxWidth: 1180, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            syncSelectedSingleNightLocation()
            syncSelectedEquipmentProfile()
        }
        .onChange(of: sites.map(\.id)) { _, _ in
            syncSelectedSingleNightLocation()
        }
        .onChange(of: equipmentProfiles.map(\.id)) { _, _ in
            syncSelectedEquipmentProfile()
        }
        .onChange(of: selectedSection) { _, newValue in
            if newValue == .home {
                syncSelectedSingleNightLocation()
                syncSelectedEquipmentProfile()
            }
        }
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 16) {
                    homeMoonInfoBlock
                        .frame(width: 250, alignment: .leading)

                    VStack(alignment: .center, spacing: 7) {
                        Text("Smart Scope Observation Planner")
                            .font(.system(size: 24, weight: .bold, design: .rounded))
                            .foregroundStyle(homeHeroTitleColor)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .multilineTextAlignment(.center)
                            .shadow(color: Color.black.opacity(0.35), radius: 8, y: 2)

                        Text("Plan observation nights, organize repeat targets across multiple sessions, and keep observation logs in one Mac workspace.")
                            .font(AppTypography.body)
                            .foregroundStyle(.white.opacity(0.90))
                            .frame(maxWidth: 620, alignment: .center)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.center)

                        homeViewingInfoBlock
                            .frame(maxWidth: 760, alignment: .center)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }

                VStack(alignment: .center, spacing: 10) {
                    homeMoonInfoBlock
                        .frame(maxWidth: 620, alignment: .leading)

                    Text("Smart Scope Observation Planner")
                        .font(.system(size: 24, weight: .bold, design: .rounded))
                        .foregroundStyle(homeHeroTitleColor)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .shadow(color: Color.black.opacity(0.35), radius: 8, y: 2)

                    Text("Plan observation nights, organize repeat targets across multiple sessions, and keep observation logs in one Mac workspace.")
                        .font(AppTypography.body)
                        .foregroundStyle(.white.opacity(0.90))
                        .frame(maxWidth: 620, alignment: .center)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.center)

                    homeViewingInfoBlock
                        .frame(maxWidth: 760, alignment: .center)
                }
            }

        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: 32, style: .continuous)
                .fill(.regularMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 32, style: .continuous)
                        .stroke(.white.opacity(0.14), lineWidth: 1)
                )
        )
        .shadow(color: .black.opacity(0.10), radius: 24, y: 12)
    }

    private var workflowSection: some View {
        VStack(alignment: .leading, spacing: 7) {
            VStack(spacing: 30) {
                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        setupLocationsCard
                            .frame(width: homeCardWidth)

                        observationEquipmentCard
                            .frame(width: homeCardWidth)
                    }

                    VStack(spacing: 12) {
                        setupLocationsCard
                            .frame(width: homeCardWidth)

                        observationEquipmentCard
                            .frame(width: homeCardWidth)
                    }
                }

                ViewThatFits(in: .horizontal) {
                    HStack(alignment: .top, spacing: 12) {
                        singleNightPlanCard
                            .frame(width: homeCardWidth)

                        multiNightPlanCard
                            .frame(width: homeCardWidth)

                        databaseMaintenanceCard
                            .frame(width: homeCardWidth)
                    }

                    VStack(spacing: 12) {
                        singleNightPlanCard
                            .frame(width: homeCardWidth)
                        multiNightPlanCard
                            .frame(width: homeCardWidth)
                        databaseMaintenanceCard
                            .frame(width: homeCardWidth)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var setupLocationsCard: some View {
        launchCard(
            topLabel: "Start Here",
            title: "Setup Locations",
            subtitle: "Save observing locations by WGS 84 coordinates or by country-aware address entry before building the next workflow steps.",
            systemImage: "mappin.and.ellipse",
            accent: Color.green,
            destination: .setupLocations,
            buttonTitle: "Open Setup Locations"
        )
    }

    private func launchCard(
        topLabel: String? = nil,
        title: String,
        subtitle: String,
        systemImage: String,
        accent: Color,
        destination: SidebarSection,
        buttonTitle: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            if let topLabel {
                Text(topLabel)
                    .font(AppTypography.bodyEmphasized)
                    .foregroundStyle(Color.yellow)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
            }

            HStack(alignment: .center, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(accent.opacity(0.16))
                        .frame(width: 28, height: 28)
                    Image(systemName: systemImage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accent)
                }

                Text(title)
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                    .multilineTextAlignment(.leading)
            }

            Text(subtitle)
                .font(AppTypography.body)
                .foregroundStyle(Color.white.opacity(0.78))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)

            Spacer(minLength: 0)

            Button {
                selectedSection = destination
            } label: {
                homeCardButtonLabel(
                    title: buttonTitle,
                    systemImage: "arrow.right",
                    alignment: .leading
                )
            }
            .controlSize(.regular)
            .homeWhiteActionStyle()
        }
        .homeCardContainer(height: homePrimaryCardHeight)
    }

    private var singleNightPlanCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.blue.opacity(0.16))
                        .frame(width: 28, height: 28)
                    Image(systemName: "moon.stars")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.blue)
                }

                Text("Create a Single Night Plan")
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
            }

            Text("Start from the default observing location. You can change it here from the saved locations list before opening tonight's observation page.")
                .font(AppTypography.body)
                .foregroundStyle(Color.white.opacity(0.78))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            if sites.isEmpty {
                Text("No saved locations are available yet.")
                    .font(AppTypography.body)
                    .foregroundStyle(Color.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                Button {
                    runtimeState.pendingLocationSelectionReturnSectionRawValue = SidebarSection.home.rawValue
                    selectedSection = .setupLocations
                } label: {
                    homeCardButtonLabel(
                        title: "Create a Location",
                        systemImage: "arrow.right",
                        alignment: .leading
                    )
                }
                .controlSize(.regular)
                .homeWhiteActionStyle()
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Default Location")
                        .font(AppTypography.body)
                        .foregroundStyle(Color.white.opacity(0.78))

                    Menu {
                        ForEach(sites) { site in
                            Button(site.name) {
                                selectedSingleNightLocationBinding.wrappedValue = site.id
                            }
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 8) {
                            Text(selectedSingleNightLocationName)
                                .font(AppTypography.body)
                                .foregroundStyle(Color.white)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .layoutPriority(1)

                            Spacer(minLength: 8)

                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.74))
                                .padding(.top, 4)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(minHeight: 48, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
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

                Spacer(minLength: 0)

                Button {
                    guard let selectedSiteID = selectedSingleNightLocationID else { return }
                    LocationPreferenceStore.setDefaultSiteID(selectedSiteID)
                    selectedSection = .planObservation
                } label: {
                    homeCardButtonLabel(
                        title: "Open Single Night Observation",
                        systemImage: "arrow.right",
                        alignment: .leading
                    )
                }
                .controlSize(.regular)
                .homeWhiteActionStyle()
                .disabled(selectedSingleNightLocationID == nil)
            }
        }
        .homeCardContainer(height: homeCardHeight)
    }

    private var observationEquipmentCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Required for Smart Telescopes")
                .font(AppTypography.bodyEmphasized)
                .foregroundStyle(Color.yellow)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .minimumScaleFactor(0.78)

            HStack(alignment: .center, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.orange.opacity(0.16))
                        .frame(width: 28, height: 28)
                    Image(systemName: "camera.macro")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.orange)
                }

                Text("Observation Equipment Used")
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
                    .multilineTextAlignment(.leading)
            }

            Text("Choose the default Smart Scope used for planning, or open Equipment to manage the smart telescope and accessory database.")
                .font(AppTypography.body)
                .foregroundStyle(Color.white.opacity(0.78))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.leading)

            if selectableEquipmentProfiles.isEmpty {
                Text("No plan-ready telescopes or smart telescopes are available yet.")
                    .font(AppTypography.body)
                    .foregroundStyle(Color.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                Button {
                    selectedSection = .profiles
                } label: {
                    homeCardButtonLabel(
                        title: "Open Equipment Page",
                        systemImage: "arrow.right",
                        alignment: .leading
                    )
                }
                .controlSize(.regular)
                .homeWhiteActionStyle()
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Default Equipment")
                        .font(AppTypography.body)
                        .foregroundStyle(Color.white.opacity(0.78))

                    HStack(alignment: .center, spacing: 8) {
                        Menu {
                            ForEach(selectableEquipmentProfiles) { equipmentProfile in
                                Button(equipmentProfile.name) {
                                    selectedEquipmentProfileBinding.wrappedValue = equipmentProfile.id
                                }
                            }
                        } label: {
                            HStack(alignment: .top, spacing: 8) {
                                Text(selectedEquipmentProfileName)
                                    .font(AppTypography.body)
                                    .foregroundStyle(Color.white)
                                    .multilineTextAlignment(.leading)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.82)
                                    .layoutPriority(1)

                                Spacer(minLength: 8)

                                Image(systemName: "chevron.down")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(Color.white.opacity(0.74))
                                    .padding(.top, 4)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 8)
                            .frame(minHeight: 44, alignment: .leading)
                            .frame(maxWidth: .infinity, alignment: .leading)
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

                        if selectedEquipmentProfile != nil {
                            Button {
                                selectedSection = .profiles
                            } label: {
                                Label("Change", systemImage: "pencil")
                                    .font(AppTypography.body)
                            }
                            .controlSize(.regular)
                            .homeWhiteActionStyle()
                        }
                    }

                    if let selectedEquipmentProfile {
                        Text(selectedEquipmentProfile.summary)
                            .font(AppTypography.body)
                            .foregroundStyle(Color.white.opacity(0.78))
                            .lineLimit(4)
                            .minimumScaleFactor(0.76)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)

                Button {
                    selectedSection = .profiles
                } label: {
                    homeCardButtonLabel(
                        title: selectedEquipmentProfile == nil ? "Open Equipment Page" : "Manage Equipment Database",
                        systemImage: "arrow.right",
                        alignment: .leading
                    )
                }
                .controlSize(.regular)
                .homeWhiteActionStyle()
            }
        }
        .homeCardContainer(height: homePrimaryCardHeight)
    }

    private var multiNightPlanCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.indigo.opacity(0.16))
                        .frame(width: 28, height: 28)
                    Image(systemName: "calendar.badge.clock")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.indigo)
                }

                Text("Multi-night Observation Planner")
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
            }

            Text("Open the new multi-night planning workspace so we can begin building a longer-range observation flow next.")
                .font(AppTypography.body)
                .foregroundStyle(Color.white.opacity(0.78))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            if sites.isEmpty {
                Text("No saved locations are available yet.")
                    .font(AppTypography.body)
                    .foregroundStyle(Color.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)

                Button {
                    runtimeState.pendingLocationSelectionReturnSectionRawValue = SidebarSection.home.rawValue
                    selectedSection = .setupLocations
                } label: {
                    homeCardButtonLabel(
                        title: "Create a Location",
                        systemImage: "arrow.right",
                        alignment: .leading
                    )
                }
                .controlSize(.regular)
                .homeWhiteActionStyle()
            } else {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Default Location")
                        .font(AppTypography.body)
                        .foregroundStyle(Color.white.opacity(0.78))

                    Menu {
                        ForEach(sites) { site in
                            Button(site.name) {
                                selectedSingleNightLocationBinding.wrappedValue = site.id
                            }
                        }
                    } label: {
                        HStack(alignment: .top, spacing: 8) {
                            Text(selectedSingleNightLocationName)
                                .font(AppTypography.body)
                                .foregroundStyle(Color.white)
                                .multilineTextAlignment(.leading)
                                .fixedSize(horizontal: false, vertical: true)
                                .layoutPriority(1)

                            Spacer(minLength: 8)

                            Image(systemName: "chevron.down")
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(Color.white.opacity(0.74))
                                .padding(.top, 4)
                        }
                        .padding(.horizontal, 10)
                        .padding(.vertical, 8)
                        .frame(minHeight: 48, alignment: .leading)
                        .frame(maxWidth: .infinity, alignment: .leading)
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

                Spacer(minLength: 0)

                Button {
                    guard let selectedSiteID = selectedSingleNightLocationID else { return }
                    LocationPreferenceStore.setDefaultSiteID(selectedSiteID)
                    selectedSection = .multiNightObservation
                } label: {
                    homeCardButtonLabel(
                        title: "Open Multi-night Observation Planner",
                        systemImage: "arrow.right",
                        alignment: .leading
                    )
                }
                .controlSize(.regular)
                .homeWhiteActionStyle()
                .disabled(selectedSingleNightLocationID == nil)
            }
        }
        .homeCardContainer(height: homeCardHeight)
    }

    private var databaseMaintenanceCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .fill(Color.cyan.opacity(0.16))
                        .frame(width: 28, height: 28)
                    Image(systemName: "server.rack")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(Color.cyan)
                }

                Text("Equipment")
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(Color.white)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .fixedSize(horizontal: false, vertical: true)
                    .layoutPriority(1)
            }

            Text("Open the Equipment Data Bases workspace to manage and refresh the equipment catalogs used for planning.")
                .font(AppTypography.body)
                .foregroundStyle(Color.white.opacity(0.78))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)

            Button {
                selectedSection = .databaseMaintenance
            } label: {
                homeCardButtonLabel(
                    title: "Open Equipment Data Bases",
                    systemImage: "arrow.right",
                    alignment: .leading
                )
            }
            .controlSize(.regular)
            .homeWhiteActionStyle()
        }
        .homeCardContainer(height: homeCardHeight)
    }

    private var placeholderMaintenanceButton: some View {
        Button {} label: {
            homeCardButtonLabel(
                title: "Being Built",
                systemImage: "hammer",
                alignment: .leading
            )
        }
        .controlSize(.regular)
        .homeWhiteActionStyle()
        .disabled(true)
    }

    private var selectedSingleNightLocationBinding: Binding<UUID?> {
        Binding(
            get: { selectedSingleNightLocationID },
            set: { newValue in
                selectedSingleNightLocationID = newValue
                LocationPreferenceStore.setDefaultSiteID(newValue)
            }
        )
    }

    private var selectedSingleNightLocationName: String {
        if let selectedSingleNightLocationID,
           let site = sites.first(where: { $0.id == selectedSingleNightLocationID }) {
            return site.name
        }

        return "Choose the default location"
    }

    private func syncSelectedSingleNightLocation() {
        selectedSingleNightLocationID = LocationPreferenceStore.reconcileDefaultSiteID(using: sites)
    }

    private func syncSelectedEquipmentProfile() {
        selectedEquipmentProfileID = LocationPreferenceStore.reconcileDefaultEquipmentProfileID(using: equipmentProfiles)
        if let selectedEquipmentProfileID,
           !selectableEquipmentProfiles.contains(where: { $0.id == selectedEquipmentProfileID }) {
            selectedEquipmentProfileBinding.wrappedValue = nil
        }
    }

    private var selectedSingleNightLocation: ObservingSite? {
        guard let selectedSingleNightLocationID else { return nil }
        return sites.first(where: { $0.id == selectedSingleNightLocationID })
    }

    private var selectedEquipmentProfileBinding: Binding<UUID?> {
        Binding(
            get: { selectedEquipmentProfileID },
            set: { newValue in
                selectedEquipmentProfileID = newValue
                LocationPreferenceStore.setDefaultEquipmentProfileID(newValue)
            }
        )
    }

    private var selectedEquipmentProfile: EquipmentProfile? {
        guard let selectedEquipmentProfileID else { return nil }
        return selectableEquipmentProfiles.first(where: { $0.id == selectedEquipmentProfileID })
    }

    private var selectableEquipmentProfiles: [EquipmentProfile] {
        EquipmentCatalogService.sortedProfiles(equipmentProfiles.filter(\.isPlanCompatibleDefault))
    }

    private var selectedEquipmentProfileName: String {
        if let selectedEquipmentProfile {
            return selectedEquipmentProfile.groupedDisplayName
        }

        return "None"
    }

    private var currentHomeMoonPhase: MoonPhaseSnapshot {
        MoonPhaseService.approximateSnapshot(for: Date())
    }

    private var currentHomeViewingEvents: SunBelowHorizonEvents {
        guard let selectedSingleNightLocation else {
            return .unavailable
        }
        return SolarHorizonService.sunBelowHorizonEvents(for: selectedSingleNightLocation, on: Date())
    }

    private var homeMoonInfoBlock: some View {
        HStack(alignment: .center, spacing: 12) {
            CraterMoonPhaseIconButton(
                snapshot: currentHomeMoonPhase,
                backgroundStyle: .metallicBlue,
                size: 58,
                locationName: selectedSingleNightLocation?.name,
                bortleText: selectedSingleNightLocation.map { "Bortle \($0.normalizedBortleClass)" }
            )

            VStack(alignment: .leading, spacing: 4) {
                Text("MOON INFO")
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(homeMoonBadgeTextColor)

                Text(currentHomeMoonPhase.phaseName)
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(homeMoonBadgeTextColor)
                    .fixedSize(horizontal: false, vertical: true)

                Text(selectedSingleNightLocation?.name ?? "Choose a default location")
                    .font(AppTypography.body)
                    .foregroundStyle(homeMoonBadgeTextColor)
                    .fixedSize(horizontal: false, vertical: true)

                Text(selectedSingleNightLocation.map { "Bortle \($0.normalizedBortleClass)" } ?? "Bortle unavailable")
                    .font(AppTypography.body)
                    .foregroundStyle(homeMoonBadgeTextColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.white.opacity(0.16), lineWidth: 1)
                )
        )
    }

    private var homeViewingInfoBlock: some View {
        VStack(alignment: .center, spacing: 4) {
            Text("VIEWING INFO")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(homeMoonBadgeTextColor.opacity(0.92))

            Text(
                "\(selectedSingleNightLocation?.name ?? "Choose a default location") • Sun Below Horizon \(formattedHomeSolarEvent(currentHomeViewingEvents.start)) to \(formattedHomeSolarEvent(currentHomeViewingEvents.end))"
            )
                .font(AppTypography.body)
                .foregroundStyle(.black.opacity(0.88))
                .lineLimit(1)
                .minimumScaleFactor(0.82)
                .fixedSize(horizontal: false, vertical: true)
                .multilineTextAlignment(.center)
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(.thinMaterial)
                .overlay(
                    RoundedRectangle(cornerRadius: 20, style: .continuous)
                        .stroke(.white.opacity(0.16), lineWidth: 1)
                )
        )
    }

    private func homeCardButtonLabel(
        title: String,
        systemImage: String,
        alignment: Alignment,
        foregroundColor: Color = homeActionButtonBlue
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 12, weight: .semibold))

            Text(title)
                .font(AppTypography.body)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
                .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, alignment: alignment)
        .foregroundStyle(foregroundColor)
    }

    private func formattedHomeSolarEvent(_ date: Date?) -> String {
        guard let date else { return "--" }
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        if let identifier = selectedSingleNightLocation?.timeZoneIdentifier,
           let timeZone = TimeZone(identifier: identifier) {
            formatter.timeZone = timeZone
        }
        return formatter.string(from: date)
    }
}

private struct LandingBackgroundView: View {
    var body: some View {
        MetallicBlueBackgroundView()
    }
}

extension View {
    func tahoeBackgroundExtension() -> some View {
        self
    }

    @ViewBuilder
    func tahoeActionStyle(prominent: Bool = false) -> some View {
        if prominent {
            self.buttonStyle(.borderedProminent)
        } else {
            self.buttonStyle(.bordered)
        }
    }

    func homeCardContainer(height: CGFloat) -> some View {
        self
            .padding(11)
            .frame(maxWidth: .infinity, minHeight: height, alignment: .topLeading)
            .background(
                RoundedRectangle(cornerRadius: 28, style: .continuous)
                    .fill(.thinMaterial)
                    .overlay(
                        RoundedRectangle(cornerRadius: 28, style: .continuous)
                            .stroke(.white.opacity(0.16), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.10), radius: 16, y: 8)
    }

    func homeWhiteActionStyle() -> some View {
        self
            .buttonStyle(.plain)
            .padding(.horizontal, 12)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(homeActionButtonBlue)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.94))
                    .overlay(
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .stroke(Color.white.opacity(0.72), lineWidth: 1)
                    )
            )
            .shadow(color: .black.opacity(0.10), radius: 10, y: 5)
    }
}
