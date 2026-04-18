import Foundation
import SwiftData

enum DSOType: String, Codable, CaseIterable, Identifiable {
    case galaxy
    case emissionNebula
    case reflectionNebula
    case planetaryNebula
    case openCluster
    case globularCluster
    case darkNebula
    case supernovaRemnant
    case starCloud
    case asterism

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .galaxy: "Galaxy"
        case .emissionNebula: "Emission Nebula"
        case .reflectionNebula: "Reflection Nebula"
        case .planetaryNebula: "Planetary Nebula"
        case .openCluster: "Open Cluster"
        case .globularCluster: "Globular Cluster"
        case .darkNebula: "Dark Nebula"
        case .supernovaRemnant: "Supernova Remnant"
        case .starCloud: "Star Cloud"
        case .asterism: "Asterism"
        }
    }
}

enum CatalogFamily: String, Codable, CaseIterable, Identifiable {
    case messier
    case ngc
    case caldwell
    case ic
    case sharpless2
    case lbn
    case openNGCAddendum

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .messier: "Messier"
        case .ngc: "NGC"
        case .caldwell: "Caldwell"
        case .ic: "IC"
        case .sharpless2: "Sharpless 2"
        case .lbn: "Lynds Bright Nebula"
        case .openNGCAddendum: "OpenNGC Addendum"
        }
    }
}

enum TransientType: String, Codable, CaseIterable, Identifiable {
    case comet
    case asteroid
    case supernova

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .comet: "Comet"
        case .asteroid: "Asteroid"
        case .supernova: "Supernova"
        }
    }
}

enum PlannedTargetStatus: String, Codable, CaseIterable, Identifiable {
    case planned
    case observed
    case skipped

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }
}

enum ObservationEntryStatus: String, Codable, CaseIterable, Identifiable {
    case planned
    case observed
    case skipped
    case cancelled

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }
}

enum SyncState: String, Codable, CaseIterable, Identifiable {
    case draft
    case synced
    case changed
    case removed

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }
}

enum SeeingCondition: String, Codable, CaseIterable, Identifiable {
    case unknown
    case poor
    case fair
    case good
    case excellent

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }
}

enum TransparencyCondition: String, Codable, CaseIterable, Identifiable {
    case unknown
    case poor
    case fair
    case good
    case excellent

    var id: String { rawValue }

    var displayName: String { rawValue.capitalized }
}

@Model
final class DSOObject {
    @Attribute(.unique) var catalogID: String
    var commonName: String
    var primaryDesignation: String
    var catalogFamilyRaw: String
    var alternateDesignations: [String]
    var objectTypeRaw: String
    var constellation: String
    var rightAscensionHours: Double
    var declinationDegrees: Double
    var magnitude: Double
    var angularSizeArcMinutes: Double
    var surfaceBrightness: Double?
    var sourceName: String?
    var sourceURLString: String?
    var locallyRetainedAt: Date?
    var localRetentionReason: String?

    init(
        catalogID: String,
        commonName: String,
        primaryDesignation: String,
        catalogFamily: CatalogFamily,
        alternateDesignations: [String] = [],
        objectType: DSOType,
        constellation: String,
        rightAscensionHours: Double,
        declinationDegrees: Double,
        magnitude: Double,
        angularSizeArcMinutes: Double,
        surfaceBrightness: Double? = nil,
        sourceName: String? = nil,
        sourceURLString: String? = nil,
        locallyRetainedAt: Date? = nil,
        localRetentionReason: String? = nil
    ) {
        self.catalogID = catalogID
        self.commonName = commonName
        self.primaryDesignation = primaryDesignation
        self.catalogFamilyRaw = catalogFamily.rawValue
        self.alternateDesignations = alternateDesignations
        self.objectTypeRaw = objectType.rawValue
        self.constellation = constellation
        self.rightAscensionHours = rightAscensionHours
        self.declinationDegrees = declinationDegrees
        self.magnitude = magnitude
        self.angularSizeArcMinutes = angularSizeArcMinutes
        self.surfaceBrightness = surfaceBrightness
        self.sourceName = sourceName
        self.sourceURLString = sourceURLString
        self.locallyRetainedAt = locallyRetainedAt
        self.localRetentionReason = localRetentionReason
    }

    var objectType: DSOType {
        get { DSOType(rawValue: objectTypeRaw) ?? .galaxy }
        set { objectTypeRaw = newValue.rawValue }
    }

    var catalogFamily: CatalogFamily {
        get { CatalogFamily(rawValue: catalogFamilyRaw) ?? .ngc }
        set { catalogFamilyRaw = newValue.rawValue }
    }

    var displayName: String {
        commonName.isEmpty ? primaryDesignation : "\(primaryDesignation) • \(commonName)"
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

    var brightnessDescription: String {
        "Apparent magnitude \(magnitude.formatted(.number.precision(.fractionLength(1))))"
    }

    var sourceDisplayName: String {
        guard let sourceName, !sourceName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return catalogFamily.displayName
        }

        return sourceName
    }

    var isLocallyRetained: Bool {
        locallyRetainedAt != nil
    }

    var generatedDescription: String {
        let familyText = catalogFamily.displayName.lowercased()
        let typeText = objectType.displayName.lowercased()

        if commonName.isEmpty {
            return "A \(typeText) in \(constellation) listed in the \(familyText) catalog."
        }

        return "\(commonName) is a \(typeText) in \(constellation) listed in the \(familyText) catalog."
    }
}

@Model
final class TransientFeedItem {
    @Attribute(.unique) var id: UUID
    var feedID: String
    var displayName: String
    var transientTypeRaw: String
    var constellation: String
    var rightAscensionHours: Double
    var declinationDegrees: Double
    var magnitude: Double?
    var discoveryDate: Date
    var lastUpdated: Date
    var sourceName: String
    var notes: String
    var locallyRetainedAt: Date?
    var localRetentionReason: String?

    init(
        id: UUID = UUID(),
        feedID: String,
        displayName: String,
        transientType: TransientType,
        constellation: String,
        rightAscensionHours: Double,
        declinationDegrees: Double,
        magnitude: Double? = nil,
        discoveryDate: Date,
        lastUpdated: Date,
        sourceName: String,
        notes: String = "",
        locallyRetainedAt: Date? = nil,
        localRetentionReason: String? = nil
    ) {
        self.id = id
        self.feedID = feedID
        self.displayName = displayName
        self.transientTypeRaw = transientType.rawValue
        self.constellation = constellation
        self.rightAscensionHours = rightAscensionHours
        self.declinationDegrees = declinationDegrees
        self.magnitude = magnitude
        self.discoveryDate = discoveryDate
        self.lastUpdated = lastUpdated
        self.sourceName = sourceName
        self.notes = notes
        self.locallyRetainedAt = locallyRetainedAt
        self.localRetentionReason = localRetentionReason
    }

    var transientType: TransientType {
        get { TransientType(rawValue: transientTypeRaw) ?? .comet }
        set { transientTypeRaw = newValue.rawValue }
    }

    var isLocallyRetained: Bool {
        locallyRetainedAt != nil
    }
}

@Model
final class ObservingSite {
    @Attribute(.unique) var id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var elevationMeters: Double
    var bortleClass: Int
    var formattedAddress: String?
    var countryCode: String?
    var countryName: String?
    var timeZoneIdentifier: String
    var notes: String

    init(
        id: UUID = UUID(),
        name: String,
        latitude: Double,
        longitude: Double,
        elevationMeters: Double = 0,
        bortleClass: Int = 4,
        formattedAddress: String? = nil,
        countryCode: String? = nil,
        countryName: String? = nil,
        timeZoneIdentifier: String = TimeZone.current.identifier,
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.elevationMeters = elevationMeters
        self.bortleClass = bortleClass
        self.formattedAddress = formattedAddress
        self.countryCode = countryCode
        self.countryName = countryName
        self.timeZoneIdentifier = timeZoneIdentifier
        self.notes = notes
    }

    var summary: String {
        "Lat \(latitude.formatted(.number.precision(.fractionLength(2))))°, Lon \(longitude.formatted(.number.precision(.fractionLength(2))))°, Bortle \(bortleClass)"
    }

    var normalizedBortleClass: Int {
        min(max(bortleClass, 1), 9)
    }

    var bortleDescription: String {
        switch normalizedBortleClass {
        case 1: "Excellent dark sky"
        case 2: "Dark rural sky"
        case 3: "Rural sky"
        case 4: "Rural transition"
        case 5: "Suburban sky"
        case 6: "Bright suburban sky"
        case 7: "Suburban urban transition"
        case 8: "City sky"
        case 9: "Inner-city sky"
        default: "Unknown sky quality"
        }
    }

    var bortleSummary: String {
        "Bortle \(normalizedBortleClass) • \(bortleDescription)"
    }
}

enum EquipmentCatalogGroup: String, Codable, CaseIterable, Identifiable {
    case classic
    case smartTelescope

    static var allCases: [EquipmentCatalogGroup] {
        [.smartTelescope]
    }

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .classic: "Legacy Equipment"
        case .smartTelescope: "Smart Telescopes"
        }
    }
}

enum EquipmentCategory: String, Codable, CaseIterable, Identifiable {
    case telescope
    case camera
    case eyepiece
    case filterSystem
    case mount
    case accessory
    case smartTelescope
    case smartAccessory

    static var allCases: [EquipmentCategory] {
        [.smartTelescope, .smartAccessory]
    }

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .telescope: "Telescope"
        case .camera: "Camera"
        case .eyepiece: "Eyepiece"
        case .filterSystem: "Filter System"
        case .mount: "Mount"
        case .accessory: "Other Devices"
        case .smartTelescope: "Smart Telescope"
        case .smartAccessory: "Smart Accessory"
        }
    }

    var supportsMultipleSelection: Bool {
        switch self {
        case .accessory, .smartAccessory:
            true
        default:
            false
        }
    }

    var catalogGroup: EquipmentCatalogGroup {
        switch self {
        case .smartTelescope, .smartAccessory:
            .smartTelescope
        default:
            .classic
        }
    }

    static func categories(for group: EquipmentCatalogGroup) -> [EquipmentCategory] {
        allCases.filter { $0.catalogGroup == group }
    }
}

@Model
final class EquipmentProfile {
    @Attribute(.unique) var id: UUID
    var name: String
    var brand: String
    var modelName: String
    var catalogGroupRaw: String
    var categoryRaw: String
    var apertureMillimeters: Double
    var focalLengthMillimeters: Double
    var eyepieceFocalLengthMillimeters: Double?
    var apparentFieldOfViewDegrees: Double?
    var sensorName: String
    var filterDescription: String
    var mountDescription: String
    var integratedComponents: String
    var accessoryDetails: String
    var specifications: String
    var notes: String

    init(
        id: UUID = UUID(),
        name: String,
        brand: String = "",
        modelName: String = "",
        catalogGroup: EquipmentCatalogGroup = .smartTelescope,
        category: EquipmentCategory = .smartTelescope,
        apertureMillimeters: Double = 0,
        focalLengthMillimeters: Double = 0,
        eyepieceFocalLengthMillimeters: Double? = nil,
        apparentFieldOfViewDegrees: Double? = nil,
        sensorName: String = "",
        filterDescription: String = "",
        mountDescription: String = "",
        integratedComponents: String = "",
        accessoryDetails: String = "",
        specifications: String = "",
        notes: String = ""
    ) {
        self.id = id
        self.name = name
        self.brand = brand
        self.modelName = modelName
        self.catalogGroupRaw = catalogGroup.rawValue
        self.categoryRaw = category.rawValue
        self.apertureMillimeters = apertureMillimeters
        self.focalLengthMillimeters = focalLengthMillimeters
        self.eyepieceFocalLengthMillimeters = eyepieceFocalLengthMillimeters
        self.apparentFieldOfViewDegrees = apparentFieldOfViewDegrees
        self.sensorName = sensorName
        self.filterDescription = filterDescription
        self.mountDescription = mountDescription
        self.integratedComponents = integratedComponents
        self.accessoryDetails = accessoryDetails
        self.specifications = specifications
        self.notes = notes
    }

    var catalogGroup: EquipmentCatalogGroup {
        get { EquipmentCatalogGroup(rawValue: catalogGroupRaw) ?? .smartTelescope }
        set { catalogGroupRaw = newValue.rawValue }
    }

    var category: EquipmentCategory {
        get { EquipmentCategory(rawValue: categoryRaw) ?? .smartTelescope }
        set {
            categoryRaw = newValue.rawValue
            catalogGroupRaw = newValue.catalogGroup.rawValue
        }
    }

    var displayBrandAndModel: String {
        [brand, modelName]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var isPlanCompatibleDefault: Bool {
        category == .smartTelescope
    }

    var summary: String {
        switch category {
        case .telescope, .smartTelescope:
            let apertureText = apertureMillimeters > 0 ? "\(Int(apertureMillimeters)) mm aperture" : nil
            let focalText = focalLengthMillimeters > 0 ? "\(Int(focalLengthMillimeters)) mm focal" : nil
            let componentText = normalizedText(integratedComponents)
            return joinedSummary([apertureText, focalText, componentText])
        case .camera:
            return joinedSummary([normalizedText(sensorName), normalizedText(specifications), normalizedText(notes)])
        case .eyepiece:
            let focalText = eyepieceFocalLengthMillimeters.map { "\(formattedMeasurement($0)) mm" }
            let apparentFieldText = apparentFieldOfViewDegrees.map { "\(formattedMeasurement($0))° AFOV" }
            return joinedSummary([focalText, apparentFieldText, normalizedText(notes)])
        case .filterSystem:
            return joinedSummary([normalizedText(filterDescription), normalizedText(specifications), normalizedText(notes)])
        case .mount:
            return joinedSummary([normalizedText(mountDescription), normalizedText(specifications), normalizedText(notes)])
        case .accessory, .smartAccessory:
            return joinedSummary([normalizedText(accessoryDetails), normalizedText(specifications), normalizedText(notes)])
        }
    }

    var groupedDisplayName: String {
        let brandModel = normalizedText(displayBrandAndModel)
        if let brandModel, brandModel != name {
            return "\(name) • \(brandModel)"
        }
        return name
    }

    private func joinedSummary(_ values: [String?]) -> String {
        let nonEmpty = values.compactMap { $0 }
        if nonEmpty.isEmpty {
            return category.displayName
        }
        return nonEmpty.joined(separator: " • ")
    }

    private func normalizedText(_ value: String) -> String? {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func formattedMeasurement(_ value: Double) -> String {
        if value.rounded() == value {
            return String(Int(value))
        }
        return value.formatted(.number.precision(.fractionLength(1)))
    }
}

@Model
final class DefaultEquipmentConfiguration {
    @Attribute(.unique) var id: UUID
    var catalogGroupRaw: String
    var updatedAt: Date
    var defaultEquipmentProfileID: UUID
    var selectionKey: String

    init(
        id: UUID = UUID(),
        catalogGroup: EquipmentCatalogGroup,
        updatedAt: Date = .now,
        defaultEquipmentProfileID: UUID,
        selectionKey: String
    ) {
        self.id = id
        self.catalogGroupRaw = catalogGroup.rawValue
        self.updatedAt = updatedAt
        self.defaultEquipmentProfileID = defaultEquipmentProfileID
        self.selectionKey = selectionKey
    }

    var catalogGroup: EquipmentCatalogGroup {
        get { EquipmentCatalogGroup(rawValue: catalogGroupRaw) ?? .smartTelescope }
        set { catalogGroupRaw = newValue.rawValue }
    }

    var selectedEquipmentProfileIDs: [UUID] {
        selectionKey
            .split(separator: "|")
            .compactMap { UUID(uuidString: String($0)) }
    }
}

@Model
final class SavedEquipmentConfiguration {
    @Attribute(.unique) var id: UUID
    /// Canonical key used to prevent duplicates: "<group>|<sorted uuid list>".
    @Attribute(.unique) var configurationKey: String
    var catalogGroupRaw: String
    var createdAt: Date
    var primaryEquipmentProfileID: UUID
    var selectionKey: String
    var title: String

    init(
        id: UUID = UUID(),
        catalogGroup: EquipmentCatalogGroup,
        createdAt: Date = .now,
        primaryEquipmentProfileID: UUID,
        selectionKey: String,
        title: String
    ) {
        self.id = id
        self.catalogGroupRaw = catalogGroup.rawValue
        self.createdAt = createdAt
        self.primaryEquipmentProfileID = primaryEquipmentProfileID
        self.selectionKey = selectionKey
        self.title = title
        self.configurationKey = "\(catalogGroup.rawValue)|\(selectionKey)"
    }

    var catalogGroup: EquipmentCatalogGroup {
        get { EquipmentCatalogGroup(rawValue: catalogGroupRaw) ?? .smartTelescope }
        set { catalogGroupRaw = newValue.rawValue }
    }

    var selectedEquipmentProfileIDs: [UUID] {
        selectionKey
            .split(separator: "|")
            .compactMap { UUID(uuidString: String($0)) }
    }
}

@Model
final class SavedTargetList {
    @Attribute(.unique) var id: UUID
    var name: String
    var createdAt: Date
    var defaultSiteID: UUID?
    @Relationship(deleteRule: .cascade, inverse: \SavedTargetListItem.savedList) var items: [SavedTargetListItem]

    init(
        id: UUID = UUID(),
        name: String,
        createdAt: Date = .now,
        defaultSiteID: UUID? = nil,
        items: [SavedTargetListItem] = []
    ) {
        self.id = id
        self.name = name
        self.createdAt = createdAt
        self.defaultSiteID = defaultSiteID
        self.items = items
    }
}

@Model
final class SavedTargetListItem {
    @Attribute(.unique) var id: UUID
    var orderIndex: Int
    var targetID: String
    var identifier: String
    var displayName: String
    var typeName: String
    var constellation: String
    var sourceLabel: String
    var rightAscensionHours: Double
    var declinationDegrees: Double
    var magnitude: Double?
    var savedList: SavedTargetList?

    init(
        id: UUID = UUID(),
        orderIndex: Int,
        targetID: String,
        identifier: String,
        displayName: String,
        typeName: String,
        constellation: String,
        sourceLabel: String,
        rightAscensionHours: Double,
        declinationDegrees: Double,
        magnitude: Double? = nil,
        savedList: SavedTargetList? = nil
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.targetID = targetID
        self.identifier = identifier
        self.displayName = displayName
        self.typeName = typeName
        self.constellation = constellation
        self.sourceLabel = sourceLabel
        self.rightAscensionHours = rightAscensionHours
        self.declinationDegrees = declinationDegrees
        self.magnitude = magnitude
        self.savedList = savedList
    }
}

@Model
final class CampaignPlan {
    @Attribute(.unique) var id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    var notes: String
    var isConfirmed: Bool
    var syncStateRaw: String
    var linkedCampaignLogId: UUID?
    var site: ObservingSite?
    var equipment: EquipmentProfile?
    var sharedTarget: DSOObject?
    @Relationship(deleteRule: .cascade, inverse: \NightPlan.campaignPlan) var nightPlans: [NightPlan]

    init(
        id: UUID = UUID(),
        title: String,
        startDate: Date,
        endDate: Date,
        notes: String = "",
        isConfirmed: Bool = false,
        syncState: SyncState = .draft,
        linkedCampaignLogId: UUID? = nil,
        site: ObservingSite? = nil,
        equipment: EquipmentProfile? = nil,
        sharedTarget: DSOObject? = nil,
        nightPlans: [NightPlan] = []
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.isConfirmed = isConfirmed
        self.syncStateRaw = syncState.rawValue
        self.linkedCampaignLogId = linkedCampaignLogId
        self.site = site
        self.equipment = equipment
        self.sharedTarget = sharedTarget
        self.nightPlans = nightPlans
    }

    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRaw) ?? .draft }
        set { syncStateRaw = newValue.rawValue }
    }
}

@Model
final class NightPlan {
    @Attribute(.unique) var id: UUID
    var title: String
    var observingDate: Date
    var startTime: Date
    var endTime: Date
    var eyepiece: String
    var otherEquipment: String
    var notes: String
    var isConfirmed: Bool
    var syncStateRaw: String
    var linkedNightLogId: UUID?
    var site: ObservingSite?
    var equipment: EquipmentProfile?
    var campaignPlan: CampaignPlan?
    @Relationship(deleteRule: .cascade, inverse: \PlannedTarget.nightPlan) var plannedTargets: [PlannedTarget]

    init(
        id: UUID = UUID(),
        title: String,
        observingDate: Date,
        startTime: Date,
        endTime: Date,
        eyepiece: String = "",
        otherEquipment: String = "",
        notes: String = "",
        isConfirmed: Bool = false,
        syncState: SyncState = .draft,
        linkedNightLogId: UUID? = nil,
        site: ObservingSite? = nil,
        equipment: EquipmentProfile? = nil,
        campaignPlan: CampaignPlan? = nil,
        plannedTargets: [PlannedTarget] = []
    ) {
        self.id = id
        self.title = title
        self.observingDate = observingDate
        self.startTime = startTime
        self.endTime = endTime
        self.eyepiece = eyepiece
        self.otherEquipment = otherEquipment
        self.notes = notes
        self.isConfirmed = isConfirmed
        self.syncStateRaw = syncState.rawValue
        self.linkedNightLogId = linkedNightLogId
        self.site = site
        self.equipment = equipment
        self.campaignPlan = campaignPlan
        self.plannedTargets = plannedTargets
    }

    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRaw) ?? .draft }
        set { syncStateRaw = newValue.rawValue }
    }
}

@Model
final class PlannedTarget {
    @Attribute(.unique) var id: UUID
    var orderIndex: Int
    var plannerScore: Double
    var recommendedStart: Date?
    var recommendedEnd: Date?
    var observationStart: Date?
    var observationEnd: Date?
    var capturedImageCount: Int
    var notes: String
    var statusRaw: String
    var syncStateRaw: String
    var linkedObservationEntryId: UUID?
    var object: DSOObject?
    var nightPlan: NightPlan?

    init(
        id: UUID = UUID(),
        orderIndex: Int,
        plannerScore: Double,
        recommendedStart: Date? = nil,
        recommendedEnd: Date? = nil,
        observationStart: Date? = nil,
        observationEnd: Date? = nil,
        capturedImageCount: Int = 0,
        notes: String = "",
        status: PlannedTargetStatus = .planned,
        syncState: SyncState = .draft,
        linkedObservationEntryId: UUID? = nil,
        object: DSOObject? = nil,
        nightPlan: NightPlan? = nil
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.plannerScore = plannerScore
        self.recommendedStart = recommendedStart
        self.recommendedEnd = recommendedEnd
        self.observationStart = observationStart
        self.observationEnd = observationEnd
        self.capturedImageCount = capturedImageCount
        self.notes = notes
        self.statusRaw = status.rawValue
        self.syncStateRaw = syncState.rawValue
        self.linkedObservationEntryId = linkedObservationEntryId
        self.object = object
        self.nightPlan = nightPlan
    }

    var status: PlannedTargetStatus {
        get { PlannedTargetStatus(rawValue: statusRaw) ?? .planned }
        set { statusRaw = newValue.rawValue }
    }

    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRaw) ?? .draft }
        set { syncStateRaw = newValue.rawValue }
    }
}

@Model
final class CampaignLog {
    @Attribute(.unique) var id: UUID
    var title: String
    var startDate: Date
    var endDate: Date
    var notes: String
    var sourceCampaignPlanId: UUID?
    var syncStateRaw: String
    @Relationship(deleteRule: .cascade, inverse: \NightLog.campaignLog) var nightLogs: [NightLog]

    init(
        id: UUID = UUID(),
        title: String,
        startDate: Date,
        endDate: Date,
        notes: String = "",
        sourceCampaignPlanId: UUID? = nil,
        syncState: SyncState = .draft,
        nightLogs: [NightLog] = []
    ) {
        self.id = id
        self.title = title
        self.startDate = startDate
        self.endDate = endDate
        self.notes = notes
        self.sourceCampaignPlanId = sourceCampaignPlanId
        self.syncStateRaw = syncState.rawValue
        self.nightLogs = nightLogs
    }

    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRaw) ?? .draft }
        set { syncStateRaw = newValue.rawValue }
    }
}

@Model
final class NightLog {
    @Attribute(.unique) var id: UUID
    var title: String
    var observingDate: Date
    var actualStart: Date?
    var actualEnd: Date?
    var summaryNotes: String
    var sourcePlanId: UUID?
    var sourceCampaignPlanId: UUID?
    var syncStateRaw: String
    var siteWasOverridden: Bool
    var equipmentWasOverridden: Bool
    var timeWindowWasOverridden: Bool
    var site: ObservingSite?
    var equipment: EquipmentProfile?
    var campaignLog: CampaignLog?
    @Relationship(deleteRule: .cascade, inverse: \ObservationEntry.nightLog) var observationEntries: [ObservationEntry]

    init(
        id: UUID = UUID(),
        title: String,
        observingDate: Date,
        actualStart: Date? = nil,
        actualEnd: Date? = nil,
        summaryNotes: String = "",
        sourcePlanId: UUID? = nil,
        sourceCampaignPlanId: UUID? = nil,
        syncState: SyncState = .draft,
        siteWasOverridden: Bool = false,
        equipmentWasOverridden: Bool = false,
        timeWindowWasOverridden: Bool = false,
        site: ObservingSite? = nil,
        equipment: EquipmentProfile? = nil,
        campaignLog: CampaignLog? = nil,
        observationEntries: [ObservationEntry] = []
    ) {
        self.id = id
        self.title = title
        self.observingDate = observingDate
        self.actualStart = actualStart
        self.actualEnd = actualEnd
        self.summaryNotes = summaryNotes
        self.sourcePlanId = sourcePlanId
        self.sourceCampaignPlanId = sourceCampaignPlanId
        self.syncStateRaw = syncState.rawValue
        self.siteWasOverridden = siteWasOverridden
        self.equipmentWasOverridden = equipmentWasOverridden
        self.timeWindowWasOverridden = timeWindowWasOverridden
        self.site = site
        self.equipment = equipment
        self.campaignLog = campaignLog
        self.observationEntries = observationEntries
    }

    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRaw) ?? .draft }
        set { syncStateRaw = newValue.rawValue }
    }
}

@Model
final class ObservationEntry {
    @Attribute(.unique) var id: UUID
    var orderIndex: Int
    var loggedAt: Date?
    var observationStart: Date?
    var observationEnd: Date?
    var capturedImageCount: Int
    var notes: String
    var statusRaw: String
    var syncStateRaw: String
    var seeingRaw: String
    var transparencyRaw: String
    var isRemoved: Bool
    var sourcePlannedTargetId: UUID?
    var object: DSOObject?
    var nightLog: NightLog?

    init(
        id: UUID = UUID(),
        orderIndex: Int,
        loggedAt: Date? = nil,
        observationStart: Date? = nil,
        observationEnd: Date? = nil,
        capturedImageCount: Int = 0,
        notes: String = "",
        status: ObservationEntryStatus = .planned,
        syncState: SyncState = .draft,
        seeing: SeeingCondition = .unknown,
        transparency: TransparencyCondition = .unknown,
        isRemoved: Bool = false,
        sourcePlannedTargetId: UUID? = nil,
        object: DSOObject? = nil,
        nightLog: NightLog? = nil
    ) {
        self.id = id
        self.orderIndex = orderIndex
        self.loggedAt = loggedAt
        self.observationStart = observationStart
        self.observationEnd = observationEnd
        self.capturedImageCount = capturedImageCount
        self.notes = notes
        self.statusRaw = status.rawValue
        self.syncStateRaw = syncState.rawValue
        self.seeingRaw = seeing.rawValue
        self.transparencyRaw = transparency.rawValue
        self.isRemoved = isRemoved
        self.sourcePlannedTargetId = sourcePlannedTargetId
        self.object = object
        self.nightLog = nightLog
    }

    var status: ObservationEntryStatus {
        get { ObservationEntryStatus(rawValue: statusRaw) ?? .planned }
        set { statusRaw = newValue.rawValue }
    }

    var syncState: SyncState {
        get { SyncState(rawValue: syncStateRaw) ?? .draft }
        set { syncStateRaw = newValue.rawValue }
    }

    var seeing: SeeingCondition {
        get { SeeingCondition(rawValue: seeingRaw) ?? .unknown }
        set { seeingRaw = newValue.rawValue }
    }

    var transparency: TransparencyCondition {
        get { TransparencyCondition(rawValue: transparencyRaw) ?? .unknown }
        set { transparencyRaw = newValue.rawValue }
    }
}

extension NightPlan {
    var displayTitle: String {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmedTitle.isEmpty ? "Untitled Plan" : trimmedTitle
    }

    var hasLinkedLog: Bool {
        linkedNightLogId != nil || isConfirmed
    }

    var orderedTargets: [PlannedTarget] {
        plannedTargets.sorted { lhs, rhs in
            if lhs.orderIndex == rhs.orderIndex {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.orderIndex < rhs.orderIndex
        }
    }
}

extension NightLog {
    var orderedEntries: [ObservationEntry] {
        observationEntries.sorted { lhs, rhs in
            if lhs.orderIndex == rhs.orderIndex {
                return lhs.id.uuidString < rhs.id.uuidString
            }
            return lhs.orderIndex < rhs.orderIndex
        }
    }
}
