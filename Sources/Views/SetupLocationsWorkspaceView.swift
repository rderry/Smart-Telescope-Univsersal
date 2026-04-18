import SwiftData
import SwiftUI
import CoreLocation

struct SetupLocationsWorkspaceView: View {
    @Environment(AppRuntimeState.self) private var runtimeState
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \ObservingSite.name) private var sites: [ObservingSite]
    @Binding var selectedSection: SidebarSection

    @State private var defaultSiteID: UUID?
    @State private var locationName = ""
    @State private var entryMode: LocationEntryMode = .coordinates
    @State private var latitudeText = ""
    @State private var longitudeText = ""
    @State private var altitudeText = ""
    @State private var altitudeUnit: AltitudeUnit = .meters
    @State private var selectedCountryCode = CountryOption.defaultCode
    @State private var addressLinePrimary = ""
    @State private var addressLineSecondary = ""
    @State private var addressLocality = ""
    @State private var addressRegion = ""
    @State private var addressPostalCode = ""
    @State private var statusMessage = ""
    @State private var resolvedSummary = ""
    @State private var isSaving = false
    @State private var resolvedAltitudeMeters: Double?
    @State private var isResolvingAltitude = false
    @State private var isRequestingCurrentLocation = false
    @State private var pendingDefaultPromptSiteID: UUID?
    @State private var pendingDefaultPromptSiteName = ""
    @State private var pendingDefaultChangeSiteID: UUID?
    @State private var pendingDefaultChangeSiteName = ""
    @State private var pendingDeleteSite: ObservingSite?
    @FocusState private var focusedField: SetupLocationField?

    private let countryOptions = CountryOption.all
    private let locationEntryTextColor = Color(red: 25 / 255, green: 25 / 255, blue: 112 / 255)

    var body: some View {
        ZStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    heroSection

                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 12) {
                            entryCard
                            databaseCard
                                .frame(width: 360)
                        }

                        VStack(alignment: .leading, spacing: 12) {
                            entryCard
                            databaseCard
                        }
                    }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 80)
                .frame(maxWidth: 1180, alignment: .leading)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
        .onAppear {
            syncDefaultSiteSelection()
        }
        .onChange(of: sites.map(\.id)) { _, _ in
            syncDefaultSiteSelection()
        }
        .onChange(of: entryMode) { _, newValue in
            clearResolvedLocationState()
            if newValue == .currentGPS {
                Task {
                    await fillCurrentLocationFromOS()
                }
            }
        }
        .onChange(of: altitudeUnit) { _, _ in
            updateDisplayedAltitudeUnitIfResolved()
        }
        .alert("Set as Default Location?", isPresented: setAsDefaultPromptIsPresented) {
            Button("Yes") {
                if let pendingDefaultPromptSiteID {
                    setDefaultSite(pendingDefaultPromptSiteID)
                    statusMessage = "\(pendingDefaultPromptSiteName) was saved and set as the default location."
                }
                clearPendingDefaultPrompt()
            }

            Button("No", role: .cancel) {
                statusMessage = "\(pendingDefaultPromptSiteName) was saved without changing the current default location."
                clearPendingDefaultPrompt()
            }
        } message: {
            Text("Should \(pendingDefaultPromptSiteName) be set as the default location?")
        }
        .alert("Confirm Deletion", isPresented: deleteConfirmationIsPresented) {
            Button("Delete", role: .destructive) {
                if let pendingDeleteSite {
                    confirmDeleteSite(pendingDeleteSite)
                }
                pendingDeleteSite = nil
            }

            Button("No", role: .cancel) {
                pendingDeleteSite = nil
            }
        } message: {
            Text("Delete \(pendingDeleteSite?.name ?? "this location") from the location database?")
        }
        .alert("Change Default Location?", isPresented: changeDefaultPromptIsPresented) {
            Button("Yes") {
                if let pendingDefaultChangeSiteID {
                    setDefaultSite(pendingDefaultChangeSiteID)
                    statusMessage = "\(pendingDefaultChangeSiteName) is now the default location."
                }
                clearPendingDefaultChangePrompt()
            }

            Button("No", role: .cancel) {
                clearPendingDefaultChangePrompt()
            }
        } message: {
            Text("Are you sure you want to make \(pendingDefaultChangeSiteName) the default location?")
        }
    }

    private var heroSection: some View {
        VStack(alignment: .center, spacing: 9) {
            Text("Setup Locations")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundStyle(Color.yellow)
                .lineLimit(2)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity, alignment: .center)
                .multilineTextAlignment(.center)
                .shadow(color: Color.black.opacity(0.35), radius: 8, y: 2)

            Text("Save observing locations by direct WGS 84 coordinates, the Mac's current GPS location, or country-aware address entry.")
                .font(AppTypography.body)
                .foregroundStyle(.white.opacity(0.92))
                .frame(maxWidth: 760, alignment: .center)
                .multilineTextAlignment(.center)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .center)
        .background(cardBackground(cornerRadius: 32, fill: .regularMaterial))
        .shadow(color: .black.opacity(0.10), radius: 24, y: 12)
    }

    private var entryCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            cardHeading(
                title: "Location Entry",
                subtitle: "Provide decimal latitude and longitude, ask macOS for the current GPS location, or enter a country plus address that will be converted for you."
            )

            TextField("Location Name", text: $locationName)
                .textFieldStyle(.roundedBorder)
                .foregroundStyle(locationEntryTextColor)
                .focused($focusedField, equals: .locationName)
                .submitLabel(.next)
                .onSubmit {
                    moveFocusForward()
                }

            VStack(alignment: .leading, spacing: 8) {
                Text("Location Source")
                    .font(AppTypography.bodyEmphasized)
                    .foregroundStyle(.white.opacity(0.86))

                Picker("Location Source", selection: $entryMode) {
                    ForEach(LocationEntryMode.allCases) { mode in
                        Text(mode.displayName).tag(mode)
                    }
                }
                .pickerStyle(.segmented)
            }

            switch entryMode {
            case .coordinates:
                coordinateEntrySection
            case .currentGPS:
                currentGPSLocationSection
            case .address:
                addressEntrySection
            }

            altitudeSection

            if !resolvedSummary.isEmpty {
                Label(resolvedSummary, systemImage: "location.viewfinder")
                    .font(AppTypography.body)
                    .foregroundStyle(.white.opacity(0.92))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !statusMessage.isEmpty {
                Text(statusMessage)
                    .font(AppTypography.body)
                    .foregroundStyle(.white.opacity(0.90))
                    .fixedSize(horizontal: false, vertical: true)
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    actionButtons
                }

                VStack(alignment: .leading, spacing: 12) {
                    actionButtons
                }
            }
        }
        .focusSection()
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground())
    }

    private var coordinateEntrySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("WGS 84 Coordinates")
                .font(AppTypography.bodyEmphasized)
                .foregroundStyle(.white.opacity(0.86))

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    coordinateField("Decimal Latitude (WGS 84)", text: entryBinding($latitudeText), field: .latitude)
                    coordinateField("Decimal Longitude (WGS 84)", text: entryBinding($longitudeText), field: .longitude)
                }

                VStack(alignment: .leading, spacing: 12) {
                    coordinateField("Decimal Latitude (WGS 84)", text: entryBinding($latitudeText), field: .latitude)
                    coordinateField("Decimal Longitude (WGS 84)", text: entryBinding($longitudeText), field: .longitude)
                }
            }
        }
    }

    private var currentGPSLocationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Current GPS Location")
                .font(AppTypography.bodyEmphasized)
                .foregroundStyle(.white.opacity(0.86))

            Text("macOS will ask for permission, then fill WGS 84 latitude, longitude, and elevation from this Mac's current location.")
                .font(AppTypography.body)
                .foregroundStyle(.white.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)

            Button {
                Task {
                    await fillCurrentLocationFromOS()
                }
            } label: {
                if isRequestingCurrentLocation {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("Get Current Location", systemImage: "location.fill")
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
            .buttonStyle(.bordered)
            .disabled(isRequestingCurrentLocation)

            if let latitude = normalizedDouble(latitudeText),
               let longitude = normalizedDouble(longitudeText) {
                VStack(alignment: .leading, spacing: 6) {
                    Text("GPS Coordinates")
                        .font(AppTypography.body)
                        .foregroundStyle(.white.opacity(0.82))

                    Text("Lat \(formattedCoordinate(latitude)) • Lon \(formattedCoordinate(longitude))")
                        .font(AppTypography.body)
                        .foregroundStyle(.white.opacity(0.92))
                        .fixedSize(horizontal: false, vertical: true)

                    if let altitudeMeters = resolvedAltitudeMeters ?? currentAltitudeMetersFromField {
                        Text("Elevation \(formattedAltitudeSummary(meters: altitudeMeters))")
                            .font(AppTypography.body)
                            .foregroundStyle(.white.opacity(0.92))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private var addressEntrySection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Country and Address")
                .font(AppTypography.bodyEmphasized)
                .foregroundStyle(.white.opacity(0.86))

            VStack(alignment: .leading, spacing: 8) {
                Text("Country")
                    .font(AppTypography.body)
                    .foregroundStyle(.white.opacity(0.82))

                Picker("Country", selection: countrySelectionBinding) {
                    ForEach(countryOptions) { option in
                        Text(option.name).tag(option.code)
                    }
                }
                .pickerStyle(.menu)
                .labelsHidden()
            }

            addressFieldsSection

            Text("If an address is provided, it will be converted to decimal latitude and longitude using WGS 84 before it is added to the location database.")
                .font(AppTypography.body)
                .foregroundStyle(.white.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var addressFieldsSection: some View {
        let schema = selectedCountry.addressSchema

        return VStack(alignment: .leading, spacing: 12) {
            addressComponentField(schema.primaryLineLabel, text: entryBinding($addressLinePrimary), field: .addressPrimary)

            if let secondaryLineLabel = schema.secondaryLineLabel {
                addressComponentField(secondaryLineLabel, text: entryBinding($addressLineSecondary), field: .addressSecondary)
            }

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    addressComponentField(schema.localityLabel, text: entryBinding($addressLocality), field: .addressLocality)
                    addressComponentField(schema.regionLabel, text: entryBinding($addressRegion), field: .addressRegion)
                }

                VStack(alignment: .leading, spacing: 12) {
                    addressComponentField(schema.localityLabel, text: entryBinding($addressLocality), field: .addressLocality)
                    addressComponentField(schema.regionLabel, text: entryBinding($addressRegion), field: .addressRegion)
                }
            }

            addressComponentField(schema.postalCodeLabel, text: entryBinding($addressPostalCode), field: .addressPostalCode)
        }
    }

    private var altitudeSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Elevation")
                .font(AppTypography.bodyEmphasized)
                .foregroundStyle(.white.opacity(0.86))

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .bottom, spacing: 12) {
                    compactAltitudeField
                    altitudeUnitControls
                    if entryMode != .currentGPS {
                        resolveAltitudeButton
                    }
                }

                VStack(alignment: .leading, spacing: 12) {
                    compactAltitudeField
                    altitudeUnitControls
                    if entryMode != .currentGPS {
                        resolveAltitudeButton
                    }
                }
            }

            Text(entryMode == .currentGPS ? "The current GPS request fills this value from macOS location data, then uses terrain elevation from the coordinates if macOS does not provide trusted altitude. You can adjust it before saving." : "Enter a value manually, or use the location information to fill GPS elevation. Choose the unit you want to enter.")
                .font(AppTypography.body)
                .foregroundStyle(.white.opacity(0.82))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var compactAltitudeField: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Elevation")
                .font(AppTypography.body)
                .foregroundStyle(.white.opacity(0.82))

            TextField("0", text: $altitudeText)
                .textFieldStyle(.roundedBorder)
                .foregroundStyle(locationEntryTextColor)
                .frame(width: 96, alignment: .leading)
                .monospacedDigit()
                .multilineTextAlignment(.trailing)
                .focused($focusedField, equals: .altitude)
                .submitLabel(.done)
                .onSubmit {
                    focusedField = nil
                }
        }
        .frame(width: 96, alignment: .leading)
    }

    private var altitudeUnitControls: some View {
        HStack(spacing: 10) {
            Toggle("Meters", isOn: altitudeUnitBinding(for: .meters))
                .toggleStyle(.checkbox)
                .font(AppTypography.body)
                .foregroundStyle(.white.opacity(0.88))

            Toggle("Feet", isOn: altitudeUnitBinding(for: .feet))
                .toggleStyle(.checkbox)
                .font(AppTypography.body)
                .foregroundStyle(.white.opacity(0.88))
        }
    }

    private var resolveAltitudeButton: some View {
        Button {
            Task {
                await fillAltitudeFromEnteredLocation()
            }
        } label: {
            if isResolvingAltitude {
                ProgressView()
                    .controlSize(.small)
            } else {
                Label("Use GPS Elevation", systemImage: "mountain.2")
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .buttonStyle(.bordered)
        .disabled(!canResolveAltitudeSource || isResolvingAltitude)
    }

    private var actionButtons: some View {
        Group {
            Button {
                Task {
                    await addLocationToDatabase()
                }
            } label: {
                if isSaving {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    Label("Add to Location Database", systemImage: "plus.circle.fill")
                        .lineLimit(2)
                        .multilineTextAlignment(.center)
                }
            }
            .disabled(!canSubmit || isSaving)
            .buttonStyle(.borderedProminent)

            Button("Cancel") {
                selectedSection = .home
            }
            .buttonStyle(.bordered)
        }
    }

    private var databaseCard: some View {
        VStack(alignment: .leading, spacing: 16) {
            databaseCardHeader

            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 10) {
                    if sites.isEmpty {
                        Text("No locations have been added yet.")
                            .font(AppTypography.body)
                            .foregroundStyle(.white.opacity(0.86))
                            .padding(.top, 4)
                    } else {
                        ForEach(sortedSites) { site in
                            siteRow(site)
                        }
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(minHeight: 220, maxHeight: 420)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground())
    }

    private var databaseCardHeader: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 12) {
                cardHeading(
                    title: "Location Database",
                    subtitle: "\(sites.count) saved location\(sites.count == 1 ? "" : "s")"
                )

                Spacer(minLength: 0)

                HStack(spacing: 10) {
                    databaseActionButtons
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                cardHeading(
                    title: "Location Database",
                    subtitle: "\(sites.count) saved location\(sites.count == 1 ? "" : "s")"
                )

                HStack(spacing: 10) {
                    databaseActionButtons
                }
            }
        }
    }

    private var databaseActionButtons: some View {
        Group {
            Button("Return to Home") {
                runtimeState.pendingLocationSelectionReturnSectionRawValue = nil
                selectedSection = .home
            }
            .buttonStyle(.bordered)

            Button {
                startSingleNightPlan()
            } label: {
                Label("Start a Plan", systemImage: "arrow.right.circle.fill")
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
            .buttonStyle(.borderedProminent)
            .disabled(defaultSiteID == nil && sites.isEmpty)
        }
    }

    private func siteRow(_ site: ObservingSite) -> some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 6) {
                Text(site.name)
                    .font(AppTypography.bodyStrong)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)

                Text(siteAddressSummary(for: site))
                    .font(AppTypography.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(locationCoordinateSummary(for: site))
                    .font(AppTypography.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text(locationAltitudeSummary(for: site))
                    .font(AppTypography.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                if let countryName = site.countryName, !countryName.isEmpty {
                    Text(countryName)
                        .font(AppTypography.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)

            VStack(alignment: .trailing, spacing: 10) {
                Toggle(selectionModeLabel, isOn: defaultSiteBinding(for: site))
                    .toggleStyle(.checkbox)
                    .font(AppTypography.body)
                    .foregroundStyle(.primary)

                Button(role: .destructive) {
                    pendingDeleteSite = site
                } label: {
                    Label("Delete", systemImage: "trash")
                        .labelStyle(.titleAndIcon)
                }
                .buttonStyle(.borderless)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(cardBackground(cornerRadius: 24, fill: .ultraThinMaterial))
    }

    private func cardHeading(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTypography.bodyEmphasized)
                .foregroundStyle(.white.opacity(0.92))

            Text(subtitle)
                .font(AppTypography.body)
                .foregroundStyle(.white.opacity(0.86))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func coordinateField(_ title: String, text: Binding<String>, field: SetupLocationField) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTypography.body)
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
                .foregroundStyle(locationEntryTextColor)
                .focused($focusedField, equals: field)
                .submitLabel(.next)
                .onSubmit {
                    moveFocusForward()
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func addressComponentField(_ title: String, text: Binding<String>, field: SetupLocationField) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(AppTypography.body)
                .foregroundStyle(.white.opacity(0.82))
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            TextField(title, text: text)
                .textFieldStyle(.roundedBorder)
                .foregroundStyle(locationEntryTextColor)
                .lineLimit(1)
                .focused($focusedField, equals: field)
                .submitLabel(nextFocusableField(after: field) == nil ? .done : .next)
                .onSubmit {
                    moveFocusForward()
                }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func cardBackground(
        cornerRadius: CGFloat = 30,
        fill: Material = .thinMaterial
    ) -> some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .fill(fill)
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(.white.opacity(0.16), lineWidth: 1)
            )
    }

    private var selectedCountry: CountryOption {
        countryOptions.first(where: { $0.code == selectedCountryCode }) ?? .fallback(code: selectedCountryCode)
    }

    private var canSubmit: Bool {
        let nameIsValid = !trimmedLocationName.isEmpty
        let altitudeIsValid = normalizedDouble(altitudeText) != nil || resolvedAltitudeMeters != nil

        switch entryMode {
        case .coordinates:
            return nameIsValid && altitudeIsValid && normalizedDouble(latitudeText) != nil && normalizedDouble(longitudeText) != nil
        case .currentGPS:
            return nameIsValid && altitudeIsValid && normalizedDouble(latitudeText) != nil && normalizedDouble(longitudeText) != nil
        case .address:
            return nameIsValid && altitudeIsValid && !formattedAddressQuery.isEmpty
        }
    }

    private var canResolveAltitudeSource: Bool {
        switch entryMode {
        case .coordinates:
            return normalizedDouble(latitudeText) != nil && normalizedDouble(longitudeText) != nil
        case .currentGPS:
            return normalizedDouble(latitudeText) != nil && normalizedDouble(longitudeText) != nil
        case .address:
            return !formattedAddressQuery.isEmpty
        }
    }

    private var trimmedLocationName: String {
        locationName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var countrySelectionBinding: Binding<String> {
        Binding(
            get: { selectedCountryCode },
            set: { newValue in
                selectedCountryCode = newValue
                clearResolvedLocationState()
            }
        )
    }

    private func entryBinding(_ binding: Binding<String>) -> Binding<String> {
        Binding(
            get: { binding.wrappedValue },
            set: { newValue in
                binding.wrappedValue = newValue
                clearResolvedLocationState()
            }
        )
    }

    private var formattedAddressQuery: String {
        [
            addressLinePrimary,
            addressLineSecondary,
            addressLocality,
            addressRegion,
            addressPostalCode
        ]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: ", ")
    }

    @MainActor
    private func addLocationToDatabase() async {
        statusMessage = ""
        resolvedSummary = ""
        isSaving = true
        defer { isSaving = false }

        guard !trimmedLocationName.isEmpty else {
            statusMessage = "Enter a location name before saving."
            return
        }

        let elevationMeters: Double
        if let rawAltitude = normalizedDouble(altitudeText) {
            elevationMeters = altitudeUnit == .feet ? rawAltitude * 0.3048 : rawAltitude
        } else if let resolvedAltitudeMeters {
            elevationMeters = resolvedAltitudeMeters
        } else {
            statusMessage = "Enter a numeric elevation value before saving."
            return
        }

        switch entryMode {
        case .coordinates:
            await saveCoordinatesLocation(elevationMeters: elevationMeters)
        case .currentGPS:
            await saveCurrentGPSLocation(elevationMeters: elevationMeters)
        case .address:
            await saveAddressLocation(elevationMeters: elevationMeters)
        }
    }

    @MainActor
    private func saveCoordinatesLocation(elevationMeters: Double) async {
        guard let latitude = normalizedDouble(latitudeText), (-90.0 ... 90.0).contains(latitude) else {
            statusMessage = "Enter a valid WGS 84 latitude between -90 and 90."
            return
        }

        guard let longitude = normalizedDouble(longitudeText), (-180.0 ... 180.0).contains(longitude) else {
            statusMessage = "Enter a valid WGS 84 longitude between -180 and 180."
            return
        }

        var resolvedAddress: String?
        var resolvedTimeZoneIdentifier = TimeZone.current.identifier

        do {
            let result = try await LocationGeocodingService.reverseGeocodeCoordinates(latitude: latitude, longitude: longitude)
            resolvedAddress = normalizedText(result.formattedAddress)
            resolvedTimeZoneIdentifier = result.timeZoneIdentifier ?? resolvedTimeZoneIdentifier
        } catch {
            // Keep coordinate entry working even if reverse geocoding is unavailable.
        }

        let site = ObservingSite(
            name: trimmedLocationName,
            latitude: latitude,
            longitude: longitude,
            elevationMeters: elevationMeters,
            formattedAddress: resolvedAddress,
            timeZoneIdentifier: resolvedTimeZoneIdentifier
        )

        modelContext.insert(site)

        do {
            try modelContext.save()
            resolvedSummary = "Saved WGS 84 coordinates • Lat \(formattedCoordinate(latitude)) • Lon \(formattedCoordinate(longitude)) • Elevation \(formattedAltitudeSummary(meters: elevationMeters))"
            if let resolvedAddress {
                statusMessage = "Added \(trimmedLocationName) at \(resolvedAddress)."
            } else {
                statusMessage = "Added \(trimmedLocationName) to the location database."
            }
            presentSetDefaultPrompt(for: site)
            clearForm(keepingCountrySelection: true)
        } catch {
            statusMessage = AppIssueFormatter.persistenceMessage(for: "save the new location", error: error)
        }
    }

    @MainActor
    private func saveCurrentGPSLocation(elevationMeters: Double) async {
        guard let latitude = normalizedDouble(latitudeText), (-90.0 ... 90.0).contains(latitude) else {
            statusMessage = "Ask macOS for the current location before saving."
            return
        }

        guard let longitude = normalizedDouble(longitudeText), (-180.0 ... 180.0).contains(longitude) else {
            statusMessage = "Ask macOS for the current location before saving."
            return
        }

        var resolvedAddress: String?
        var resolvedCountryCode: String?
        var resolvedCountryName: String?
        var resolvedTimeZoneIdentifier = TimeZone.current.identifier

        do {
            let result = try await LocationGeocodingService.reverseGeocodeCoordinates(latitude: latitude, longitude: longitude)
            resolvedAddress = normalizedText(result.formattedAddress)
            resolvedCountryCode = normalizedText(result.countryCode)
            resolvedCountryName = normalizedText(result.countryName)
            resolvedTimeZoneIdentifier = result.timeZoneIdentifier ?? resolvedTimeZoneIdentifier
        } catch {
            // Keep current GPS saves working even if reverse geocoding is unavailable.
        }

        let site = ObservingSite(
            name: trimmedLocationName,
            latitude: latitude,
            longitude: longitude,
            elevationMeters: elevationMeters,
            formattedAddress: resolvedAddress,
            countryCode: resolvedCountryCode,
            countryName: resolvedCountryName,
            timeZoneIdentifier: resolvedTimeZoneIdentifier
        )

        modelContext.insert(site)

        do {
            try modelContext.save()
            resolvedSummary = "Saved current GPS location • Lat \(formattedCoordinate(latitude)) • Lon \(formattedCoordinate(longitude)) • Elevation \(formattedAltitudeSummary(meters: elevationMeters))"
            statusMessage = "Added \(trimmedLocationName) from the current GPS location."
            presentSetDefaultPrompt(for: site)
            clearForm(keepingCountrySelection: true)
        } catch {
            statusMessage = AppIssueFormatter.persistenceMessage(for: "save the current GPS location", error: error)
        }
    }

    @MainActor
    private func saveAddressLocation(elevationMeters: Double) async {
        guard !formattedAddressQuery.isEmpty else {
            statusMessage = "Enter an address before saving the location."
            return
        }

        do {
            let result = try await LocationGeocodingService.geocodeAddress(formattedAddressQuery, country: selectedCountry)
            let site = ObservingSite(
                name: trimmedLocationName,
                latitude: result.latitude,
                longitude: result.longitude,
                elevationMeters: elevationMeters,
                formattedAddress: normalizedText(result.formattedAddress) ?? formattedAddressQuery,
                countryCode: selectedCountry.code,
                countryName: selectedCountry.name,
                timeZoneIdentifier: result.timeZoneIdentifier ?? TimeZone.current.identifier
            )

            modelContext.insert(site)
            try modelContext.save()

            resolvedSummary = "Resolved to WGS 84 • Lat \(formattedCoordinate(result.latitude)) • Lon \(formattedCoordinate(result.longitude)) • Elevation \(formattedAltitudeSummary(meters: elevationMeters))"
            if let formattedAddress = result.formattedAddress, !formattedAddress.isEmpty {
                statusMessage = "Added \(trimmedLocationName) from \(formattedAddress)."
            } else {
                statusMessage = "Added \(trimmedLocationName) to the location database."
            }
            presentSetDefaultPrompt(for: site)
            clearForm(keepingCountrySelection: true)
        } catch {
            statusMessage = AppIssueFormatter.remoteServiceMessage(service: "Location lookup", error: error)
        }
    }

    private func clearForm(keepingCountrySelection: Bool) {
        locationName = ""
        latitudeText = ""
        longitudeText = ""
        altitudeText = ""
        altitudeUnit = .meters
        addressLinePrimary = ""
        addressLineSecondary = ""
        addressLocality = ""
        addressRegion = ""
        addressPostalCode = ""
        entryMode = .coordinates
        resolvedAltitudeMeters = nil
        if !keepingCountrySelection {
            selectedCountryCode = CountryOption.defaultCode
        }
    }

    @MainActor
    private func fillAltitudeFromEnteredLocation() async {
        statusMessage = ""
        isResolvingAltitude = true
        defer { isResolvingAltitude = false }

        do {
            let result: AddressLookupResult
            switch entryMode {
            case .coordinates:
                guard let latitude = normalizedDouble(latitudeText), let longitude = normalizedDouble(longitudeText) else {
                    statusMessage = "Enter valid latitude and longitude before resolving GPS elevation."
                    return
                }
                result = try await LocationGeocodingService.reverseGeocodeCoordinates(latitude: latitude, longitude: longitude)
            case .currentGPS:
                await fillCurrentLocationFromOS()
                return
            case .address:
                guard !formattedAddressQuery.isEmpty else {
                    statusMessage = "Enter the address fields before resolving GPS elevation."
                    return
                }
                result = try await LocationGeocodingService.geocodeAddress(formattedAddressQuery, country: selectedCountry)
            }

            guard let altitudeMeters = await bestAvailableAltitudeMeters(from: result) else {
                statusMessage = "GPS elevation could not be determined from that location. Enter the elevation manually."
                return
            }

            resolvedAltitudeMeters = altitudeMeters
            altitudeUnit = .meters
            altitudeText = formattedAltitudeValue(altitudeMeters)

            resolvedSummary = "Resolved GPS elevation from entered \(entryMode == .coordinates ? "coordinates" : "address") • Elevation field filled in meters • \(formattedAltitudeSummary(meters: altitudeMeters))"
        } catch {
            statusMessage = AppIssueFormatter.remoteServiceMessage(service: "GPS elevation lookup", error: error)
        }
    }

    @MainActor
    private func fillCurrentLocationFromOS() async {
        statusMessage = "Requesting the current location from macOS."
        isRequestingCurrentLocation = true
        defer { isRequestingCurrentLocation = false }

        do {
            let result = try await CurrentLocationService.requestCurrentLocation()
            latitudeText = formattedCoordinate(result.latitude)
            longitudeText = formattedCoordinate(result.longitude)

            if let altitudeMeters = result.altitudeMeters {
                resolvedAltitudeMeters = altitudeMeters
                altitudeUnit = .meters
                altitudeText = formattedAltitudeValue(altitudeMeters)
            } else {
                resolvedAltitudeMeters = nil
                altitudeText = ""
            }

            if trimmedLocationName.isEmpty {
                locationName = suggestedCurrentLocationName(from: result)
            }

            let altitudeSummary = result.altitudeMeters.map {
                " • Elevation \(formattedAltitudeSummary(meters: $0))"
            } ?? " • Elevation unavailable"
            let accuracySummary = result.verticalAccuracyMeters.map {
                " • Vertical accuracy \(formattedAltitudeValue($0)) m"
            } ?? ""
            let sourceSummary = result.altitudeSource.map {
                switch $0 {
                case .gps:
                    " • Source GPS altitude"
                case .terrainLookup:
                    " • Source terrain elevation"
                }
            } ?? ""

            resolvedSummary = "Current GPS location • Lat \(formattedCoordinate(result.latitude)) • Lon \(formattedCoordinate(result.longitude))\(altitudeSummary)\(accuracySummary)\(sourceSummary)"

            if let formattedAddress = normalizedText(result.formattedAddress) {
                statusMessage = "macOS provided the current location at \(formattedAddress)."
            } else {
                statusMessage = "macOS provided the current GPS coordinates."
            }
        } catch {
            statusMessage = "Current location unavailable: \(error.localizedDescription)"
        }
    }

    @MainActor
    private func bestAvailableAltitudeMeters(from result: AddressLookupResult) async -> Double? {
        if let directAltitude = normalizedAltitude(result.altitudeMeters) {
            return directAltitude
        }

        if let terrainElevation = try? await ElevationLookupService.elevationMeters(
            latitude: result.latitude,
            longitude: result.longitude
        ) {
            return terrainElevation
        }

        return nil
    }

    private func startSingleNightPlan() {
        runtimeState.pendingLocationSelectionReturnSectionRawValue = nil
        selectedSection = .planObservation
    }

    private func clearResolvedLocationState() {
        resolvedAltitudeMeters = nil
        resolvedSummary = ""
    }

    private func defaultSiteBinding(for site: ObservingSite) -> Binding<Bool> {
        Binding(
            get: {
                if isSelectingLocationForReturn {
                    return false
                }
                return defaultSiteID == site.id
            },
            set: { isSelected in
                guard isSelected else {
                    if !isSelectingLocationForReturn, defaultSiteID == site.id {
                        setDefaultSite(nil)
                    }
                    return
                }

                if let returnSection = selectionReturnSection {
                    setDefaultSite(site.id)
                    runtimeState.pendingLocationSelectionReturnSectionRawValue = nil
                    selectedSection = returnSection
                } else if defaultSiteID != site.id {
                    pendingDefaultChangeSiteID = site.id
                    pendingDefaultChangeSiteName = site.name
                }
            }
        )
    }

    private var selectionReturnSection: SidebarSection? {
        guard let rawValue = runtimeState.pendingLocationSelectionReturnSectionRawValue else {
            return nil
        }
        return SidebarSection(rawValue: rawValue)
    }

    private var isSelectingLocationForReturn: Bool {
        selectionReturnSection != nil
    }

    private var selectionModeLabel: String {
        isSelectingLocationForReturn ? "Use This Location" : "Select as Default"
    }

    private var setAsDefaultPromptIsPresented: Binding<Bool> {
        Binding(
            get: { pendingDefaultPromptSiteID != nil },
            set: { isPresented in
                if !isPresented {
                    clearPendingDefaultPrompt()
                }
            }
        )
    }

    private var deleteConfirmationIsPresented: Binding<Bool> {
        Binding(
            get: { pendingDeleteSite != nil },
            set: { isPresented in
                if !isPresented {
                    pendingDeleteSite = nil
                }
            }
        )
    }

    private var changeDefaultPromptIsPresented: Binding<Bool> {
        Binding(
            get: { pendingDefaultChangeSiteID != nil },
            set: { isPresented in
                if !isPresented {
                    clearPendingDefaultChangePrompt()
                }
            }
        )
    }

    private func setDefaultSite(_ id: UUID?) {
        defaultSiteID = id
        LocationPreferenceStore.setDefaultSiteID(id)
    }

    private func syncDefaultSiteSelection() {
        defaultSiteID = LocationPreferenceStore.reconcileDefaultSiteID(using: sites)
    }

    private func altitudeUnitBinding(for unit: AltitudeUnit) -> Binding<Bool> {
        Binding(
            get: { altitudeUnit == unit },
            set: { isSelected in
                if isSelected {
                    altitudeUnit = unit
                }
            }
        )
    }

    private func updateDisplayedAltitudeUnitIfResolved() {
        guard let resolvedAltitudeMeters else { return }
        altitudeText = altitudeUnit == .feet
            ? formattedAltitudeValue(resolvedAltitudeMeters * 3.28084)
            : formattedAltitudeValue(resolvedAltitudeMeters)
    }

    private func moveFocusForward() {
        focusedField = nextFocusableField(after: focusedField)
    }

    private func nextFocusableField(after field: SetupLocationField?) -> SetupLocationField? {
        let order: [SetupLocationField] = switch entryMode {
        case .coordinates:
            [.locationName, .latitude, .longitude, .altitude]
        case .currentGPS:
            [.locationName, .altitude]
        case .address:
            if selectedCountry.addressSchema.secondaryLineLabel == nil {
                [.locationName, .addressPrimary, .addressLocality, .addressRegion, .addressPostalCode, .altitude]
            } else {
                [.locationName, .addressPrimary, .addressSecondary, .addressLocality, .addressRegion, .addressPostalCode, .altitude]
            }
        }

        guard let field else { return order.first }
        guard let index = order.firstIndex(of: field) else { return order.first }
        let nextIndex = order.index(after: index)
        return nextIndex < order.endIndex ? order[nextIndex] : nil
    }

    private func confirmDeleteSite(_ site: ObservingSite) {
        let siteName = site.name
        let nextDefaultSiteID = defaultSiteID == site.id
            ? nil
            : defaultSiteID
        modelContext.delete(site)

        do {
            try modelContext.save()
            setDefaultSite(nextDefaultSiteID)
            statusMessage = "Deleted \(siteName) from the location database."
        } catch {
            statusMessage = AppIssueFormatter.persistenceMessage(for: "delete the location", error: error)
        }
    }

    private func presentSetDefaultPrompt(for site: ObservingSite) {
        pendingDefaultPromptSiteID = site.id
        pendingDefaultPromptSiteName = site.name
    }

    private func clearPendingDefaultPrompt() {
        pendingDefaultPromptSiteID = nil
        pendingDefaultPromptSiteName = ""
    }

    private func clearPendingDefaultChangePrompt() {
        pendingDefaultChangeSiteID = nil
        pendingDefaultChangeSiteName = ""
    }

    private var sortedSites: [ObservingSite] {
        let currentDefaultSite = sites.first(where: { $0.id == defaultSiteID })

        return sites.sorted { lhs, rhs in
            if lhs.id == defaultSiteID { return true }
            if rhs.id == defaultSiteID { return false }

            if let currentDefaultSite {
                let lhsDistance = distanceFromDefault(lhs, defaultSite: currentDefaultSite)
                let rhsDistance = distanceFromDefault(rhs, defaultSite: currentDefaultSite)
                if abs(lhsDistance - rhsDistance) > 1 {
                    return lhsDistance < rhsDistance
                }
            }

            return lhs.name.localizedStandardCompare(rhs.name) == .orderedAscending
        }
    }

    private func distanceFromDefault(_ site: ObservingSite, defaultSite: ObservingSite) -> CLLocationDistance {
        let siteLocation = CLLocation(latitude: site.latitude, longitude: site.longitude)
        let defaultLocation = CLLocation(latitude: defaultSite.latitude, longitude: defaultSite.longitude)
        return siteLocation.distance(from: defaultLocation)
    }

    private func normalizedAltitude(_ altitude: Double?) -> Double? {
        guard let altitude, altitude.isFinite else { return nil }
        guard abs(altitude) > 0.5 else { return nil }
        return altitude
    }

    private var currentAltitudeMetersFromField: Double? {
        guard let altitudeValue = normalizedDouble(altitudeText) else { return nil }
        return altitudeUnit == .feet ? altitudeValue * 0.3048 : altitudeValue
    }

    private func normalizedDouble(_ text: String) -> Double? {
        Double(text.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private func formattedCoordinate(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(5)))
    }

    private func locationCoordinateSummary(for site: ObservingSite) -> String {
        "Lat \(formattedCoordinate(site.latitude)) • Lon \(formattedCoordinate(site.longitude))"
    }

    private func locationAltitudeSummary(for site: ObservingSite) -> String {
        let altitudeFeet = site.elevationMeters * 3.28084
        return "Elevation \(site.elevationMeters.formatted(.number.precision(.fractionLength(0)))) m / \(altitudeFeet.formatted(.number.precision(.fractionLength(0)))) ft"
    }

    private func siteAddressSummary(for site: ObservingSite) -> String {
        if let formattedAddress = normalizedText(site.formattedAddress) {
            return formattedAddress
        }

        if let countryName = normalizedText(site.countryName) {
            return countryName
        }

        return "Address not yet stored for this location."
    }

    private func formattedAltitudeValue(_ value: Double) -> String {
        value.formatted(.number.precision(.fractionLength(0)))
    }

    private func formattedAltitudeSummary(meters: Double) -> String {
        let feet = meters * 3.28084
        return "\(formattedAltitudeValue(meters)) m / \(formattedAltitudeValue(feet)) ft"
    }

    private func suggestedCurrentLocationName(from result: CurrentLocationResult) -> String {
        if let formattedAddress = normalizedText(result.formattedAddress),
           let firstComponent = formattedAddress.components(separatedBy: ",").first {
            let trimmedComponent = firstComponent.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmedComponent.isEmpty {
                return trimmedComponent
            }
        }

        if let countryName = normalizedText(result.countryName) {
            return "Current Location, \(countryName)"
        }

        return "Current GPS Location"
    }

    private func normalizedText(_ text: String?) -> String? {
        guard let text else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}

private enum AltitudeUnit: String, CaseIterable {
    case meters
    case feet

    var displayName: String {
        switch self {
        case .meters:
            "Meters"
        case .feet:
            "Feet"
        }
    }
}

private enum SetupLocationField: Hashable {
    case locationName
    case latitude
    case longitude
    case addressPrimary
    case addressSecondary
    case addressLocality
    case addressRegion
    case addressPostalCode
    case altitude
}

private enum LocationEntryMode: String, CaseIterable, Identifiable {
    case coordinates
    case currentGPS
    case address

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .coordinates:
            "Decimal Latitude / Longitude"
        case .currentGPS:
            "Current GPS Location"
        case .address:
            "Country and Address"
        }
    }
}

struct CountryOption: Identifiable, Hashable {
    let code: String
    let name: String

    var id: String { code }

    static let defaultCode = "US"

    static let all: [CountryOption] = Locale.Region.isoRegions
        .compactMap { region in
            let code = region.identifier
            guard let name = Locale.current.localizedString(forRegionCode: code) else { return nil }
            return CountryOption(code: code, name: name)
        }
        .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }

    static func fallback(code: String) -> CountryOption {
        CountryOption(code: code, name: code)
    }

    var addressSchema: AddressFieldSchema {
        switch code {
        case "US":
            AddressFieldSchema(
                primaryLineLabel: "Street Address",
                secondaryLineLabel: "Apartment or Suite",
                localityLabel: "City",
                regionLabel: "State",
                postalCodeLabel: "ZIP Code"
            )
        case "CA":
            AddressFieldSchema(
                primaryLineLabel: "Street Address",
                secondaryLineLabel: "Unit or Suite",
                localityLabel: "City",
                regionLabel: "Province",
                postalCodeLabel: "Postal Code"
            )
        case "GB":
            AddressFieldSchema(
                primaryLineLabel: "Building and Street",
                secondaryLineLabel: "District or Locality",
                localityLabel: "Town or City",
                regionLabel: "County or Region",
                postalCodeLabel: "Postcode"
            )
        case "AU":
            AddressFieldSchema(
                primaryLineLabel: "Street Address",
                secondaryLineLabel: "Unit or Building",
                localityLabel: "Suburb or City",
                regionLabel: "State or Territory",
                postalCodeLabel: "Postcode"
            )
        case "NZ":
            AddressFieldSchema(
                primaryLineLabel: "Street Address",
                secondaryLineLabel: "Suburb or District",
                localityLabel: "Town or City",
                regionLabel: "Region",
                postalCodeLabel: "Postcode"
            )
        case "JP":
            AddressFieldSchema(
                primaryLineLabel: "Street, Block, Building",
                secondaryLineLabel: "Ward or District",
                localityLabel: "City",
                regionLabel: "Prefecture",
                postalCodeLabel: "Postal Code"
            )
        case "DE", "FR", "NL", "ES", "IT":
            AddressFieldSchema(
                primaryLineLabel: "Street and Number",
                secondaryLineLabel: "Building or Unit",
                localityLabel: "City",
                regionLabel: "Region or Province",
                postalCodeLabel: "Postal Code"
            )
        default:
            AddressFieldSchema(
                primaryLineLabel: "Street Address",
                secondaryLineLabel: "District or Building",
                localityLabel: "City or Locality",
                regionLabel: "Region or State",
                postalCodeLabel: "Postal Code"
            )
        }
    }

    var formatHint: String {
        switch code {
        case "US":
            "Street address\nCity, State ZIP Code\nUnited States"
        case "CA":
            "Street address\nCity Province Postal Code\nCanada"
        case "GB":
            "Building and street\nTown or city\nPostcode\nUnited Kingdom"
        case "AU":
            "Street address\nSuburb State Postcode\nAustralia"
        case "NZ":
            "Street address\nSuburb or city\nPostcode\nNew Zealand"
        case "JP":
            "Prefecture, city, street\nPostal code\nJapan"
        case "DE", "FR", "NL", "ES", "IT":
            "Street and number\nPostal code City\n\(name)"
        default:
            "Street address\nLocality\nRegion / Postal code\n\(name)"
        }
    }
}

struct AddressFieldSchema: Hashable {
    let primaryLineLabel: String
    let secondaryLineLabel: String?
    let localityLabel: String
    let regionLabel: String
    let postalCodeLabel: String
}
