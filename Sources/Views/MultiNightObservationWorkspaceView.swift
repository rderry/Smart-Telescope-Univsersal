import Foundation
import SwiftData
import SwiftUI

struct MultiNightObservationWorkspaceView: View {
    @Environment(AppRuntimeState.self) private var runtimeState
    @Query(sort: \ObservingSite.name) private var sites: [ObservingSite]
    @Query(sort: \SavedTargetList.createdAt, order: .reverse) private var savedLists: [SavedTargetList]
    @Binding var selectedSection: SidebarSection
    @State private var selectedLocationID: UUID?
    @State private var selectedSavedListID: UUID?
    @State private var telescopeCaptureStartDate: Date?

    private let compactBodyFont = Font.system(size: 13, weight: .regular, design: .rounded)
    private let compactStrongFont = Font.system(size: 14, weight: .semibold, design: .rounded)
    private let compactSelectorLabelFont = Font.system(size: 12, weight: .semibold, design: .rounded)
    private let compactCaptionFont = Font.system(size: 11, weight: .semibold, design: .rounded)
    private let heroMetricTitleFont = Font.system(size: 12, weight: .bold, design: .rounded)
    private let heroMetricBodyFont = Font.system(size: 14, weight: .semibold, design: .rounded)
    private let heroMetricCaptionFont = Font.system(size: 12, weight: .semibold, design: .rounded)
    private let cardHeadingTitleFont = Font.system(size: 16, weight: .bold, design: .rounded)
    private let labelColor = Color.yellow
    private let sidebarWidth: CGFloat = 320
    private let contentCardMaxWidth: CGFloat = .infinity
    private let targetFeedVisibleHeight: CGFloat = 112
    private let heroMetricWidth: CGFloat = 248
    private let heroMetricHeight: CGFloat = 116

    var body: some View {
        multiNightRoot
    }

    private var multiNightRoot: some View {
        GeometryReader { proxy in
            multiNightContent(proxy: proxy)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            syncSelectedLocation()
            syncSelectedSavedList()
            applyPendingTelescopeCaptureStartIfNeeded()
        }
        .onChange(of: sites.map(\.id)) { _, _ in
            syncSelectedLocation()
        }
        .onChange(of: savedLists.map(\.id)) { _, _ in
            syncSelectedSavedList()
        }
    }

    @ViewBuilder
    private func multiNightContent(proxy: GeometryProxy) -> some View {
        VStack(spacing: 8) {
            heroSection
                .padding(.horizontal, 18)
                .padding(.top, 6)

            if proxy.size.width >= 760 {
                wideMultiNightContent(proxy: proxy)
            } else {
                compactMultiNightContent(proxy: proxy)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func wideMultiNightContent(proxy: GeometryProxy) -> some View {
        let sidebarHeight = sidebarHeight(for: proxy.size.height)

        return HStack(alignment: .top, spacing: 12) {
            savedListsSidebar(height: sidebarHeight)
                .frame(width: sidebarWidth)

            VStack(alignment: .leading, spacing: 10) {
                centeredPlannerFilterCard(maxHeight: plannerFilterMaximumHeight(for: proxy.size.height, compact: false))
                centeredTargetsCard
                Spacer(minLength: 0)
            }
            .padding(.trailing, 18)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 8)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func compactMultiNightContent(proxy: GeometryProxy) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            savedListsSidebar(height: max(proxy.size.height * 0.30, 260))
            centeredPlannerFilterCard(maxHeight: plannerFilterMaximumHeight(for: proxy.size.height, compact: true))
            centeredTargetsCard
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 18)
        .padding(.bottom, 52)
        .frame(maxWidth: 1180, alignment: .leading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func sidebarHeight(for availableHeight: CGFloat) -> CGFloat {
        min(max(availableHeight - 292, 300), max(300, availableHeight - 156))
    }

    private func plannerFilterMaximumHeight(for availableHeight: CGFloat, compact: Bool) -> CGFloat {
        let reservedHeight: CGFloat = compact ? 540 : 455
        let minimumHeight: CGFloat = compact ? 300 : 260
        let maximumHeight: CGFloat = compact ? 420 : 340
        return min(max(availableHeight - reservedHeight, minimumHeight), maximumHeight)
    }

    private var heroSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    heroLocationControl
                        .frame(width: 188, alignment: .topLeading)

                    VStack(alignment: .center, spacing: 4) {
                        Text("Multi-night Observation Planner")
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(Color.yellow)
                            .lineLimit(2)
                            .minimumScaleFactor(0.8)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .multilineTextAlignment(.center)
                            .shadow(color: Color.black.opacity(0.35), radius: 8, y: 2)

                        Text("Build a carry-forward observing list from saved single-night targets, then spread the work across several clear nights.")
                            .font(.system(size: 12, weight: .regular, design: .rounded))
                            .foregroundStyle(.white.opacity(0.92))
                            .frame(maxWidth: 760, alignment: .center)
                            .fixedSize(horizontal: false, vertical: true)
                            .multilineTextAlignment(.center)

                        heroObservationInfoBlocks
                            .frame(maxWidth: 760, alignment: .center)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    multiNightStatusBlock
                        .frame(width: 212, alignment: .trailing)
                }
                .frame(maxWidth: .infinity, alignment: .trailing)

                VStack(alignment: .leading, spacing: 6) {
                    heroLocationControl
                        .frame(maxWidth: 260, alignment: .leading)

                    Text("Multi-night Observation Planner")
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundStyle(Color.yellow)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .multilineTextAlignment(.center)
                        .shadow(color: Color.black.opacity(0.35), radius: 8, y: 2)

                    Text("Build a carry-forward observing list from saved single-night targets, then spread the work across several clear nights.")
                        .font(.system(size: 12, weight: .regular, design: .rounded))
                        .foregroundStyle(.white.opacity(0.92))
                        .frame(maxWidth: 760, alignment: .center)
                        .fixedSize(horizontal: false, vertical: true)
                        .multilineTextAlignment(.center)

                    heroObservationInfoBlocks
                        .frame(maxWidth: 760, alignment: .center)

                    multiNightStatusBlock
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
        .background(multiNightCardBackground(cornerRadius: 28, fill: .regularMaterial))
        .shadow(color: .black.opacity(0.10), radius: 18, y: 10)
    }

    private var heroLocationControl: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text("LOCATION")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(labelColor.opacity(0.84))

            Text(selectedLocationName)
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.94))
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .fixedSize(horizontal: false, vertical: true)

            if sites.isEmpty {
                Button {
                    runtimeState.pendingLocationSelectionReturnSectionRawValue = SidebarSection.multiNightObservation.rawValue
                    selectedSection = .setupLocations
                } label: {
                    Label("Create", systemImage: "mappin.and.ellipse")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
            } else {
                Menu {
                    ForEach(sites) { site in
                        Button(site.name) {
                            selectedLocationBinding.wrappedValue = site.id
                        }
                    }
                } label: {
                    Label("Change", systemImage: "location")
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .frame(maxWidth: .infinity, alignment: .center)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.mini)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(multiNightCardBackground(cornerRadius: 18, fill: .thinMaterial))
    }

    private var heroObservationInfoBlocks: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 8) {
                heroMetricBlock(
                    title: "OBSERVING SITE",
                    value: selectedLocation?.name ?? "Choose a saved location",
                    caption: selectedLocation?.timeZoneIdentifier ?? "Location needed",
                    systemImage: "mappin.and.ellipse"
                )

                heroMetricBlock(
                    title: "SAVED LISTS",
                    value: "\(savedLists.count) available",
                    caption: selectedSavedList.map { "\($0.items.count) targets selected" } ?? "Build lists from Single Night",
                    systemImage: "tray.full"
                )

                heroMetricBlock(
                    title: "OBSERVATION WINDOW",
                    value: telescopeCaptureStartDate.map(formattedCaptureStart) ?? "Not set",
                    caption: telescopeCaptureStartDate == nil ? "Sun below horizon start" : "Telescope beginning window",
                    systemImage: "clock.badge.checkmark"
                )
            }
            .frame(maxWidth: .infinity, alignment: .center)

            VStack(alignment: .center, spacing: 8) {
                heroMetricBlock(
                    title: "OBSERVING SITE",
                    value: selectedLocation?.name ?? "Choose a saved location",
                    caption: selectedLocation?.timeZoneIdentifier ?? "Location needed",
                    systemImage: "mappin.and.ellipse"
                )

                heroMetricBlock(
                    title: "SAVED LISTS",
                    value: "\(savedLists.count) available",
                    caption: selectedSavedList.map { "\($0.items.count) targets selected" } ?? "Build lists from Single Night",
                    systemImage: "tray.full"
                )

                heroMetricBlock(
                    title: "OBSERVATION WINDOW",
                    value: telescopeCaptureStartDate.map(formattedCaptureStart) ?? "Not set",
                    caption: telescopeCaptureStartDate == nil ? "Sun below horizon start" : "Telescope beginning window",
                    systemImage: "clock.badge.checkmark"
                )
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func heroMetricBlock(
        title: String,
        value: String,
        caption: String,
        systemImage: String
    ) -> some View {
        VStack(alignment: .center, spacing: 4) {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 12, weight: .semibold))

                Text(title)
                    .font(heroMetricTitleFont)
            }
            .foregroundStyle(labelColor.opacity(0.92))
            .multilineTextAlignment(.center)

            Text(value)
                .font(heroMetricBodyFont)
                .foregroundStyle(.white)
                .lineLimit(2)
                .minimumScaleFactor(0.70)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)

            Text(caption)
                .font(heroMetricCaptionFont)
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 8)
        .frame(width: heroMetricWidth, height: heroMetricHeight, alignment: .center)
        .background(multiNightCardBackground(cornerRadius: 18, fill: .thinMaterial))
    }

    private var multiNightStatusBlock: some View {
        VStack(alignment: .center, spacing: 5) {
            Text("MULTI-NIGHT")
                .font(.system(size: 10, weight: .semibold, design: .rounded))
                .foregroundStyle(labelColor.opacity(0.84))

            Image(systemName: "calendar.badge.clock")
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(.white.opacity(0.94))

            Text(selectedSavedList?.name ?? "Choose a saved list")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.94))
                .lineLimit(2)
                .minimumScaleFactor(0.72)
                .multilineTextAlignment(.center)

            Text(selectedSavedList.map { formattedListDate($0.createdAt) } ?? "Ready for planning")
                .font(.system(size: 11, weight: .semibold, design: .rounded))
                .foregroundStyle(.white.opacity(0.78))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, minHeight: 116, alignment: .center)
        .background(multiNightCardBackground(cornerRadius: 20, fill: .thinMaterial))
    }

    private func savedListsSidebar(height: CGFloat) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Image(systemName: "list.bullet.rectangle.portrait")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(labelColor.opacity(0.92))

                Text("Saved Lists Database")
                    .font(compactStrongFont)
                    .foregroundStyle(labelColor.opacity(0.92))
                    .lineLimit(1)
            }

            if savedLists.isEmpty {
                Text("Saved single-night target lists will appear here for multi-night planning.")
                    .font(compactBodyFont)
                    .foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .frame(maxHeight: .infinity, alignment: .topLeading)
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(savedLists) { list in
                            savedListSidebarRow(list)
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
                    selectedSection = .planObservation
                } label: {
                    Label {
                        Text("Build From Single Night")
                            .lineLimit(2)
                            .multilineTextAlignment(.center)
                    } icon: {
                        Image(systemName: "scope")
                    }
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    selectedSection = .currentPlan
                } label: {
                    Label("Current Plan", systemImage: "list.bullet.clipboard")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)

                Button {
                    selectedSection = .home
                } label: {
                    Label("Return Home", systemImage: "house")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: height, maxHeight: height, alignment: .topLeading)
        .background(multiNightCardBackground())
    }

    private func savedListSidebarRow(_ list: SavedTargetList) -> some View {
        let isSelected = selectedSavedListID == list.id

        return Button {
            selectedSavedListID = list.id
        } label: {
            VStack(alignment: .leading, spacing: 3) {
                Text(list.name)
                    .font(compactStrongFont)
                    .foregroundStyle(.white.opacity(0.95))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)

                Text("\(list.items.count) targets - \(formattedListDate(list.createdAt))")
                    .font(compactCaptionFont)
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(multiNightCardBackground(cornerRadius: 14, fill: .thinMaterial))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(isSelected ? Color.accentColor.opacity(0.50) : Color.clear, lineWidth: 1.2)
            )
            .contentShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        }
        .buttonStyle(.plain)
    }

    private func centeredPlannerFilterCard(maxHeight: CGFloat) -> some View {
        plannerFilterCard(maxHeight: maxHeight)
            .frame(maxWidth: .infinity, alignment: .center)
    }

    private func plannerFilterCard(maxHeight: CGFloat) -> some View {
        ScrollView(.vertical) {
            plannerFilterCardContent
                .padding(10)
        }
        .scrollIndicators(.visible)
        .frame(maxWidth: contentCardMaxWidth, maxHeight: maxHeight, alignment: .topLeading)
        .background(multiNightCardBackground())
        .clipShape(RoundedRectangle(cornerRadius: 30, style: .continuous))
    }

    private var plannerFilterCardContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardHeading(
                title: "Multi-night Database Filters",
                centered: true
            )

            planningWindowControl
            savedListPickerControl
            planningSortOptionsControl
        }
        .frame(maxWidth: contentCardMaxWidth, alignment: .leading)
    }

    private var planningWindowControl: some View {
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
                locationSummaryField
                beginningWindowField
                savedListCountField
            }
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(multiNightCardBackground(cornerRadius: 18, fill: .ultraThinMaterial))
    }

    private var locationSummaryField: some View {
        VStack(alignment: .center, spacing: 6) {
            Text("Default Location")
                .font(compactSelectorLabelFont)
                .foregroundStyle(labelColor.opacity(0.92))
                .multilineTextAlignment(.center)

            Menu {
                ForEach(sites) { site in
                    Button(site.name) {
                        selectedLocationBinding.wrappedValue = site.id
                    }
                }
            } label: {
                menuControlLabel(selectedLocationName)
            }
            .buttonStyle(.plain)
            .disabled(sites.isEmpty)
        }
        .frame(minWidth: 190, maxWidth: .infinity, alignment: .center)
    }

    private var beginningWindowField: some View {
        VStack(alignment: .center, spacing: 6) {
            Text("Telescope Start")
                .font(compactSelectorLabelFont)
                .foregroundStyle(labelColor.opacity(0.92))
                .multilineTextAlignment(.center)

            Text(telescopeCaptureStartDate.map(formattedCaptureStart) ?? "Not set")
                .font(compactStrongFont)
                .foregroundStyle(.white.opacity(0.94))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .center)
                .padding(.horizontal, 10)
                .background(multiNightCardBackground(cornerRadius: 12, fill: .thinMaterial))
        }
        .frame(minWidth: 190, maxWidth: .infinity, alignment: .center)
    }

    private var savedListCountField: some View {
        VStack(alignment: .center, spacing: 6) {
            Text("Saved Target Lists")
                .font(compactSelectorLabelFont)
                .foregroundStyle(labelColor.opacity(0.92))
                .multilineTextAlignment(.center)

            Text("\(savedLists.count)")
                .font(compactStrongFont)
                .foregroundStyle(.white.opacity(0.94))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity, minHeight: 32, alignment: .center)
                .padding(.horizontal, 10)
                .background(multiNightCardBackground(cornerRadius: 12, fill: .thinMaterial))
        }
        .frame(minWidth: 190, maxWidth: .infinity, alignment: .center)
    }

    private var savedListPickerControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Target List")
                .font(compactSelectorLabelFont)
                .foregroundStyle(labelColor.opacity(0.92))

            Menu {
                ForEach(savedLists) { list in
                    Button("\(list.name) (\(list.items.count))") {
                        selectedSavedListID = list.id
                    }
                }
            } label: {
                menuControlLabel(selectedSavedList?.name ?? "Choose a saved target list")
            }
            .buttonStyle(.plain)
            .disabled(savedLists.isEmpty)
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(multiNightCardBackground(cornerRadius: 18, fill: .ultraThinMaterial))
    }

    private var planningSortOptionsControl: some View {
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
                Toggle("List Order", isOn: .constant(true))
                    .toggleStyle(.checkbox)
                Toggle("Night Window", isOn: .constant(false))
                    .toggleStyle(.checkbox)
                Toggle("Target Type", isOn: .constant(false))
                    .toggleStyle(.checkbox)
                Toggle("Magnitude", isOn: .constant(false))
                    .toggleStyle(.checkbox)
            }
            .font(compactBodyFont)
            .foregroundStyle(.white.opacity(0.92))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(multiNightCardBackground(cornerRadius: 18, fill: .ultraThinMaterial))
    }

    private var centeredTargetsCard: some View {
        targetsCard
            .frame(maxWidth: .infinity, alignment: .top)
    }

    private var targetsCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            cardHeading(
                title: "Targets",
                centered: true
            )

            if savedLists.isEmpty {
                Text("Save a target list from Single Night Observation to begin multi-night planning.")
                    .font(compactBodyFont)
                    .foregroundStyle(.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)

                Button {
                    selectedSection = .planObservation
                } label: {
                    Label("Go to Single Night", systemImage: "scope")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            } else if let selectedSavedList {
                selectedListHeader(selectedSavedList)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 4)

                targetFeedList(for: selectedSavedList)
            } else {
                Text("Choose a saved list to review its targets.")
                    .font(compactBodyFont)
                    .foregroundStyle(.white.opacity(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(10)
        .frame(maxWidth: contentCardMaxWidth, alignment: .topLeading)
        .background(multiNightCardBackground())
    }

    private func selectedListHeader(_ list: SavedTargetList) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 10) {
                headerSummary(title: "Target List", value: list.name)
                headerSummary(title: "Targets", value: "\(list.items.count)")
                headerSummary(title: "Created", value: formattedListDate(list.createdAt))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 8) {
                headerSummary(title: "Target List", value: list.name)
                headerSummary(title: "Targets", value: "\(list.items.count)")
                headerSummary(title: "Created", value: formattedListDate(list.createdAt))
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private func headerSummary(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(compactSelectorLabelFont)
                .foregroundStyle(labelColor.opacity(0.92))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(value)
                .font(compactStrongFont)
                .foregroundStyle(.white.opacity(0.94))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(minWidth: 150, maxWidth: .infinity, alignment: .leading)
    }

    private func targetFeedList(for list: SavedTargetList) -> some View {
        let items = sortedItems(for: list)

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 8) {
                Text("Target Feed")
                    .font(compactSelectorLabelFont)
                    .foregroundStyle(labelColor.opacity(0.92))

                Spacer(minLength: 0)

                Text("\(items.count) targets")
                    .font(compactCaptionFont)
                    .foregroundStyle(.white.opacity(0.72))
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 7) {
                    ForEach(items) { item in
                        targetFeedRow(item)
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
        .background(multiNightCardBackground(cornerRadius: 22, fill: .ultraThinMaterial))
    }

    private func targetFeedRow(_ item: SavedTargetListItem) -> some View {
        HStack(alignment: .center, spacing: 8) {
            Toggle("", isOn: .constant(true))
                .toggleStyle(.checkbox)
                .labelsHidden()
                .fixedSize()

            targetFeedRowContent(for: item)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 9)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(multiNightCardBackground(cornerRadius: 14, fill: .thinMaterial))
    }

    private func targetFeedRowContent(for item: SavedTargetListItem) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .center, spacing: 10) {
                targetFeedField(item.identifier, minimumWidth: 70, idealWidth: 84, maximumWidth: 92, font: compactStrongFont)
                targetFeedField(item.displayName, minimumWidth: 118, idealWidth: 220, maximumWidth: 240, font: compactStrongFont)
                    .layoutPriority(3)
                targetFeedField(item.typeName, minimumWidth: 82, idealWidth: 116, maximumWidth: 130, font: compactBodyFont)
                targetFeedField(item.constellation, minimumWidth: 38, idealWidth: 48, maximumWidth: 54, font: compactBodyFont)

                Spacer(minLength: 0)

                targetMagnitudeBadge(for: item)
                    .fixedSize(horizontal: true, vertical: false)
            }

            HStack(alignment: .center, spacing: 8) {
                targetFeedField(item.identifier, minimumWidth: 62, idealWidth: 74, maximumWidth: 82, font: compactStrongFont)
                targetFeedField(item.displayName, minimumWidth: 96, idealWidth: 170, maximumWidth: 190, font: compactStrongFont)
                    .layoutPriority(2)

                Spacer(minLength: 0)

                targetMagnitudeBadge(for: item)
                    .fixedSize(horizontal: true, vertical: false)
            }
        }
    }

    private func targetFeedField(
        _ text: String,
        minimumWidth: CGFloat,
        idealWidth: CGFloat,
        maximumWidth: CGFloat,
        font: Font
    ) -> some View {
        Text(text.isEmpty ? "-" : text)
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

    private func targetMagnitudeBadge(for item: SavedTargetListItem) -> some View {
        Text(item.magnitude.map { String(format: "Mag %.1f", $0) } ?? "Mag -")
            .font(compactCaptionFont)
            .foregroundStyle(.white.opacity(0.94))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule()
                    .fill(Color.black.opacity(0.22))
                    .overlay(
                        Capsule()
                            .stroke(labelColor.opacity(0.26), lineWidth: 1)
                    )
            )
    }

    private func menuControlLabel(_ text: String) -> some View {
        HStack(spacing: 8) {
            Text(text)
                .font(compactStrongFont)
                .foregroundStyle(.white.opacity(0.94))
                .lineLimit(1)
                .minimumScaleFactor(0.72)

            Spacer(minLength: 8)

            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.white.opacity(0.70))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
        .background(multiNightCardBackground(cornerRadius: 12, fill: .thinMaterial))
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
                    .foregroundStyle(.white.opacity(0.82))
                    .fixedSize(horizontal: false, vertical: true)
                    .multilineTextAlignment(textAlignment)
                    .frame(maxWidth: .infinity, alignment: frameAlignment)
            }
        }
    }

    private func multiNightCardBackground(
        cornerRadius: CGFloat = 30,
        fill: Material = .regularMaterial
    ) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.14), lineWidth: 1)
            )
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

        return sites.isEmpty ? "No saved location" : "Choose a saved location"
    }

    private var selectedLocation: ObservingSite? {
        guard let selectedLocationID else { return nil }
        return sites.first { $0.id == selectedLocationID }
    }

    private var selectedSavedList: SavedTargetList? {
        if let selectedSavedListID,
           let list = savedLists.first(where: { $0.id == selectedSavedListID }) {
            return list
        }

        return savedLists.first
    }

    private func sortedItems(for list: SavedTargetList) -> [SavedTargetListItem] {
        list.items.sorted {
            if $0.orderIndex == $1.orderIndex {
                return $0.identifier.localizedStandardCompare($1.identifier) == .orderedAscending
            }
            return $0.orderIndex < $1.orderIndex
        }
    }

    private func syncSelectedLocation() {
        selectedLocationID = LocationPreferenceStore.reconcileDefaultSiteID(using: sites)
    }

    private func syncSelectedSavedList() {
        let ids = Set(savedLists.map(\.id))
        if let selectedSavedListID, ids.contains(selectedSavedListID) {
            return
        }
        selectedSavedListID = savedLists.first?.id
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

    private func formattedListDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .none
        if let timeZoneIdentifier = selectedLocation?.timeZoneIdentifier,
           let timeZone = TimeZone(identifier: timeZoneIdentifier) {
            formatter.timeZone = timeZone
        }
        return formatter.string(from: date)
    }
}
