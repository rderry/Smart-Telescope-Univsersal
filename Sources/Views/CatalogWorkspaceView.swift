import SwiftData
import SwiftUI

private enum CatalogScope: String, CaseIterable, Identifiable {
    case all
    case deepSky
    case transients
    case sourceRegistry

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: "All"
        case .deepSky: "Deep Sky"
        case .transients: "Transients"
        case .sourceRegistry: "Sources"
        }
    }
}

struct CatalogWorkspaceView: View {
    @Query(sort: \DSOObject.primaryDesignation) private var objects: [DSOObject]
    @Query(sort: \TransientFeedItem.lastUpdated, order: .reverse) private var transientItems: [TransientFeedItem]
    @Binding var selectedSection: SidebarSection
    @State private var searchText = ""
    @State private var scope: CatalogScope = .all
    @State private var selectedFamily: CatalogFamily?

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 12) {
                Picker("Scope", selection: $scope) {
                    ForEach(CatalogScope.allCases) { scope in
                        Text(scope.title).tag(scope)
                    }
                }
                .pickerStyle(.segmented)

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        familyChip(title: "All Families", isSelected: selectedFamily == nil) {
                            selectedFamily = nil
                        }

                        ForEach(CatalogFamily.allCases) { family in
                            familyChip(title: family.displayName, isSelected: selectedFamily == family) {
                                selectedFamily = family
                                scope = .deepSky
                            }
                        }
                    }
                }

                Text(summaryText)
                    .font(AppTypography.body)
                    .foregroundStyle(.secondary)
            }
            .padding()

            List {
                if scope == .sourceRegistry {
                    sourceRegistrySection
                }

                if scope != .transients && scope != .sourceRegistry {
                    Section("Deep-Sky Catalogs") {
                        ForEach(filteredObjects) { object in
                            VStack(alignment: .leading, spacing: 6) {
                                ViewThatFits(in: .horizontal) {
                                    HStack(alignment: .top, spacing: 12) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(object.displayName)
                                                .font(AppTypography.bodyEmphasized)
                                                .lineLimit(2)
                                                .fixedSize(horizontal: false, vertical: true)
                                            Text(object.catalogFamily.displayName)
                                                .font(AppTypography.body)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                                .fixedSize(horizontal: false, vertical: true)
                                        }
                                        Spacer()
                                        Text(object.objectType.displayName)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(object.displayName)
                                            .font(AppTypography.bodyEmphasized)
                                            .lineLimit(2)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Text(object.catalogFamily.displayName)
                                            .font(AppTypography.body)
                                            .foregroundStyle(.secondary)
                                        Text(object.objectType.displayName)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Text("\(object.constellation) • Mag \(object.magnitude.formatted(.number.precision(.fractionLength(1)))) • Size \(Int(object.angularSizeArcMinutes))′")
                                    .font(AppTypography.body)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)

                                if !object.alternateDesignations.isEmpty {
                                    Text(object.alternateDesignations.joined(separator: " • "))
                                        .font(AppTypography.body)
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(3)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                if scope != .deepSky && scope != .sourceRegistry {
                    Section("Transient Feed") {
                        ForEach(filteredTransients) { item in
                            VStack(alignment: .leading, spacing: 6) {
                                ViewThatFits(in: .horizontal) {
                                    HStack(alignment: .top, spacing: 12) {
                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(item.displayName)
                                                .font(AppTypography.bodyEmphasized)
                                                .lineLimit(2)
                                                .fixedSize(horizontal: false, vertical: true)
                                            Text(item.transientType.displayName)
                                                .font(AppTypography.body)
                                                .foregroundStyle(.secondary)
                                        }
                                        Spacer()
                                        Text(item.sourceName)
                                            .font(AppTypography.body)
                                            .foregroundStyle(.secondary)
                                            .lineLimit(2)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.displayName)
                                            .font(AppTypography.bodyEmphasized)
                                            .lineLimit(2)
                                            .fixedSize(horizontal: false, vertical: true)
                                        Text(item.transientType.displayName)
                                            .font(AppTypography.body)
                                            .foregroundStyle(.secondary)
                                        Text(item.sourceName)
                                            .font(AppTypography.body)
                                            .foregroundStyle(.secondary)
                                    }
                                }

                                Text("\(item.constellation) • RA \(item.rightAscensionHours.formatted(.number.precision(.fractionLength(2))))h • Dec \(item.declinationDegrees.formatted(.number.precision(.fractionLength(1))))°")
                                    .font(AppTypography.body)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)

                                Text("Discovered \(item.discoveryDate.formatted(date: .abbreviated, time: .omitted)) • Updated \(item.lastUpdated.formatted(date: .abbreviated, time: .omitted))")
                                    .font(AppTypography.body)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)

                                if let magnitude = item.magnitude {
                                    Text("Magnitude \(magnitude.formatted(.number.precision(.fractionLength(1))))")
                                        .font(AppTypography.body)
                                        .foregroundStyle(.secondary)
                                }

                                if !item.notes.isEmpty {
                                    Text(item.notes)
                                        .font(AppTypography.body)
                                        .foregroundStyle(.tertiary)
                                        .lineLimit(3)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }
            }
        }
        .navigationTitle("Catalog")
        .searchable(text: $searchText, prompt: "Search Caldwell, IC, Sh2, LBN, comets, supernovae, or source databases")
    }

    private var sourceRegistrySection: some View {
        Section("Database Sources and Local Cache Policy") {
            ForEach(filteredDatabaseSources) { source in
                VStack(alignment: .leading, spacing: 6) {
                    ViewThatFits(in: .horizontal) {
                        HStack(alignment: .top, spacing: 12) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(source.name)
                                    .font(AppTypography.bodyEmphasized)
                                    .lineLimit(2)
                                    .fixedSize(horizontal: false, vertical: true)
                                Text("\(source.provider) • \(source.domain.displayName)")
                                    .font(AppTypography.body)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Link("Source", destination: source.sourceURL)
                                .font(AppTypography.body)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(source.name)
                                .font(AppTypography.bodyEmphasized)
                                .lineLimit(2)
                                .fixedSize(horizontal: false, vertical: true)
                            Text("\(source.provider) • \(source.domain.displayName)")
                                .font(AppTypography.body)
                                .foregroundStyle(.secondary)
                            Link("Open Source", destination: source.sourceURL)
                                .font(AppTypography.body)
                        }
                    }

                    Text(source.scaleDescription)
                        .font(AppTypography.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(source.contentsDescription)
                        .font(AppTypography.body)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(source.accessDescription)
                        .font(AppTypography.body)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(source.appUse)
                        .font(AppTypography.body)
                        .foregroundStyle(.tertiary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.vertical, 4)
            }
        }
    }

    private func familyChip(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(AppTypography.body)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.14))
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .clipShape(Capsule())
                .contentShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private var filteredObjects: [DSOObject] {
        let familyFiltered = objects.filter { object in
            selectedFamily == nil || object.catalogFamily == selectedFamily
        }

        guard !searchText.isEmpty else { return familyFiltered }
        return familyFiltered.filter { object in
            object.catalogID.localizedCaseInsensitiveContains(searchText)
            || object.commonName.localizedCaseInsensitiveContains(searchText)
            || object.primaryDesignation.localizedCaseInsensitiveContains(searchText)
            || object.constellation.localizedCaseInsensitiveContains(searchText)
            || object.catalogFamily.displayName.localizedCaseInsensitiveContains(searchText)
            || object.alternateDesignations.contains(where: { $0.localizedCaseInsensitiveContains(searchText) })
        }
    }

    private var filteredTransients: [TransientFeedItem] {
        guard !searchText.isEmpty else { return transientItems }
        return transientItems.filter { item in
            item.feedID.localizedCaseInsensitiveContains(searchText)
            || item.displayName.localizedCaseInsensitiveContains(searchText)
            || item.constellation.localizedCaseInsensitiveContains(searchText)
            || item.transientType.displayName.localizedCaseInsensitiveContains(searchText)
            || item.sourceName.localizedCaseInsensitiveContains(searchText)
            || item.notes.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var filteredDatabaseSources: [AstronomyDatabaseSource] {
        guard !searchText.isEmpty else { return AstronomyDatabaseSourceService.sources }
        return AstronomyDatabaseSourceService.sources.filter { source in
            source.name.localizedCaseInsensitiveContains(searchText)
            || source.provider.localizedCaseInsensitiveContains(searchText)
            || source.domain.displayName.localizedCaseInsensitiveContains(searchText)
            || source.scaleDescription.localizedCaseInsensitiveContains(searchText)
            || source.contentsDescription.localizedCaseInsensitiveContains(searchText)
            || source.accessDescription.localizedCaseInsensitiveContains(searchText)
            || source.appUse.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var summaryText: String {
        if scope == .sourceRegistry {
            return "\(filteredDatabaseSources.count) source definitions • large catalogs stay remote, selected targets stay local until removed"
        }

        let familyLabel = selectedFamily?.displayName ?? "all families"
        return "\(filteredObjects.count) deep-sky objects across \(familyLabel) • \(filteredTransients.count) transient feed items"
    }
}
