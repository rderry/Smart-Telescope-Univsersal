import Foundation
import SwiftData
import SwiftUI
import WebKit

private let equipmentHeroCardColor = Color(red: 0.80, green: 0.31, blue: 0.33)
private let equipmentCardColor = Color(red: 0.73, green: 0.24, blue: 0.26)
private let equipmentSubcardColor = Color(red: 0.86, green: 0.43, blue: 0.45)
private let equipmentSoftwareNoticeColor = Color(red: 0.10, green: 0.43, blue: 0.30)
private let equipmentInputFillColor = Color.white
private let equipmentDatabaseObjectColor = Color.white
private let equipmentActionDarkBlue = Color(red: 0.02, green: 0.16, blue: 0.44)

private enum EquipmentFormField: Hashable {
    case name
    case brand
    case model
    case aperture
    case focalLength
    case eyepieceFocalLength
    case apparentField
    case sensor
    case filter
    case mount
    case integratedComponents
    case accessory
    case specifications
    case notes
}

private struct EquipmentEntryDraft {
    let group: EquipmentCatalogGroup
    var category: EquipmentCategory
    var name = ""
    var brand = ""
    var modelName = ""
    var apertureText = ""
    var focalLengthText = ""
    var eyepieceFocalLengthText = ""
    var apparentFieldText = ""
    var sensorName = ""
    var filterDescription = ""
    var mountDescription = ""
    var integratedComponents = ""
    var accessoryDetails = ""
    var specifications = ""
    var notes = ""

    static func classic() -> Self {
        EquipmentEntryDraft(group: .classic, category: .telescope)
    }

    static func smart() -> Self {
        EquipmentEntryDraft(group: .smartTelescope, category: .smartTelescope)
    }

    var trimmedName: String {
        name.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    mutating func reset() {
        self = group == .classic ? .classic() : .smart()
    }
}

private struct PendingDefaultConflict {
    let selectedProfile: EquipmentProfile
    let otherGroup: EquipmentCatalogGroup
}

private enum EquipmentContinuePrompt: Identifiable {
    case verify(EquipmentCatalogGroup)
    case smartNoDefaultWarning
    case captureStart(EquipmentCatalogGroup)

    var id: String {
        switch self {
        case .verify(let group):
            "verify-\(group.rawValue)"
        case .smartNoDefaultWarning:
            "smart-no-default-warning"
        case .captureStart(let group):
            "capture-start-\(group.rawValue)"
        }
    }
}

private struct EquipmentGuideLink: Identifiable {
    let title: String
    let url: URL

    var id: String {
        url.absoluteString
    }
}

private struct EquipmentSheetControlCluster: View {
    let onClose: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            EquipmentSheetControlDot(
                color: Color(red: 1.0, green: 0.37, blue: 0.33),
                accessibilityLabel: "Close equipment card",
                action: onClose
            )

            EquipmentSheetControlDot(
                color: Color(red: 1.0, green: 0.74, blue: 0.18),
                accessibilityLabel: "This equipment card stays inside the Equipment page.",
                action: nil
            )

            EquipmentSheetControlDot(
                color: Color(red: 0.18, green: 0.78, blue: 0.35),
                accessibilityLabel: "This equipment card stays inside the Equipment page.",
                action: nil
            )
        }
        .padding(.top, 5)
    }
}

private struct EquipmentSheetControlDot: View {
    let color: Color
    let accessibilityLabel: String
    let action: (() -> Void)?

    var body: some View {
        Group {
            if let action {
                Button(action: action) {
                    dot
                }
                .buttonStyle(.plain)
            } else {
                dot
                    .opacity(0.72)
            }
        }
        .help(accessibilityLabel)
        .accessibilityLabel(accessibilityLabel)
    }

    private var dot: some View {
        Circle()
            .fill(color)
            .frame(width: 14, height: 14)
            .overlay(
                Circle()
                    .stroke(.black.opacity(0.18), lineWidth: 0.5)
            )
    }
}

private struct EquipmentGuideViewer: View {
    let guide: EquipmentGuideLink
    let onClose: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                EquipmentSheetControlCluster {
                    onClose()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(guide.title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.yellow)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)

                    Text("Official maker guide shown inside Smart Scope Observation Planner. Close this viewer to return to the equipment details.")
                        .font(AppTypography.body)
                        .foregroundStyle(.white.opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }

            EquipmentGuideWebView(url: guide.url)
                .frame(minWidth: 880, minHeight: 620)
                .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.18), lineWidth: 1)
                )
        }
        .padding(20)
        .frame(minWidth: 940, minHeight: 720, alignment: .topLeading)
        .background(equipmentCardColor)
    }
}

private struct EquipmentGuideWebView: NSViewRepresentable {
    let url: URL

    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.allowsBackForwardNavigationGestures = true
        webView.load(URLRequest(url: url))
        return webView
    }

    func updateNSView(_ webView: WKWebView, context: Context) {
        if webView.url != url {
            webView.load(URLRequest(url: url))
        }
    }
}

struct ProfilesWorkspaceView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(AppRuntimeState.self) private var runtimeState
    @Query(sort: \EquipmentProfile.name) private var equipmentProfiles: [EquipmentProfile]
    @Query(sort: \ObservingSite.name) private var sites: [ObservingSite]
    @Binding var selectedSection: SidebarSection

    @State private var defaultEquipmentID: UUID?
    @State private var classicDraft = EquipmentEntryDraft.classic()
    @State private var smartDraft = EquipmentEntryDraft.smart()
    @State private var classicStatusMessage = ""
    @State private var smartStatusMessage = ""
    @State private var selectedEquipmentIDs = [EquipmentCategory: UUID]()
    @State private var selectedAdditionalAccessoryIDs = [UUID]()
    @State private var selectedAdditionalSmartAccessoryIDs = [UUID]()
    @State private var focusedEquipmentIDs = [EquipmentCatalogGroup: UUID]()
    @State private var activeAddGroup: EquipmentCatalogGroup?
    @State private var refreshingGroups = Set<EquipmentCatalogGroup>()
    @State private var pendingDeleteEquipment: EquipmentProfile?
    @State private var pendingDefaultEquipment: EquipmentProfile?
    @State private var pendingDefaultConflict: PendingDefaultConflict?
    @State private var defaultChangePromptIsVisible = false
    @State private var defaultConflictPromptIsVisible = false
    @State private var pendingClearGroup: EquipmentCatalogGroup?
    @State private var presentedEquipmentProfileID: UUID?
    @State private var presentedGuide: EquipmentGuideLink?
    @State private var continuePrompt: EquipmentContinuePrompt?
    @State private var pendingContinueDestination: SidebarSection?
    @State private var captureStartDate = Date()
    @FocusState private var focusedField: EquipmentFormField?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            heroSection
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .frame(maxWidth: 1180, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)

            equipmentWorkspace
            .padding(.horizontal, 18)
            .padding(.bottom, 66)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .onAppear {
            syncDefaultSelection()
            syncSelectedEquipment()
        }
        .onChange(of: equipmentProfiles.map(\.id)) { _, _ in
            syncDefaultSelection()
            syncSelectedEquipment()
        }
        .alert("Change Default Equipment?", isPresented: defaultChangePromptIsPresented) {
            Button("Yes") {
                if let pendingDefaultEquipment {
                    applyDefaultEquipment(pendingDefaultEquipment)
                }
                pendingDefaultEquipment = nil
                defaultChangePromptIsVisible = false
            }

            Button("No", role: .cancel) {
                pendingDefaultEquipment = nil
                defaultChangePromptIsVisible = false
            }
        } message: {
            Text("A default equipment configuration already exists. Replace it with \(pendingDefaultEquipment?.groupedDisplayName ?? "this item")?")
        }
        .alert("Clear Other Telescope?", isPresented: defaultConflictPromptIsPresented) {
            Button("Yes") {
                if let pendingDefaultConflict {
                    clearTelescopeSelection(for: pendingDefaultConflict.otherGroup)
                    self.pendingDefaultConflict = nil
                    defaultConflictPromptIsVisible = false
                    requestDefaultChange(to: pendingDefaultConflict.selectedProfile, checkOtherCardSelection: false)
                } else {
                    defaultConflictPromptIsVisible = false
                }
            }

            Button("No", role: .cancel) {
                pendingDefaultConflict = nil
                defaultConflictPromptIsVisible = false
            }
        } message: {
            Text("Another telescope is already selected. Clear that selection and make \(pendingDefaultConflict?.selectedProfile.groupedDisplayName ?? "this telescope") the default?")
        }
        .alert("Confirm Deletion", isPresented: deleteConfirmationIsPresented) {
            Button("Delete", role: .destructive) {
                if let pendingDeleteEquipment {
                    confirmDeleteEquipment(pendingDeleteEquipment)
                }
                pendingDeleteEquipment = nil
            }

            Button("No", role: .cancel) {
                pendingDeleteEquipment = nil
            }
        } message: {
            Text("Delete \(pendingDeleteEquipment?.groupedDisplayName ?? "this equipment") from the equipment database?")
        }
        .alert("Clear Equipment List?", isPresented: clearConfirmationIsPresented) {
            Button("Yes", role: .destructive) {
                if let pendingClearGroup {
                    clearAllEquipmentSelections(reportingFrom: pendingClearGroup)
                }
                pendingClearGroup = nil
            }

            Button("No", role: .cancel) {
                pendingClearGroup = nil
            }
        } message: {
            Text("Are you sure you want to clear all selected equipment from the sidebar?")
        }
        .sheet(item: $activeAddGroup) { group in
            equipmentAddSheet(for: group)
                .presentationBackground(equipmentCardColor)
        }
        .sheet(isPresented: equipmentDetailIsPresented) {
            if let presentedEquipmentProfile {
                equipmentDetailWindow(for: presentedEquipmentProfile)
                    .presentationBackground(equipmentCardColor)
            } else {
                Text("This equipment item is no longer available.")
                    .font(AppTypography.body)
                    .padding(24)
                    .presentationBackground(equipmentCardColor)
            }
        }
        .sheet(item: $continuePrompt) { prompt in
            equipmentContinueWindow(for: prompt)
                .presentationBackground(equipmentCardColor)
        }
    }

    private var heroSection: some View {
        VStack(alignment: .center, spacing: 9) {
            Text("Observation Equipment")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color.yellow)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .shadow(color: Color.black.opacity(0.35), radius: 8, y: 2)

            Text("Organize smart telescope systems, pick your default Smart Scope, and keep compatible accessories ready for planning workflows.")
                .font(AppTypography.body)
                .foregroundStyle(.white.opacity(0.92))
                .frame(maxWidth: 820, alignment: .center)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(cardBackground(cornerRadius: 32, fill: equipmentHeroCardColor))
        .shadow(color: .black.opacity(0.10), radius: 24, y: 12)
    }

    private var equipmentWorkspace: some View {
        HStack(alignment: .top, spacing: 18) {
            equipmentListCard
                .frame(width: 300)
                .frame(maxHeight: 660, alignment: .top)

            Spacer(minLength: 24)

            equipmentCardsStack
                .frame(width: 760)
                .frame(maxHeight: .infinity, alignment: .topTrailing)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var equipmentCardsStack: some View {
        smartEquipmentCard
            .frame(width: 760)
            .frame(maxHeight: .infinity)
            .frame(width: 760, alignment: .topTrailing)
        .frame(maxHeight: .infinity, alignment: .topTrailing)
    }

    private var equipmentListCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Equipment List")
                .font(AppTypography.bodyEmphasized)
                .foregroundStyle(Color.yellow)

            Text("Tap an item to focus it in the matching equipment card.")
                .font(.system(size: 12.5, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.84))
                .fixedSize(horizontal: false, vertical: true)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 12) {
                    equipmentListSection(for: .smartTelescope)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .scrollTargetLayout()
            }
            .frame(height: 488, alignment: .top)
            .scrollTargetBehavior(.viewAligned)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(cardBackground(cornerRadius: 26, fill: equipmentSubcardColor))
    }

    private func equipmentListSection(for group: EquipmentCatalogGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(group.displayName)
                    .font(.system(size: 13.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Spacer(minLength: 0)

                Button("Keep in Database") {
                    keepCurrentConfigurationInDatabase(for: group)
                }
                .buttonStyle(.bordered)
                .tint(equipmentActionDarkBlue)
                .foregroundStyle(equipmentActionDarkBlue)
                .controlSize(.mini)
                .font(.system(size: 11.2, weight: .semibold, design: .rounded))
                .disabled(!canKeepCurrentConfiguration(for: group))
            }

            let groupProfiles = selectedEquipmentListProfiles(for: group)
            if groupProfiles.isEmpty {
                Text("No selected items.")
                    .font(.system(size: 12.5, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(groupProfiles) { profile in
                    equipmentListRow(profile)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func equipmentListRow(_ profile: EquipmentProfile) -> some View {
        Button {
            focusEquipmentFromList(profile)
        } label: {
            VStack(alignment: .leading, spacing: 4) {
                Text(profile.name)
                    .font(.system(size: 12.8, weight: .bold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.88))
                    .lineLimit(2)
                    .minimumScaleFactor(0.74)

                Text("\(profile.category.displayName) • \(makerName(for: profile))")
                    .font(.system(size: 11.8, weight: .medium, design: .rounded))
                    .foregroundStyle(.black.opacity(0.68))
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(height: 58, alignment: .leading)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground(cornerRadius: 16, fill: equipmentDatabaseObjectColor))
        }
        .buttonStyle(.plain)
        .help("Focus \(profile.groupedDisplayName)")
    }

    private var smartEquipmentCard: some View {
        equipmentGroupCard(
            title: "Smart Telescope Systems",
            subtitle: "Smart telescope systems and platform-specific accessories.",
            draft: $smartDraft,
            group: .smartTelescope
        )
    }

    private func equipmentGroupCard(
        title: String,
        subtitle: String,
        draft: Binding<EquipmentEntryDraft>,
        group: EquipmentCatalogGroup
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            groupHeader(title: title, subtitle: subtitle, group: group)

            ScrollView(.vertical, showsIndicators: true) {
                VStack(alignment: .leading, spacing: 10) {
                    selectedConfigurationSection(group: group)
                    groupDatabaseSection(group: group)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxHeight: .infinity)

            continueBar(for: group)
        }
        .padding(14)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(cardBackground())
    }

    private func continueBar(for group: EquipmentCatalogGroup) -> some View {
        HStack(spacing: 10) {
            continueShortcutButton(
                title: "Continue to Single Night Plan",
                systemImage: "scope",
                group: group,
                destination: .planObservation
            )

            continueShortcutButton(
                title: "Continue to Multi-night Plan",
                systemImage: "calendar.badge.clock",
                group: group,
                destination: .multiNightObservation
            )
        }
        .font(.system(size: 12.6, weight: .bold, design: .rounded))
        .padding(.top, 2)
    }

    private func continueShortcutButton(
        title: String,
        systemImage: String,
        group: EquipmentCatalogGroup,
        destination: SidebarSection
    ) -> some View {
        Button {
            beginContinueFlow(for: group, destination: destination)
        } label: {
            VStack(spacing: 3) {
                Image(systemName: systemImage)
                    .font(.system(size: 13.2, weight: .semibold))

                Text(title)
                    .lineLimit(2)
                    .minimumScaleFactor(0.76)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .foregroundStyle(.white)
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.regular)
    }

    private func groupHeader(title: String, subtitle: String, group: EquipmentCatalogGroup) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            groupHeaderText(title: title, subtitle: subtitle, group: group)
            groupHeaderActions(group: group)
        }
        .frame(minHeight: 108, alignment: .top)
    }

    private func groupHeaderText(title: String, subtitle: String, group: EquipmentCatalogGroup) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(title)
                    .font(AppTypography.bodyEmphasized)
                    .foregroundStyle(Color.yellow)

                if !statusBinding(for: group).wrappedValue.isEmpty {
                    Text(statusBinding(for: group).wrappedValue)
                        .font(.system(size: 11.2, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.84))
                        .lineLimit(1)
                        .minimumScaleFactor(0.68)
                }

                Spacer(minLength: 0)
            }

            Text(subtitle)
                .font(.system(size: 12.2, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.88))
                .lineLimit(2)
                .minimumScaleFactor(0.78)
                .fixedSize(horizontal: false, vertical: true)

            Text("Default Telescope: \(defaultEquipmentName(for: group))")
                .font(.system(size: 12.2, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.92))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .fixedSize(horizontal: false, vertical: true)

            Text("Last Update: \(refreshDateText(for: group))")
                .font(.system(size: 12.2, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(1)
                .minimumScaleFactor(0.78)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func groupHeaderActions(group: EquipmentCatalogGroup) -> some View {
        HStack(alignment: .center, spacing: 7) {
            Spacer(minLength: 0)

            Button {
                activeAddGroup = group
            } label: {
                Label("Add", systemImage: "plus.circle.fill")
                    .foregroundStyle(equipmentActionDarkBlue)
            }
            .buttonStyle(.borderedProminent)
            .tint(equipmentActionDarkBlue)

            Button {
                requestDefaultTelescope(for: group)
            } label: {
                Label("Default", systemImage: "star.circle")
                    .foregroundStyle(equipmentActionDarkBlue)
            }
            .buttonStyle(.bordered)
            .tint(equipmentActionDarkBlue)
            .disabled(group != .smartTelescope || selectedTelescope(for: group) == nil)

            Button {
                refreshGroup(group)
            } label: {
                if refreshingGroups.contains(group) {
                    ProgressView()
                        .controlSize(.small)
                        .tint(equipmentActionDarkBlue)
                } else {
                    Label("Refresh", systemImage: "arrow.clockwise")
                        .foregroundStyle(equipmentActionDarkBlue)
                }
            }
            .buttonStyle(.bordered)
            .tint(equipmentActionDarkBlue)
            .disabled(refreshingGroups.contains(group))

            Button(role: .destructive) {
                pendingClearGroup = group
            } label: {
                Label("Clear", systemImage: "xmark.circle")
            }
            .buttonStyle(.bordered)

            Spacer(minLength: 0)
        }
        .font(.system(size: 12.2, weight: .semibold, design: .rounded))
        .labelStyle(.titleAndIcon)
        .lineLimit(1)
        .minimumScaleFactor(0.78)
        .controlSize(.small)
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private func selectedConfigurationSection(group: EquipmentCatalogGroup) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Selected Configuration")
                .font(AppTypography.bodyEmphasized)
                .foregroundStyle(.white.opacity(0.94))

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: configurationColumnMinimum(for: group)), spacing: 8, alignment: .top)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(EquipmentCategory.categories(for: group)) { category in
                    equipmentDropdown(for: category)
                }
            }

        }
    }

    private func equipmentDropdown(for category: EquipmentCategory) -> some View {
        VStack(alignment: .leading, spacing: category == .smartAccessory ? 4 : 5) {
            Text(category.displayName)
                .font(.system(size: category == .smartAccessory ? 12 : 12.6, weight: .semibold, design: .rounded))
                .foregroundStyle(.black.opacity(0.88))

            Picker(category.displayName, selection: selectedEquipmentBinding(for: category)) {
                Text("None").tag(UUID?.none)
                ForEach(profiles(for: category)) { profile in
                    Text(profile.groupedDisplayName).tag(Optional(profile.id))
                }
            }
            .labelsHidden()
            .pickerStyle(.menu)
            .tint(.black)
            .padding(.horizontal, category == .smartAccessory ? 6 : 8)
            .padding(.vertical, category == .smartAccessory ? 4 : 5)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(equipmentInputFillColor)
            )

            Text(equipmentDropdownSummary(for: category))
                .font(.system(size: category == .smartAccessory ? 11.1 : 12, weight: .regular, design: .rounded))
                .foregroundStyle(.black.opacity(0.76))
                .lineLimit(category == .smartAccessory ? 1 : 2)
                .minimumScaleFactor(0.76)
                .fixedSize(horizontal: false, vertical: true)

            if category.supportsMultipleSelection {
                multipleAccessorySelectionSummary(for: category)
            }
        }
        .padding(category == .smartAccessory ? 8 : 9)
        .frame(maxWidth: .infinity, minHeight: dropdownMinimumHeight(for: category), alignment: .topLeading)
        .background(cardBackground(cornerRadius: 18, fill: equipmentInputFillColor))
    }

    @ViewBuilder
    private func multipleAccessorySelectionSummary(for category: EquipmentCategory) -> some View {
        let selectedProfiles = selectedMultipleEquipmentProfiles(for: category)

        VStack(alignment: .leading, spacing: category == .smartAccessory ? 4 : 6) {
            if selectedProfiles.isEmpty {
                Text("Select an item to add it to this configuration.")
                    .font(.system(size: category == .smartAccessory ? 10.8 : 12, weight: .regular, design: .rounded))
                    .foregroundStyle(.black.opacity(0.62))
                    .lineLimit(category == .smartAccessory ? 1 : 2)
                    .minimumScaleFactor(0.72)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                ForEach(selectedProfiles) { profile in
                    HStack(spacing: 6) {
                        Text(profile.groupedDisplayName)
                            .font(.system(size: category == .smartAccessory ? 10.9 : 12, weight: .semibold, design: .rounded))
                            .foregroundStyle(.black.opacity(0.78))
                            .lineLimit(1)
                            .minimumScaleFactor(0.74)

                        Spacer(minLength: 4)

                        Button {
                            removeMultipleEquipmentSelection(profile.id, for: category)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(.black.opacity(0.55))
                        .help("Remove \(profile.groupedDisplayName)")
                    }
                }

                Button("Clear selected \(category.displayName.lowercased())") {
                    clearMultipleEquipmentSelections(for: category)
                }
                .buttonStyle(.borderless)
                .font(.system(size: category == .smartAccessory ? 10.8 : 11.6, weight: .semibold, design: .rounded))
                .foregroundStyle(.black.opacity(0.70))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func equipmentAddSheet(for group: EquipmentCatalogGroup) -> some View {
        let draft = $smartDraft

        return VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                EquipmentSheetControlCluster {
                    activeAddGroup = nil
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Add Smart Equipment")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.yellow)

                    Text("Add a custom item to the equipment database, then select it from the dropdowns on the card.")
                        .font(AppTypography.body)
                        .foregroundStyle(.white.opacity(0.88))
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                Button("Cancel") {
                    activeAddGroup = nil
                }
                .keyboardShortcut(.cancelAction)
            }

            ScrollView {
                groupEntrySection(draft: draft, group: group)
                    .padding(.vertical, 4)
            }
            .frame(minHeight: 380)

            HStack {
                Spacer()

                Button("Add to Database") {
                    if addEquipment(draft: draft.wrappedValue) {
                        activeAddGroup = nil
                    }
                }
                .buttonStyle(.borderedProminent)
                .disabled(draft.wrappedValue.trimmedName.isEmpty)
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 640, alignment: .topLeading)
        .frame(minHeight: 620, alignment: .topLeading)
        .background(equipmentCardColor)
    }

    private func groupEntrySection(
        draft: Binding<EquipmentEntryDraft>,
        group: EquipmentCatalogGroup
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Type", selection: draft.category) {
                ForEach(EquipmentCategory.categories(for: group)) { category in
                    Text(category.displayName).tag(category)
                }
            }
            .pickerStyle(.menu)
            .tint(.black)
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(equipmentInputFillColor)
            )

            labeledTextField("Name", text: draft.name, field: .name)

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    labeledTextField("Brand", text: draft.brand, field: .brand)
                    labeledTextField("Model", text: draft.modelName, field: .model)
                }

                VStack(alignment: .leading, spacing: 12) {
                    labeledTextField("Brand", text: draft.brand, field: .brand)
                    labeledTextField("Model", text: draft.modelName, field: .model)
                }
            }

            groupSpecificFields(draft: draft)

            if !statusBinding(for: group).wrappedValue.isEmpty {
                Text(statusBinding(for: group).wrappedValue)
                    .font(AppTypography.body)
                    .foregroundStyle(.white.opacity(0.90))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    @ViewBuilder
    private func groupSpecificFields(draft: Binding<EquipmentEntryDraft>) -> some View {
        switch draft.wrappedValue.category {
        case .telescope:
            telescopeFields(draft: draft, isSmart: false)
        case .camera:
            cameraFields(draft: draft)
        case .eyepiece:
            eyepieceFields(draft: draft)
        case .filterSystem:
            filterFields(draft: draft)
        case .mount:
            mountFields(draft: draft)
        case .accessory:
            accessoryFields(draft: draft, isSmart: false)
        case .smartTelescope:
            telescopeFields(draft: draft, isSmart: true)
        case .smartAccessory:
            accessoryFields(draft: draft, isSmart: true)
        }
    }

    private func telescopeFields(draft: Binding<EquipmentEntryDraft>, isSmart: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    labeledNumericField("Aperture (mm)", text: draft.apertureText, field: .aperture)
                    labeledNumericField("Focal Length (mm)", text: draft.focalLengthText, field: .focalLength)
                }

                VStack(alignment: .leading, spacing: 12) {
                    labeledNumericField("Aperture (mm)", text: draft.apertureText, field: .aperture)
                    labeledNumericField("Focal Length (mm)", text: draft.focalLengthText, field: .focalLength)
                }
            }

            labeledTextField("Mount", text: draft.mountDescription, field: .mount)
            labeledTextField("Sensor / Optics", text: draft.sensorName, field: .sensor)

            if isSmart {
                labeledTextField("Integrated Components", text: draft.integratedComponents, field: .integratedComponents)
            }

            labeledTextField("Specifications", text: draft.specifications, field: .specifications)
            labeledTextField("Notes", text: draft.notes, field: .notes)
        }
    }

    private func cameraFields(draft: Binding<EquipmentEntryDraft>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            labeledTextField("Sensor", text: draft.sensorName, field: .sensor)
            labeledTextField("Specifications", text: draft.specifications, field: .specifications)
            labeledTextField("Notes", text: draft.notes, field: .notes)
        }
    }

    private func eyepieceFields(draft: Binding<EquipmentEntryDraft>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    labeledNumericField("Focal Length (mm)", text: draft.eyepieceFocalLengthText, field: .eyepieceFocalLength)
                    labeledNumericField("Apparent Field (°)", text: draft.apparentFieldText, field: .apparentField)
                }

                VStack(alignment: .leading, spacing: 12) {
                    labeledNumericField("Focal Length (mm)", text: draft.eyepieceFocalLengthText, field: .eyepieceFocalLength)
                    labeledNumericField("Apparent Field (°)", text: draft.apparentFieldText, field: .apparentField)
                }
            }

            labeledTextField("Specifications", text: draft.specifications, field: .specifications)
            labeledTextField("Notes", text: draft.notes, field: .notes)
        }
    }

    private func filterFields(draft: Binding<EquipmentEntryDraft>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            labeledTextField("Filter Description", text: draft.filterDescription, field: .filter)
            labeledTextField("Specifications", text: draft.specifications, field: .specifications)
            labeledTextField("Notes", text: draft.notes, field: .notes)
        }
    }

    private func mountFields(draft: Binding<EquipmentEntryDraft>) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            labeledTextField("Mount Type", text: draft.mountDescription, field: .mount)
            labeledTextField("Specifications", text: draft.specifications, field: .specifications)
            labeledTextField("Notes", text: draft.notes, field: .notes)
        }
    }

    private func accessoryFields(draft: Binding<EquipmentEntryDraft>, isSmart: Bool) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            labeledTextField(isSmart ? "Smart Accessory Details" : "Other Device Details", text: draft.accessoryDetails, field: .accessory)
            labeledTextField("Specifications", text: draft.specifications, field: .specifications)
            labeledTextField("Notes", text: draft.notes, field: .notes)
        }
    }

    private func groupDatabaseSection(group: EquipmentCatalogGroup) -> some View {
        VStack(alignment: .leading, spacing: 7) {
            Text("Smart Database")
                .font(AppTypography.bodyEmphasized)
                .foregroundStyle(.white.opacity(0.92))

            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 8) {
                    if profiles(for: group).isEmpty {
                        Text("No smart equipment saved yet.")
                            .font(AppTypography.body)
                            .foregroundStyle(.white.opacity(0.86))
                    } else {
                        ForEach(profiles(for: group)) { profile in
                            equipmentRow(profile)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(height: databaseViewportHeight(for: group))
            .id(databaseSelectionKey(for: group))
        }
        .padding(.trailing, 0)
    }

    private func configurationColumnMinimum(for group: EquipmentCatalogGroup) -> CGFloat {
        164
    }

    private func dropdownMinimumHeight(for category: EquipmentCategory) -> CGFloat {
        switch category {
        case .smartAccessory:
            104
        case .accessory:
            130
        default:
            92
        }
    }

    private func equipmentRow(_ profile: EquipmentProfile) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text("Maker: \(makerName(for: profile))")
                        .font(.system(size: 12.2, weight: .bold, design: .rounded))
                        .foregroundStyle(.black)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Button("Open Details") {
                        presentedEquipmentProfileID = profile.id
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.mini)
                    .font(.system(size: 10.2, weight: .semibold, design: .rounded))
                    .lineLimit(1)
                    .help("Open equipment details")
                }

                Text(profile.name)
                    .font(.system(size: 12.4, weight: .bold, design: .rounded))
                    .foregroundStyle(.black.opacity(0.92))
                    .lineLimit(2)
                    .minimumScaleFactor(0.74)

                if let modelText = modelName(for: profile) {
                    Text("Model: \(modelText)")
                        .font(.system(size: 11.2, weight: .regular, design: .rounded))
                        .foregroundStyle(.black.opacity(0.72))
                        .lineLimit(1)
                        .minimumScaleFactor(0.74)
                }

                ForEach(equipmentDetailLines(for: profile), id: \.self) { line in
                    Text(line)
                        .font(.system(size: 10.9, weight: .regular, design: .rounded))
                        .foregroundStyle(.black.opacity(0.70))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .onTapGesture {
                openDatabaseRowDetails(for: profile)
            }
            .help("Open equipment details")

            Spacer(minLength: 4)

            VStack(alignment: .trailing, spacing: 6) {
                VStack(alignment: .trailing, spacing: 6) {
                    if profile.isPlanCompatibleDefault {
                        Toggle("Select as Default", isOn: defaultBinding(for: profile))
                            .toggleStyle(.checkbox)
                            .font(.system(size: 10.6, weight: .regular, design: .rounded))
                            .foregroundStyle(.black.opacity(0.86))
                    }

                    Button(role: .destructive) {
                        pendingDeleteEquipment = profile
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                    .buttonStyle(.borderless)
                }

                Spacer(minLength: 6)

                VStack(alignment: .trailing, spacing: 4) {
                    if let smartSupportText = smartDeviceSupportText(for: profile) {
                        Text(smartSupportText)
                            .font(.system(size: 10.1, weight: .medium, design: .rounded))
                            .foregroundStyle(.black.opacity(0.70))
                            .multilineTextAlignment(.trailing)
                            .lineLimit(2)
                            .minimumScaleFactor(0.68)
                    }

                    Text(typeLabel(for: profile))
                        .font(.system(size: 10.8, weight: .bold, design: .rounded))
                        .foregroundStyle(typeTextColor(for: profile))
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)
                        .padding(.horizontal, 7)
                        .padding(.vertical, 4)
                        .background(
                            Capsule(style: .continuous)
                                .fill(typeFillColor(for: profile))
                        )
                }
            }
            .frame(width: 118, alignment: .topTrailing)
        }
        .padding(10)
        .frame(height: equipmentRowHeight(for: profile), alignment: .topLeading)
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .background(cardBackground(cornerRadius: 24, fill: equipmentDatabaseObjectColor))
    }

    private func openDatabaseRowDetails(for profile: EquipmentProfile) {
        presentedEquipmentProfileID = profile.id
    }

    private func databaseViewportHeight(for group: EquipmentCatalogGroup) -> CGFloat {
        174
    }

    private func equipmentRowHeight(for profile: EquipmentProfile) -> CGFloat {
        174
    }

    @ViewBuilder
    private func equipmentContinueWindow(for prompt: EquipmentContinuePrompt) -> some View {
        switch prompt {
        case .verify(let group):
            continueVerificationWindow(for: group)
        case .smartNoDefaultWarning:
            smartNoDefaultContinueWindow
        case .captureStart(let group):
            telescopeCaptureStartWindow(for: group)
        }
    }

    private func continueVerificationWindow(for group: EquipmentCatalogGroup) -> some View {
        equipmentContinuePanel(
            title: "Verify Smart Telescope",
            message: continueVerificationMessage(for: group)
        ) {
            HStack(spacing: 10) {
                Button("No") {
                    cancelContinueFlow()
                }
                .keyboardShortcut(.cancelAction)

                Button("Yes, Continue") {
                    askForTelescopeCaptureStart(for: group)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private var smartNoDefaultContinueWindow: some View {
        equipmentContinuePanel(
            title: "No Default Smart Telescope",
            message: "Without choosing your default Smart Telescope, the Observation Targets you are shown may not be possible for your Smart Scope to capture. Continue?"
        ) {
            HStack(spacing: 10) {
                Button("No") {
                    cancelContinueFlow()
                }
                .keyboardShortcut(.cancelAction)

                Button("Yes") {
                    askForTelescopeCaptureStart(for: .smartTelescope)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
        }
    }

    private func telescopeCaptureStartWindow(for group: EquipmentCatalogGroup) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                EquipmentSheetControlCluster {
                    cancelContinueFlow()
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Capture Start Time")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.yellow)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    Text("What time is your telescope able to start capture?")
                        .font(AppTypography.body)
                        .foregroundStyle(.white.opacity(0.90))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            FlexibleClockTimeField(
                title: "Telescope capture can start at",
                selection: $captureStartDate,
                width: 190,
                labelColor: .white.opacity(0.90),
                textColor: .white,
                helperColor: .white.opacity(0.76),
                titleFont: AppTypography.body,
                showsHelper: true
            )

            Text("This time will be used as the Sun Below Horizon start for the planner.")
                .font(.system(size: 12.5, weight: .regular, design: .rounded))
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 10) {
                Button("Cancel") {
                    cancelContinueFlow()
                }
                .keyboardShortcut(.cancelAction)

                Button("Continue") {
                    performContinueWithCaptureStart(for: group)
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(22)
        .frame(width: 520, alignment: .topLeading)
        .background(equipmentCardColor)
    }

    private func equipmentContinuePanel<Actions: View>(
        title: String,
        message: String,
        @ViewBuilder actions: () -> Actions
    ) -> some View {
        VStack(alignment: .leading, spacing: 18) {
            HStack(alignment: .top, spacing: 12) {
                EquipmentSheetControlCluster {
                    cancelContinueFlow()
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(title)
                        .font(.title2.weight(.bold))
                        .foregroundStyle(Color.yellow)
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    Text(message)
                        .font(AppTypography.body)
                        .foregroundStyle(.white.opacity(0.90))
                        .lineSpacing(3)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            actions()
                .frame(maxWidth: .infinity, alignment: .center)
        }
        .padding(22)
        .frame(width: 520, alignment: .topLeading)
        .background(equipmentCardColor)
    }

    @ViewBuilder
    private func equipmentDetailWindow(for profile: EquipmentProfile) -> some View {
        if isMeadeEquipment(profile) {
            meadeEquipmentNoticeWindow(for: profile)
        } else if requiresBrowserProductNotice(profile) {
            browserProductNoticeWindow(for: profile)
        } else {
            VStack(alignment: .leading, spacing: 16) {
                HStack(alignment: .top, spacing: 12) {
                    EquipmentSheetControlCluster {
                        closeEquipmentDetail()
                    }

                    VStack(alignment: .leading, spacing: 4) {
                        Text(profile.name)
                            .font(.title2.weight(.bold))
                            .foregroundStyle(Color.yellow)
                            .fixedSize(horizontal: false, vertical: true)

                        Text("\(makerName(for: profile)) \(typeLabel(for: profile))")
                            .font(AppTypography.body)
                            .foregroundStyle(.white.opacity(0.88))
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Spacer()
                }

                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 14) {
                        equipmentDetailSection(title: "Equipment", lines: equipmentOverviewLines(for: profile))
                        equipmentDetailSection(title: "Technical Details", lines: equipmentDetailLines(for: profile))

                        if let supportText = smartDeviceSupportText(for: profile) {
                            equipmentDetailSection(title: "App and Device Support", lines: [supportText])
                        }

                        officialGuideSection(for: profile)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .padding(20)
            .frame(width: 640, alignment: .topLeading)
            .frame(minHeight: 520, alignment: .topLeading)
            .background(equipmentCardColor)
            .sheet(item: $presentedGuide) { guide in
                EquipmentGuideViewer(guide: guide) {
                    presentedGuide = nil
                }
                .presentationBackground(equipmentCardColor)
            }
        }
    }

    private func meadeEquipmentNoticeWindow(for profile: EquipmentProfile) -> some View {
        VStack(alignment: .center, spacing: 26) {
            HStack {
                EquipmentSheetControlCluster {
                    closeEquipmentDetail()
                }

                Spacer()
            }

            Spacer(minLength: 0)

            VStack(alignment: .center, spacing: 22) {
                Text("Meade has gone out of business, we are sorry we have no information to show you!")

                Text("We recommend you use a search engine in your browser of choice and search for archived data.")

                Text("Thank you for understanding.")
            }
            .font(.system(size: 31, weight: .bold, design: .rounded))
            .foregroundStyle(.black)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 14)
            .accessibilityLabel("Meade notice for \(profile.groupedDisplayName)")

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 640, alignment: .top)
        .frame(minHeight: 520, alignment: .top)
        .background(equipmentCardColor)
    }

    private func browserProductNoticeWindow(for profile: EquipmentProfile) -> some View {
        VStack(alignment: .center, spacing: 26) {
            HStack {
                EquipmentSheetControlCluster {
                    closeEquipmentDetail()
                }

                Spacer()
            }

            Spacer(minLength: 0)

            VStack(alignment: .center, spacing: 24) {
                Text("Please use your browser to obtain information on these products.")

                Text("Thank you very much.")
            }
            .font(.system(size: 31, weight: .bold, design: .rounded))
            .foregroundStyle(.black)
            .multilineTextAlignment(.center)
            .lineLimit(nil)
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.horizontal, 14)
            .accessibilityLabel("Browser information notice for \(profile.groupedDisplayName)")

            Spacer(minLength: 0)
        }
        .padding(20)
        .frame(width: 640, alignment: .top)
        .frame(minHeight: 520, alignment: .top)
        .background(equipmentSoftwareNoticeColor)
    }

    @ViewBuilder
    private func equipmentDetailSection(title: String, lines: [String]) -> some View {
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text(title)
                    .font(AppTypography.bodyEmphasized)
                    .foregroundStyle(Color.yellow)

                ForEach(lines, id: \.self) { line in
                    Text(line)
                        .font(AppTypography.body)
                        .foregroundStyle(.white.opacity(0.90))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground(cornerRadius: 20, fill: equipmentSubcardColor))
        }
    }

    @ViewBuilder
    private func officialGuideSection(for profile: EquipmentProfile) -> some View {
        if profile.catalogGroup == .smartTelescope {
            let links = officialGuideLinks(for: profile)

            VStack(alignment: .leading, spacing: 10) {
                Text("Official Setup and Product Guides")
                    .font(AppTypography.bodyEmphasized)
                    .foregroundStyle(Color.yellow)

                Text("These open official maker or manufacturer-managed support pages in the in-app viewer. Manuals are not copied into the app, which keeps us clear of redistribution/copyright issues.")
                    .font(.system(size: 12.5, weight: .regular, design: .rounded))
                    .foregroundStyle(.white.opacity(0.86))
                    .fixedSize(horizontal: false, vertical: true)

                if links.isEmpty {
                    Text("No official guide link has been attached for this equipment yet.")
                        .font(AppTypography.body)
                        .foregroundStyle(.white.opacity(0.88))
                } else {
                    ForEach(links) { guide in
                        Button {
                            presentedGuide = guide
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: "doc.text.magnifyingglass")
                                Text(guide.title)
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.82)
                                Spacer(minLength: 0)
                                Image(systemName: "arrow.up.right.square")
                            }
                            .font(AppTypography.body)
                            .foregroundStyle(.white)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 14, style: .continuous)
                                    .fill(.black.opacity(0.18))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(cardBackground(cornerRadius: 20, fill: equipmentSubcardColor))
        }
    }

    private func equipmentOverviewLines(for profile: EquipmentProfile) -> [String] {
        var lines = [
            "Maker: \(makerName(for: profile))",
            "Type: \(typeLabel(for: profile))"
        ]

        if let modelText = modelName(for: profile) {
            lines.append("Model: \(modelText)")
        }

        return lines
    }

    private func officialGuideLinks(for profile: EquipmentProfile) -> [EquipmentGuideLink] {
        guard !isMeadeEquipment(profile) else { return [] }

        let brand = profile.brand.lowercased()
        let name = profile.name.lowercased()
        var links = [(String, String)]()

        if brand.contains("vaonis") || name.contains("vespera") || name.contains("stellina") {
            links.append(("Vaonis Manuals and Documents", "https://vaonis.com/pages/manuals-documents"))
        }

        if brand.contains("unistellar") || name.contains("unistellar") || name.contains("evscope") || name.contains("equinox") || name.contains("odyssey") {
            links.append(("Unistellar Help Center and User Manuals", "https://help.unistellar.com/hc/en-us"))
        }

        if brand.contains("zwo") || name.contains("seestar") {
            if name.contains("s30") {
                links.append(("Seestar S30 Product Guides", "https://store.seestar.com/products/seestar-s30-all-in-one-smart-telescope-tiny-and-mighty"))
            } else {
                links.append(("Seestar S50 Product Guides", "https://www.seestar.com/products/seestar-s50"))
            }
        }

        if brand.contains("dwarf") || name.contains("dwarf") {
            links.append(("DWARFLAB Smart Telescope User Manuals", "https://help.dwarflab.com/en/docs/DWARF-3-Smart-Telescope-User-Manual-Part1-App-Interface-Introduction"))
        }

        if brand.contains("celestron") || name.contains("origin") {
            links.append(("Celestron Manuals and Software", "https://www.celestron.com/pages/manuals-software"))
        }

        var seenURLs = Set<String>()
        return links.compactMap { title, urlString -> EquipmentGuideLink? in
            guard let url = URL(string: urlString), seenURLs.insert(url.absoluteString).inserted else { return nil }
            return EquipmentGuideLink(title: title, url: url)
        }
    }

    private func makerName(for profile: EquipmentProfile) -> String {
        let maker = trimmedText(profile.brand)
        return maker.isEmpty ? "Unknown" : maker
    }

    private func modelName(for profile: EquipmentProfile) -> String? {
        let model = trimmedText(profile.modelName)
        guard !model.isEmpty, model.localizedCaseInsensitiveCompare(profile.name) != .orderedSame else {
            return nil
        }
        return model
    }

    private func equipmentDetailLines(for profile: EquipmentProfile) -> [String] {
        switch profile.category {
        case .telescope, .smartTelescope:
            var lines = [String]()
            let apertureText = profile.apertureMillimeters > 0 ? "\(Int(profile.apertureMillimeters)) mm aperture" : nil
            let focalText = profile.focalLengthMillimeters > 0 ? "\(Int(profile.focalLengthMillimeters)) mm focal length" : nil
            if let opticalLine = joinedDisplayText([apertureText, focalText]) {
                lines.append("Optics: \(opticalLine)")
            }
            appendDisplayLine("Mount", value: profile.mountDescription, to: &lines)
            appendDisplayLine("Sensor", value: profile.sensorName, to: &lines)
            appendDisplayLine("Integrated", value: profile.integratedComponents, to: &lines)
            appendDisplayLine("Specs", value: profile.specifications, to: &lines)
            return lines
        case .camera:
            return compactDisplayLines([
                ("Sensor", profile.sensorName),
                ("Specs", profile.specifications),
                ("Notes", profile.notes)
            ])
        case .eyepiece:
            let focalText = profile.eyepieceFocalLengthMillimeters.map { "\(formattedMeasurement($0)) mm focal length" }
            let fieldText = profile.apparentFieldOfViewDegrees.map { "\(formattedMeasurement($0)) degree apparent field" }
            var lines = [String]()
            if let opticsLine = joinedDisplayText([focalText, fieldText]) {
                lines.append("Optics: \(opticsLine)")
            }
            appendDisplayLine("Specs", value: profile.specifications, to: &lines)
            appendDisplayLine("Notes", value: profile.notes, to: &lines)
            return lines
        case .filterSystem:
            return compactDisplayLines([
                ("Filter", profile.filterDescription),
                ("Specs", profile.specifications),
                ("Notes", profile.notes)
            ])
        case .mount:
            return compactDisplayLines([
                ("Mount", profile.mountDescription),
                ("Specs", profile.specifications),
                ("Notes", profile.notes)
            ])
        case .accessory, .smartAccessory:
            return compactDisplayLines([
                ("Details", profile.accessoryDetails),
                ("Specs", profile.specifications),
                ("Notes", profile.notes)
            ])
        }
    }

    private func compactDisplayLines(_ fields: [(String, String)]) -> [String] {
        var lines = [String]()
        for field in fields {
            appendDisplayLine(field.0, value: field.1, to: &lines)
        }
        return lines
    }

    private func appendDisplayLine(_ label: String, value: String, to lines: inout [String]) {
        let value = trimmedText(value)
        guard !value.isEmpty else { return }
        lines.append("\(label): \(value)")
    }

    private func joinedDisplayText(_ values: [String?]) -> String? {
        let values = values.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
        return values.isEmpty ? nil : values.joined(separator: " • ")
    }

    private func smartDeviceSupportText(for profile: EquipmentProfile) -> String? {
        guard profile.category == .smartTelescope else { return nil }

        let brand = profile.brand.lowercased()
        let name = profile.name.lowercased()
        if brand.contains("vaonis") {
            return "Devices: iPhone, iPad, iPod touch • iOS/iPadOS 14+"
        }
        if brand.contains("unistellar") {
            return "Devices: iPhone, iPad, iPod touch • iOS/iPadOS 15+"
        }
        if brand.contains("zwo") || name.contains("seestar") {
            return "Devices: iPhone, iPad, iPod touch, Apple Silicon Mac, Apple Vision • iOS/iPadOS 13+"
        }
        if brand.contains("dwarf") {
            return "Devices: iPhone, iPad, iPod touch, Apple Vision • iOS/iPadOS 15+"
        }
        if brand.contains("celestron") || name.contains("origin") {
            return "Devices: iPhone, iPad, Apple Silicon Mac, Apple Vision • iOS/iPadOS 18.6+"
        }
        return "Devices: maker app required • check current iOS/iPadOS support"
    }

    private func typeLabel(for profile: EquipmentProfile) -> String {
        profile.category == .smartTelescope ? "Smart Scope" : profile.category.displayName
    }

    private func typeFillColor(for profile: EquipmentProfile) -> Color {
        if profile.category == .smartTelescope {
            return equipmentCardColor
        }
        return Color.black.opacity(0.08)
    }

    private func typeTextColor(for profile: EquipmentProfile) -> Color {
        if profile.category == .smartTelescope {
            return .white
        }
        return .black.opacity(0.78)
    }

    private func isMeadeEquipment(_ profile: EquipmentProfile) -> Bool {
        let searchableText = [
            profile.brand,
            profile.name,
            profile.modelName,
            profile.specifications,
            profile.notes
        ]
        .joined(separator: " ")
        .lowercased()

        return searchableText.contains("meade")
    }

    private func requiresBrowserProductNotice(_ profile: EquipmentProfile) -> Bool {
        let searchableText = [
            profile.brand,
            profile.name,
            profile.modelName,
            profile.accessoryDetails,
            profile.specifications,
            profile.notes
        ]
        .joined(separator: " ")
        .lowercased()

        return searchableText.contains("affinity")
            || searchableText.contains("ritson")
            || searchableText.contains("photoshop")
            || searchableText.contains("adobe")
    }

    private func formattedMeasurement(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return value.formatted(.number.precision(.fractionLength(1)))
    }

    private func labeledTextField(_ title: String, text: Binding<String>, field: EquipmentFormField) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTypography.body)
                .foregroundStyle(.black.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)

            TextField(title, text: text)
                .textFieldStyle(.plain)
                .foregroundStyle(.black)
                .padding(.horizontal, 8)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(equipmentInputFillColor)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(.black.opacity(0.16), lineWidth: 1)
                )
                .focused($focusedField, equals: field)
                .submitLabel(nextFocusableField(after: field) == nil ? .done : .next)
                .onSubmit {
                    moveFocusForward()
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func labeledNumericField(_ title: String, text: Binding<String>, field: EquipmentFormField) -> some View {
        labeledTextField(title, text: numericBinding(text), field: field)
    }

    private func cardBackground(
        cornerRadius: CGFloat = 30,
        fill: Color = equipmentCardColor
    ) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            )
    }

    private func profiles(for category: EquipmentCategory) -> [EquipmentProfile] {
        let matchingProfiles = equipmentProfiles.filter { $0.category == category }
        if category == .smartAccessory {
            guard let selectedSmartScope = selectedEquipment(for: .smartTelescope) else {
                return []
            }
            return EquipmentCatalogService.sortedProfiles(
                matchingProfiles.filter { smartAccessory($0, isCompatibleWith: selectedSmartScope) }
            )
        }
        return EquipmentCatalogService.sortedProfiles(matchingProfiles)
    }

    private func profiles(for group: EquipmentCatalogGroup) -> [EquipmentProfile] {
        let sorted = EquipmentCatalogService.sortedProfiles(equipmentProfiles.filter { $0.catalogGroup == group })
        let selectedIDs = selectedEquipmentIDsForGroup(group)

        return sorted.sorted { lhs, rhs in
            if let lhsSelectedIndex = selectedIDs.firstIndex(of: lhs.id),
               let rhsSelectedIndex = selectedIDs.firstIndex(of: rhs.id) {
                return lhsSelectedIndex < rhsSelectedIndex
            }
            if selectedIDs.contains(lhs.id) { return true }
            if selectedIDs.contains(rhs.id) { return false }
            if let defaultEquipmentID {
                if lhs.id == defaultEquipmentID { return true }
                if rhs.id == defaultEquipmentID { return false }
            }
            return false
        }
    }

    private func selectedEquipmentListProfiles(for group: EquipmentCatalogGroup) -> [EquipmentProfile] {
        selectedEquipmentIDsForGroup(group).compactMap { selectedID in
            equipmentProfiles.first { $0.id == selectedID && $0.catalogGroup == group }
        }
    }

    private func selectedEquipmentIDsForGroup(_ group: EquipmentCatalogGroup) -> [UUID] {
        let focusedIDs = [focusedEquipmentIDs[group]].compactMap(\.self)
        let primaryIDs = EquipmentCategory.categories(for: group).compactMap { selectedEquipmentIDs[$0] }
        let multiIDs = selectedAdditionalSmartAccessoryIDs
        return orderedUniqueIDs(focusedIDs + primaryIDs + multiIDs)
    }

    private func databaseSelectionKey(for group: EquipmentCatalogGroup) -> String {
        selectedEquipmentIDsForGroup(group)
            .map(\.uuidString)
            .sorted()
            .joined(separator: "|")
    }

    private func selectedEquipmentBinding(for category: EquipmentCategory) -> Binding<UUID?> {
        Binding(
            get: { selectedEquipmentIDs[category] },
            set: { newValue in
                let previousValue = selectedEquipmentIDs[category]
                if let newValue {
                    selectedEquipmentIDs[category] = newValue
                    focusedEquipmentIDs[category.catalogGroup] = newValue
                } else {
                    selectedEquipmentIDs.removeValue(forKey: category)
                    if focusedEquipmentIDs[category.catalogGroup] == previousValue {
                        focusedEquipmentIDs.removeValue(forKey: category.catalogGroup)
                    }
                }
                addMultipleEquipmentSelection(newValue, for: category)
                openSpecialProductNoticeIfNeeded(for: newValue)
                updatePresentedEquipmentSelectionIfNeeded(for: category, selectedID: newValue)
                if category == .smartTelescope {
                    reconcileSmartAccessorySelection()
                }
            }
        )
    }

    private func selectedEquipment(for category: EquipmentCategory) -> EquipmentProfile? {
        guard let selectedID = selectedEquipmentIDs[category] else { return nil }
        return equipmentProfiles.first { $0.id == selectedID && $0.category == category }
    }

    private func focusEquipmentFromList(_ profile: EquipmentProfile) {
        selectedEquipmentIDs[profile.category] = profile.id
        focusedEquipmentIDs[profile.catalogGroup] = profile.id
        addMultipleEquipmentSelection(profile.id, for: profile.category)
        if profile.category == .smartTelescope {
            reconcileSmartAccessorySelection()
        }
        statusBinding(for: profile.catalogGroup).wrappedValue = "Focused \(profile.groupedDisplayName) from the equipment list."
    }

    private func equipmentDropdownSummary(for category: EquipmentCategory) -> String {
        if category == .smartAccessory && selectedEquipment(for: .smartTelescope) == nil {
            return "Select a smart telescope first to show compatible accessories."
        }
        if category.supportsMultipleSelection {
            let selectedProfiles = selectedMultipleEquipmentProfiles(for: category)
            if selectedProfiles.isEmpty {
                return "No \(category.displayName.lowercased()) selected."
            }
            return "\(selectedProfiles.count) selected. Pick another item to add it."
        }
        return selectedEquipment(for: category)?.summary ?? "No \(category.displayName.lowercased()) selected."
    }

    private func selectedMultipleEquipmentIDs(for category: EquipmentCategory) -> [UUID] {
        switch category {
        case .accessory:
            selectedAdditionalAccessoryIDs
        case .smartAccessory:
            selectedAdditionalSmartAccessoryIDs
        default:
            []
        }
    }

    private func setSelectedMultipleEquipmentIDs(_ ids: [UUID], for category: EquipmentCategory) {
        let uniqueIDs = orderedUniqueIDs(ids)
        switch category {
        case .accessory:
            selectedAdditionalAccessoryIDs = uniqueIDs
        case .smartAccessory:
            selectedAdditionalSmartAccessoryIDs = uniqueIDs
        default:
            break
        }
    }

    private func selectedMultipleEquipmentProfiles(for category: EquipmentCategory) -> [EquipmentProfile] {
        selectedMultipleEquipmentIDs(for: category).compactMap { selectedID in
            equipmentProfiles.first { $0.id == selectedID && $0.category == category }
        }
    }

    private func addMultipleEquipmentSelection(_ selectedID: UUID?, for category: EquipmentCategory) {
        guard category.supportsMultipleSelection, let selectedID else { return }
        guard equipmentProfiles.contains(where: { $0.id == selectedID && $0.category == category }) else { return }

        var selectedIDs = selectedMultipleEquipmentIDs(for: category)
        if !selectedIDs.contains(selectedID) {
            selectedIDs.append(selectedID)
            setSelectedMultipleEquipmentIDs(selectedIDs, for: category)
        }
    }

    private func removeMultipleEquipmentSelection(_ selectedID: UUID, for category: EquipmentCategory) {
        let nextIDs = selectedMultipleEquipmentIDs(for: category).filter { $0 != selectedID }
        setSelectedMultipleEquipmentIDs(nextIDs, for: category)
        if selectedEquipmentIDs[category] == selectedID {
            selectedEquipmentIDs.removeValue(forKey: category)
        }
        if focusedEquipmentIDs[category.catalogGroup] == selectedID {
            focusedEquipmentIDs[category.catalogGroup] = nextIDs.first
        }
    }

    private func clearMultipleEquipmentSelections(for category: EquipmentCategory) {
        let clearedIDs = selectedMultipleEquipmentIDs(for: category)
        setSelectedMultipleEquipmentIDs([], for: category)
        selectedEquipmentIDs.removeValue(forKey: category)
        if let focusedID = focusedEquipmentIDs[category.catalogGroup],
           clearedIDs.contains(focusedID) {
            focusedEquipmentIDs.removeValue(forKey: category.catalogGroup)
        }
    }

    private func orderedUniqueIDs(_ ids: [UUID]) -> [UUID] {
        var seenIDs = Set<UUID>()
        return ids.filter { seenIDs.insert($0).inserted }
    }

    private func openSpecialProductNoticeIfNeeded(for selectedID: UUID?) {
        guard
            let selectedID,
            let profile = equipmentProfiles.first(where: { $0.id == selectedID }),
            isMeadeEquipment(profile) || requiresBrowserProductNotice(profile)
        else {
            return
        }

        presentedGuide = nil
        presentedEquipmentProfileID = selectedID
    }

    private func updatePresentedEquipmentSelectionIfNeeded(for category: EquipmentCategory, selectedID: UUID?) {
        guard let presentedEquipmentProfileID,
              let presentedProfile = equipmentProfiles.first(where: { $0.id == presentedEquipmentProfileID }),
              presentedProfile.category == category else {
            return
        }
        self.presentedEquipmentProfileID = selectedID
    }

    private func reconcileSmartAccessorySelection() {
        guard let selectedSmartScope = selectedEquipment(for: .smartTelescope) else {
            selectedEquipmentIDs.removeValue(forKey: .smartAccessory)
            selectedAdditionalSmartAccessoryIDs.removeAll()
            return
        }

        if let selectedAccessory = selectedEquipment(for: .smartAccessory),
           !smartAccessory(selectedAccessory, isCompatibleWith: selectedSmartScope) {
            selectedEquipmentIDs.removeValue(forKey: .smartAccessory)
        }

        selectedAdditionalSmartAccessoryIDs = selectedAdditionalSmartAccessoryIDs.filter { accessoryID in
            guard let accessory = equipmentProfiles.first(where: { $0.id == accessoryID && $0.category == .smartAccessory }) else {
                return false
            }
            return smartAccessory(accessory, isCompatibleWith: selectedSmartScope)
        }

        if let focusedID = focusedEquipmentIDs[.smartTelescope],
           equipmentProfiles.first(where: { $0.id == focusedID })?.category == .smartAccessory,
           selectedEquipmentIDs[.smartAccessory] != focusedID,
           !selectedAdditionalSmartAccessoryIDs.contains(focusedID) {
            focusedEquipmentIDs.removeValue(forKey: .smartTelescope)
        }
    }

    private func smartAccessory(_ accessory: EquipmentProfile, isCompatibleWith smartScope: EquipmentProfile) -> Bool {
        let accessoryText = normalizedCompatibilityText(for: accessory)
        let scopeTokens = smartScopeCompatibilityTokens(for: smartScope)

        if scopeTokens.contains(where: { accessoryText.contains($0) }) {
            return true
        }

        let brandToken = normalizedCompatibilityText(smartScope.brand)
        guard !brandToken.isEmpty, accessoryText.contains(brandToken) else {
            return false
        }

        return !mentionsDifferentSmartScopeFamily(accessoryText, allowedTokens: scopeTokens)
    }

    private func smartScopeCompatibilityTokens(for smartScope: EquipmentProfile) -> [String] {
        let text = normalizedCompatibilityText(for: smartScope)
        let knownFamilies = [
            "seestar s50",
            "seestar s30",
            "vespera",
            "stellina",
            "origin",
            "dwarf",
            "odyssey",
            "evscope",
            "equinox"
        ]

        var tokens = knownFamilies.filter { text.contains($0) }
        tokens.append(normalizedCompatibilityText(smartScope.name))
        tokens.append(normalizedCompatibilityText(smartScope.modelName))
        return Array(Set(tokens.filter { !$0.isEmpty }))
    }

    private func mentionsDifferentSmartScopeFamily(_ text: String, allowedTokens: [String]) -> Bool {
        let knownFamilies = [
            "seestar s50",
            "seestar s30",
            "vespera",
            "stellina",
            "origin",
            "dwarf",
            "odyssey",
            "evscope",
            "equinox"
        ]
        return knownFamilies.contains { text.contains($0) && !allowedTokens.contains($0) }
    }

    private func normalizedCompatibilityText(for profile: EquipmentProfile) -> String {
        normalizedCompatibilityText([
            profile.name,
            profile.brand,
            profile.modelName,
            profile.filterDescription,
            profile.accessoryDetails,
            profile.specifications,
            profile.notes
        ].joined(separator: " "))
    }

    private func normalizedCompatibilityText(_ value: String) -> String {
        value
            .lowercased()
            .replacingOccurrences(of: "-", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func selectedTelescope(for group: EquipmentCatalogGroup) -> EquipmentProfile? {
        switch group {
        case .classic:
            selectedEquipment(for: .telescope)
        case .smartTelescope:
            selectedEquipment(for: .smartTelescope)
        }
    }

    private func defaultEquipment(for group: EquipmentCatalogGroup) -> EquipmentProfile? {
        guard let defaultEquipmentID else { return nil }
        return equipmentProfiles.first { $0.id == defaultEquipmentID && $0.catalogGroup == group }
    }

    private func continueVerificationMessage(for group: EquipmentCatalogGroup) -> String {
        if let defaultEquipment = defaultEquipment(for: group) {
            return "Continue using \(defaultEquipment.groupedDisplayName) as the default equipment for planning?"
        }

        if let selectedTelescope = selectedTelescope(for: group) {
            return "Continue using the selected telescope, \(selectedTelescope.groupedDisplayName), for planning?"
        }

        return "No smart telescope default is set. Continue to the next page anyway?"
    }

    private func beginContinueFlow(for group: EquipmentCatalogGroup, destination: SidebarSection) {
        pendingContinueDestination = destination
        if defaultEquipment(for: .smartTelescope) == nil {
            continuePrompt = .smartNoDefaultWarning
        } else {
            continuePrompt = .verify(group)
        }
    }

    private func cancelContinueFlow() {
        continuePrompt = nil
        pendingContinueDestination = nil
    }

    private func askForTelescopeCaptureStart(for group: EquipmentCatalogGroup) {
        captureStartDate = defaultTelescopeCaptureStartDate()
        continuePrompt = .captureStart(group)
    }

    private func performContinueWithCaptureStart(for group: EquipmentCatalogGroup) {
        runtimeState.pendingTelescopeCaptureStartDate = normalizedToMinute(captureStartDate)
        runtimeState.pendingTelescopeCaptureStartDestinationRawValue = pendingContinueDestination?.rawValue
        performContinue(for: group)
    }

    private func performContinue(for group: EquipmentCatalogGroup) {
        guard let destination = pendingContinueDestination else {
            cancelContinueFlow()
            return
        }

        storeDefaultEquipmentConfigurationIfNeeded(for: group)
        selectedSection = destination
        cancelContinueFlow()
    }

    private func defaultTelescopeCaptureStartDate() -> Date {
        let now = Date()
        if let defaultSiteID = LocationPreferenceStore.reconcileDefaultSiteID(using: sites),
           let defaultSite = sites.first(where: { $0.id == defaultSiteID }),
           let nightStart = SolarHorizonService.sunBelowHorizonEvents(for: defaultSite, on: now).start {
            return normalizedToMinute(nightStart)
        }

        return normalizedToMinute(now)
    }

    private func normalizedToMinute(_ date: Date) -> Date {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute], from: date)
        return Calendar.current.date(from: components) ?? date
    }

    @discardableResult
    private func storeDefaultEquipmentConfigurationIfNeeded(for group: EquipmentCatalogGroup) -> Bool {
        guard let defaultEquipment = defaultEquipment(for: group) else { return false }

        let selectionKey = databaseSelectionKey(for: group)
        let groupRaw = group.rawValue

        do {
            var descriptor = FetchDescriptor<DefaultEquipmentConfiguration>(
                predicate: #Predicate { $0.catalogGroupRaw == groupRaw }
            )
            descriptor.fetchLimit = 1

            if let existing = try modelContext.fetch(descriptor).first {
                existing.defaultEquipmentProfileID = defaultEquipment.id
                existing.selectionKey = selectionKey
                existing.updatedAt = .now
            } else {
                modelContext.insert(
                    DefaultEquipmentConfiguration(
                        catalogGroup: group,
                        updatedAt: .now,
                        defaultEquipmentProfileID: defaultEquipment.id,
                        selectionKey: selectionKey
                    )
                )
            }

            try modelContext.save()
            return true
        } catch {
            statusBinding(for: group).wrappedValue = AppIssueFormatter.persistenceMessage(
                for: "store the default equipment configuration",
                error: error
            )
            return false
        }
    }

    private func canKeepCurrentConfiguration(for group: EquipmentCatalogGroup) -> Bool {
        selectedTelescope(for: group) != nil && !databaseSelectionKey(for: group).isEmpty
    }

    private func keepCurrentConfigurationInDatabase(for group: EquipmentCatalogGroup) {
        guard let primaryEquipment = selectedTelescope(for: group) else {
            statusBinding(for: group).wrappedValue = "Select a telescope before saving a configuration."
            return
        }

        let selectionKey = databaseSelectionKey(for: group)
        guard !selectionKey.isEmpty else {
            statusBinding(for: group).wrappedValue = "Select equipment items before saving a configuration."
            return
        }

        let title = "Smart: \(primaryEquipment.groupedDisplayName)"
        let configurationKey = "\(group.rawValue)|\(selectionKey)"

        do {
            var descriptor = FetchDescriptor<SavedEquipmentConfiguration>(
                predicate: #Predicate { $0.configurationKey == configurationKey }
            )
            descriptor.fetchLimit = 1

            if let existing = try modelContext.fetch(descriptor).first {
                existing.createdAt = .now
                existing.primaryEquipmentProfileID = primaryEquipment.id
                existing.selectionKey = selectionKey
                existing.title = title
            } else {
                modelContext.insert(
                    SavedEquipmentConfiguration(
                        catalogGroup: group,
                        createdAt: .now,
                        primaryEquipmentProfileID: primaryEquipment.id,
                        selectionKey: selectionKey,
                        title: title
                    )
                )
            }

            try modelContext.save()
            statusBinding(for: group).wrappedValue = "Saved this configuration to the database."
        } catch {
            statusBinding(for: group).wrappedValue = AppIssueFormatter.persistenceMessage(
                for: "save this equipment configuration",
                error: error
            )
        }
    }

    private func otherGroup(for group: EquipmentCatalogGroup) -> EquipmentCatalogGroup {
        switch group {
        case .classic:
            return .smartTelescope
        case .smartTelescope:
            return .classic
        }
    }

    private func clearAllEquipmentSelections(reportingFrom reportingGroup: EquipmentCatalogGroup) {
        for group in EquipmentCatalogGroup.allCases {
            clearCard(group, shouldReport: false)
        }
        statusBinding(for: reportingGroup).wrappedValue = "Equipment sidebar cleared."
        statusBinding(for: otherGroup(for: reportingGroup)).wrappedValue = ""
    }

    private func clearCard(_ group: EquipmentCatalogGroup, shouldReport: Bool = true) {
        for category in EquipmentCategory.categories(for: group) {
            selectedEquipmentIDs.removeValue(forKey: category)
        }
        switch group {
        case .classic:
            selectedAdditionalAccessoryIDs.removeAll()
        case .smartTelescope:
            selectedAdditionalSmartAccessoryIDs.removeAll()
        }
        focusedEquipmentIDs.removeValue(forKey: group)
        clearDraft(for: group)
        if shouldReport {
            statusBinding(for: group).wrappedValue = "\(group.displayName) selections cleared."
        }
    }

    private func clearTelescopeSelection(for group: EquipmentCatalogGroup) {
        switch group {
        case .classic:
            if let focusedID = focusedEquipmentIDs[group],
               equipmentProfiles.first(where: { $0.id == focusedID })?.category == .telescope {
                focusedEquipmentIDs.removeValue(forKey: group)
            }
            selectedEquipmentIDs.removeValue(forKey: .telescope)
        case .smartTelescope:
            selectedEquipmentIDs.removeValue(forKey: .smartTelescope)
            selectedEquipmentIDs.removeValue(forKey: .smartAccessory)
            selectedAdditionalSmartAccessoryIDs.removeAll()
            focusedEquipmentIDs.removeValue(forKey: group)
        }
        statusBinding(for: group).wrappedValue = "Telescope selection cleared."
    }

    private func requestDefaultTelescope(for group: EquipmentCatalogGroup) {
        guard let selectedProfile = selectedTelescope(for: group) else {
            statusBinding(for: group).wrappedValue = "Select a telescope first."
            return
        }

        let otherGroup = otherGroup(for: group)
        if let otherSelected = selectedTelescope(for: otherGroup),
           otherSelected.id != selectedProfile.id {
            pendingDefaultConflict = PendingDefaultConflict(selectedProfile: selectedProfile, otherGroup: otherGroup)
            defaultConflictPromptIsVisible = true
            return
        }

        requestDefaultChange(to: selectedProfile, checkOtherCardSelection: false)
    }

    private func requestDefaultChange(
        to profile: EquipmentProfile,
        checkOtherCardSelection: Bool = true
    ) {
        guard profile.isPlanCompatibleDefault else { return }

        if checkOtherCardSelection {
            let otherGroup = otherGroup(for: profile.catalogGroup)
            if let otherSelected = selectedTelescope(for: otherGroup),
               otherSelected.id != profile.id {
                pendingDefaultConflict = PendingDefaultConflict(selectedProfile: profile, otherGroup: otherGroup)
                defaultConflictPromptIsVisible = true
                return
            }
        }

        guard defaultEquipmentID != profile.id else { return }

        if defaultEquipmentID != nil {
            pendingDefaultEquipment = profile
            defaultChangePromptIsVisible = true
        } else {
            applyDefaultEquipment(profile)
        }
    }

    private func applyDefaultEquipment(_ profile: EquipmentProfile) {
        selectedEquipmentIDs[profile.category] = profile.id
        focusedEquipmentIDs[profile.catalogGroup] = profile.id
        if profile.category == .smartTelescope {
            reconcileSmartAccessorySelection()
        }
        setDefaultEquipment(profile.id)
        if storeDefaultEquipmentConfigurationIfNeeded(for: profile.catalogGroup) {
            statusBinding(for: profile.catalogGroup).wrappedValue = "\(profile.groupedDisplayName) is now the default Smart Scope setup."
        }
    }

    private func defaultEquipmentName(for group: EquipmentCatalogGroup) -> String {
        guard
            let defaultEquipmentID,
            let profile = equipmentProfiles.first(where: { $0.id == defaultEquipmentID && $0.catalogGroup == group })
        else {
            return "None"
        }

        return profile.groupedDisplayName
    }

    private func statusBinding(for group: EquipmentCatalogGroup) -> Binding<String> {
        Binding(
            get: { group == .classic ? classicStatusMessage : smartStatusMessage },
            set: { newValue in
                if group == .classic {
                    classicStatusMessage = newValue
                } else {
                    smartStatusMessage = newValue
                }
            }
        )
    }

    private var defaultChangePromptIsPresented: Binding<Bool> {
        Binding(
            get: { defaultChangePromptIsVisible && pendingDefaultEquipment != nil },
            set: { isPresented in
                defaultChangePromptIsVisible = isPresented
            }
        )
    }

    private var defaultConflictPromptIsPresented: Binding<Bool> {
        Binding(
            get: { defaultConflictPromptIsVisible && pendingDefaultConflict != nil },
            set: { isPresented in
                defaultConflictPromptIsVisible = isPresented
            }
        )
    }

    private var deleteConfirmationIsPresented: Binding<Bool> {
        Binding(
            get: { pendingDeleteEquipment != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDeleteEquipment = nil
                }
            }
        )
    }

    private var clearConfirmationIsPresented: Binding<Bool> {
        Binding(
            get: { pendingClearGroup != nil },
            set: { isPresented in
                if !isPresented {
                    pendingClearGroup = nil
                }
            }
        )
    }

    private var presentedEquipmentProfile: EquipmentProfile? {
        guard let presentedEquipmentProfileID else { return nil }
        return equipmentProfiles.first { $0.id == presentedEquipmentProfileID }
    }

    private var equipmentDetailIsPresented: Binding<Bool> {
        Binding(
            get: { presentedEquipmentProfileID != nil },
            set: { isPresented in
                if !isPresented {
                    closeEquipmentDetail()
                }
            }
        )
    }

    private func closeEquipmentDetail() {
        presentedGuide = nil
        presentedEquipmentProfileID = nil
    }

    private func defaultBinding(for profile: EquipmentProfile) -> Binding<Bool> {
        Binding(
            get: { defaultEquipmentID == profile.id },
            set: { isSelected in
                guard isSelected else {
                    if defaultEquipmentID == profile.id {
                        setDefaultEquipment(nil)
                        statusBinding(for: profile.catalogGroup).wrappedValue = "Default equipment cleared."
                    }
                    return
                }
                if defaultEquipmentID != profile.id {
                    requestDefaultChange(to: profile)
                }
            }
        )
    }

    @discardableResult
    private func addEquipment(draft: EquipmentEntryDraft) -> Bool {
        let group = draft.group
        statusBinding(for: group).wrappedValue = ""

        let newProfile = EquipmentProfile(
            name: draft.trimmedName,
            brand: trimmedText(draft.brand),
            modelName: trimmedText(draft.modelName),
            catalogGroup: draft.category.catalogGroup,
            category: draft.category,
            apertureMillimeters: parsedDouble(draft.apertureText) ?? 0,
            focalLengthMillimeters: parsedDouble(draft.focalLengthText) ?? 0,
            eyepieceFocalLengthMillimeters: parsedDouble(draft.eyepieceFocalLengthText),
            apparentFieldOfViewDegrees: parsedDouble(draft.apparentFieldText),
            sensorName: trimmedText(draft.sensorName),
            filterDescription: trimmedText(draft.filterDescription),
            mountDescription: trimmedText(draft.mountDescription),
            integratedComponents: trimmedText(draft.integratedComponents),
            accessoryDetails: trimmedText(draft.accessoryDetails),
            specifications: trimmedText(draft.specifications),
            notes: trimmedText(draft.notes)
        )

        modelContext.insert(newProfile)

        do {
            try modelContext.save()
            statusBinding(for: group).wrappedValue = "Added \(newProfile.groupedDisplayName) to the smart database."
            clearDraft(for: group)
            return true
        } catch {
            statusBinding(for: group).wrappedValue = AppIssueFormatter.persistenceMessage(for: "save the new equipment entry", error: error)
            return false
        }
    }

    private func refreshGroup(_ group: EquipmentCatalogGroup) {
        statusBinding(for: group).wrappedValue = ""
        refreshingGroups.insert(group)
        defer { refreshingGroups.remove(group) }

        do {
            try EquipmentCatalogService.refreshBundledDatabase(context: modelContext, groups: Set([group]))
        } catch {
            statusBinding(for: group).wrappedValue = AppIssueFormatter.persistenceMessage(for: "refresh the equipment database", error: error)
        }
    }

    private func confirmDeleteEquipment(_ profile: EquipmentProfile) {
        let profileName = profile.groupedDisplayName
        let nextDefaultEquipmentID = defaultEquipmentID == profile.id ? nil : defaultEquipmentID
        modelContext.delete(profile)

        do {
            try modelContext.save()
            setDefaultEquipment(nextDefaultEquipmentID)
            statusBinding(for: profile.catalogGroup).wrappedValue = "Deleted \(profileName) from the database."
        } catch {
            statusBinding(for: profile.catalogGroup).wrappedValue = AppIssueFormatter.persistenceMessage(for: "delete the equipment entry", error: error)
        }
    }

    private func syncDefaultSelection() {
        defaultEquipmentID = LocationPreferenceStore.reconcileDefaultEquipmentProfileID(using: equipmentProfiles)
        if let defaultEquipmentID,
           let profile = equipmentProfiles.first(where: { $0.id == defaultEquipmentID }),
           !profile.isPlanCompatibleDefault {
            setDefaultEquipment(nil)
        }
    }

    private func syncSelectedEquipment() {
        let validSelections = Set(equipmentProfiles.map(\.id))
        selectedEquipmentIDs = selectedEquipmentIDs.filter { validSelections.contains($0.value) }
        selectedAdditionalAccessoryIDs = selectedAdditionalAccessoryIDs.filter { validSelections.contains($0) }
        selectedAdditionalSmartAccessoryIDs = selectedAdditionalSmartAccessoryIDs.filter { validSelections.contains($0) }
        focusedEquipmentIDs = focusedEquipmentIDs.filter { validSelections.contains($0.value) }

        if let defaultEquipmentID,
           let defaultProfile = equipmentProfiles.first(where: { $0.id == defaultEquipmentID }) {
            selectedEquipmentIDs[defaultProfile.category] = defaultProfile.id
        }
        reconcileSmartAccessorySelection()
    }

    private func setDefaultEquipment(_ id: UUID?) {
        defaultEquipmentID = id
        LocationPreferenceStore.setDefaultEquipmentProfileID(id)
    }

    private func clearDraft(for group: EquipmentCatalogGroup) {
        if group == .classic {
            classicDraft.reset()
        } else {
            smartDraft.reset()
        }
    }

    private func refreshDateText(for group: EquipmentCatalogGroup) -> String {
        guard let date = EquipmentCatalogService.refreshSnapshot().refreshDate(for: group) else {
            return "Not refreshed yet"
        }
        return date.formatted(date: .abbreviated, time: .shortened)
    }

    private func moveFocusForward() {
        focusedField = nextFocusableField(after: focusedField)
    }

    private func nextFocusableField(after field: EquipmentFormField?) -> EquipmentFormField? {
        let fields: [EquipmentFormField] = [
            .name,
            .brand,
            .model,
            .aperture,
            .focalLength,
            .eyepieceFocalLength,
            .apparentField,
            .sensor,
            .filter,
            .mount,
            .integratedComponents,
            .accessory,
            .specifications,
            .notes
        ]

        guard let field else { return fields.first }
        guard let index = fields.firstIndex(of: field) else { return fields.first }
        let nextIndex = fields.index(after: index)
        return nextIndex < fields.endIndex ? fields[nextIndex] : nil
    }

    private func numericBinding(_ binding: Binding<String>) -> Binding<String> {
        Binding(
            get: { binding.wrappedValue },
            set: { newValue in
                binding.wrappedValue = newValue.filter { "0123456789.".contains($0) }
            }
        )
    }

    private func parsedDouble(_ value: String) -> Double? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        return Double(trimmed)
    }

    private func trimmedText(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
