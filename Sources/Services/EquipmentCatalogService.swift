import Foundation
import SwiftData

struct EquipmentSeedRecord {
    let id: UUID
    let name: String
    let brand: String
    let modelName: String
    let category: EquipmentCategory
    let apertureMillimeters: Double
    let focalLengthMillimeters: Double
    let eyepieceFocalLengthMillimeters: Double?
    let apparentFieldOfViewDegrees: Double?
    let sensorName: String
    let filterDescription: String
    let mountDescription: String
    let integratedComponents: String
    let accessoryDetails: String
    let specifications: String
    let notes: String
}

struct EquipmentRefreshSnapshot {
    let smartLastRefresh: Date?

    func refreshDate(for group: EquipmentCatalogGroup) -> Date? {
        switch group {
        case .classic:
            nil
        case .smartTelescope:
            smartLastRefresh
        }
    }
}

@MainActor
enum EquipmentCatalogService {
    private static let smartRefreshKey = "equipment_refresh.smart_last_success"
    private static let bundledSeedVersionKey = "equipment_refresh.bundled_seed_version"
    private static let initialInstallDateKey = "app.initial_install_date"
    private static let bundledSeedVersion = 11

    static func bootstrapIfNeeded(context: ModelContext) throws {
        try removeClassicEquipmentData(context: context)

        let smartEquipmentCount = try context.fetch(FetchDescriptor<EquipmentProfile>())
            .filter { $0.catalogGroup == .smartTelescope }
            .count
        if smartEquipmentCount == 0 {
            try applyRecords(bundledSeedRecords(), context: context)
            let initialInstallDate = initialInstallDate()
            stampRefreshDate(initialInstallDate, for: .smartTelescope)
            UserDefaults.standard.set(bundledSeedVersion, forKey: bundledSeedVersionKey)
            return
        }

        guard UserDefaults.standard.integer(forKey: bundledSeedVersionKey) < bundledSeedVersion else { return }
        try applyRecords(bundledSeedRecords(), context: context)
        UserDefaults.standard.set(bundledSeedVersion, forKey: bundledSeedVersionKey)
    }

    static func refreshBundledDatabase(
        context: ModelContext,
        groups: Set<EquipmentCatalogGroup>,
        now: Date = .now
    ) throws {
        let selectedRecords = bundledSeedRecords().filter { groups.contains($0.category.catalogGroup) }
        try applyRecords(selectedRecords, context: context)
        for group in groups {
            stampRefreshDate(now, for: group)
        }
    }

    static func refreshSnapshot(defaults: UserDefaults = .standard) -> EquipmentRefreshSnapshot {
        EquipmentRefreshSnapshot(
            smartLastRefresh: defaults.object(forKey: smartRefreshKey) as? Date
        )
    }

    private static func telescopeSeedRecord(
        id: String,
        name: String,
        brand: String,
        modelName: String,
        apertureMillimeters: Double,
        focalLengthMillimeters: Double,
        mountDescription: String,
        specifications: String,
        notes: String
    ) -> EquipmentSeedRecord {
        EquipmentSeedRecord(
            id: UUID(uuidString: id)!,
            name: name,
            brand: brand,
            modelName: modelName,
            category: .telescope,
            apertureMillimeters: apertureMillimeters,
            focalLengthMillimeters: focalLengthMillimeters,
            eyepieceFocalLengthMillimeters: nil,
            apparentFieldOfViewDegrees: nil,
            sensorName: "",
            filterDescription: "",
            mountDescription: mountDescription,
            integratedComponents: "",
            accessoryDetails: "",
            specifications: specifications,
            notes: notes
        )
    }

    private static func classicSeedRecord(
        id: String,
        name: String,
        brand: String,
        modelName: String,
        category: EquipmentCategory,
        eyepieceFocalLengthMillimeters: Double? = nil,
        apparentFieldOfViewDegrees: Double? = nil,
        sensorName: String = "",
        filterDescription: String = "",
        mountDescription: String = "",
        accessoryDetails: String = "",
        specifications: String,
        notes: String
    ) -> EquipmentSeedRecord {
        EquipmentSeedRecord(
            id: UUID(uuidString: id)!,
            name: name,
            brand: brand,
            modelName: modelName,
            category: category,
            apertureMillimeters: 0,
            focalLengthMillimeters: 0,
            eyepieceFocalLengthMillimeters: eyepieceFocalLengthMillimeters,
            apparentFieldOfViewDegrees: apparentFieldOfViewDegrees,
            sensorName: sensorName,
            filterDescription: filterDescription,
            mountDescription: mountDescription,
            integratedComponents: "",
            accessoryDetails: accessoryDetails,
            specifications: specifications,
            notes: notes
        )
    }

    private static func smartSeedRecord(
        id: String,
        name: String,
        brand: String,
        modelName: String,
        category: EquipmentCategory = .smartTelescope,
        apertureMillimeters: Double = 0,
        focalLengthMillimeters: Double = 0,
        sensorName: String = "",
        filterDescription: String = "",
        mountDescription: String = "",
        integratedComponents: String = "",
        accessoryDetails: String = "",
        specifications: String,
        notes: String
    ) -> EquipmentSeedRecord {
        EquipmentSeedRecord(
            id: UUID(uuidString: id)!,
            name: name,
            brand: brand,
            modelName: modelName,
            category: category,
            apertureMillimeters: apertureMillimeters,
            focalLengthMillimeters: focalLengthMillimeters,
            eyepieceFocalLengthMillimeters: nil,
            apparentFieldOfViewDegrees: nil,
            sensorName: sensorName,
            filterDescription: filterDescription,
            mountDescription: mountDescription,
            integratedComponents: integratedComponents,
            accessoryDetails: accessoryDetails,
            specifications: specifications,
            notes: notes
        )
    }

    static func bundledSeedRecords() -> [EquipmentSeedRecord] {
        [
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0001")!,
                name: "Apertura AD8",
                brand: "Apertura",
                modelName: "AD8 Dobsonian",
                category: .telescope,
                apertureMillimeters: 203,
                focalLengthMillimeters: 1200,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "",
                filterDescription: "",
                mountDescription: "Dobsonian",
                integratedComponents: "",
                accessoryDetails: "",
                specifications: "8 in Newtonian reflector",
                notes: "General-purpose deep-sky visual scope."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0002")!,
                name: "Sky-Watcher Evostar 80ED",
                brand: "Sky-Watcher",
                modelName: "Evostar 80ED",
                category: .telescope,
                apertureMillimeters: 80,
                focalLengthMillimeters: 600,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "",
                filterDescription: "",
                mountDescription: "Refractor OTA",
                integratedComponents: "",
                accessoryDetails: "",
                specifications: "ED apochromatic refractor",
                notes: "Compact refractor for imaging and visual use."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0011")!,
                name: "NexStar Evolution 8",
                brand: "Celestron",
                modelName: "NexStar Evolution 8",
                category: .telescope,
                apertureMillimeters: 203.2,
                focalLengthMillimeters: 2032,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "",
                filterDescription: "",
                mountDescription: "Computerized alt-az single fork arm",
                integratedComponents: "",
                accessoryDetails: "",
                specifications: "8 in Schmidt-Cassegrain • f/10 • StarBright XLT",
                notes: "Common GoTo visual and planetary observing system."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0012")!,
                name: "Advanced VX 9.25 EdgeHD",
                brand: "Celestron",
                modelName: "Advanced VX 9.25 EdgeHD",
                category: .telescope,
                apertureMillimeters: 235,
                focalLengthMillimeters: 2350,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "",
                filterDescription: "",
                mountDescription: "Advanced VX equatorial mount",
                integratedComponents: "",
                accessoryDetails: "",
                specifications: "9.25 in EdgeHD Schmidt-Cassegrain • f/10",
                notes: "Higher-aperture EdgeHD system for visual and imaging work."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0016")!,
                name: "AstroMaster 130EQ",
                brand: "Celestron",
                modelName: "AstroMaster 130EQ",
                category: .telescope,
                apertureMillimeters: 130,
                focalLengthMillimeters: 650,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "",
                filterDescription: "",
                mountDescription: "Manual German equatorial mount",
                integratedComponents: "",
                accessoryDetails: "",
                specifications: "Newtonian reflector • f/5",
                notes: "Common consumer reflector for beginner visual observing."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0017")!,
                name: "StarSense Explorer DX 130AZ",
                brand: "Celestron",
                modelName: "StarSense Explorer DX 130AZ",
                category: .telescope,
                apertureMillimeters: 130,
                focalLengthMillimeters: 650,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "",
                filterDescription: "",
                mountDescription: "Manual alt-azimuth mount with app-assisted pointing",
                integratedComponents: "",
                accessoryDetails: "",
                specifications: "Newtonian reflector • f/5",
                notes: "Consumer push-to style telescope using phone-assisted navigation."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0018")!,
                name: "NexStar 6SE",
                brand: "Celestron",
                modelName: "NexStar 6SE",
                category: .telescope,
                apertureMillimeters: 150,
                focalLengthMillimeters: 1500,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "",
                filterDescription: "",
                mountDescription: "Computerized single fork alt-azimuth mount",
                integratedComponents: "",
                accessoryDetails: "",
                specifications: "6 in Schmidt-Cassegrain • f/10",
                notes: "Popular portable GoTo SCT for visual observing and planetary work."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0019")!,
                name: "Classic 200P Dobsonian",
                brand: "Sky-Watcher",
                modelName: "Classic 200P",
                category: .telescope,
                apertureMillimeters: 200,
                focalLengthMillimeters: 1200,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "",
                filterDescription: "",
                mountDescription: "Dobsonian",
                integratedComponents: "",
                accessoryDetails: "",
                specifications: "Newtonian reflector • f/6",
                notes: "Large-aperture visual Dobsonian for deep-sky observing."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0020")!,
                name: "Heritage 150P",
                brand: "Sky-Watcher",
                modelName: "Heritage 150P",
                category: .telescope,
                apertureMillimeters: 150,
                focalLengthMillimeters: 750,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "",
                filterDescription: "",
                mountDescription: "Tabletop Dobsonian",
                integratedComponents: "",
                accessoryDetails: "",
                specifications: "Collapsible Newtonian reflector • f/5",
                notes: "Compact tabletop Dobsonian with good aperture for travel and quick setup."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0021")!,
                name: "SkyMax 180 Pro",
                brand: "Sky-Watcher",
                modelName: "SkyMax 180 Pro",
                category: .telescope,
                apertureMillimeters: 180,
                focalLengthMillimeters: 2700,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "",
                filterDescription: "",
                mountDescription: "Maksutov-Cassegrain OTA",
                integratedComponents: "",
                accessoryDetails: "",
                specifications: "Maksutov-Cassegrain • f/15",
                notes: "Long-focal-length optical tube for lunar and planetary observing."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0022")!,
                name: "Evostar 72ED",
                brand: "Sky-Watcher",
                modelName: "Evostar 72ED",
                category: .telescope,
                apertureMillimeters: 72,
                focalLengthMillimeters: 420,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "",
                filterDescription: "",
                mountDescription: "ED refractor OTA",
                integratedComponents: "",
                accessoryDetails: "",
                specifications: "Doublet ED refractor • f/5.8",
                notes: "Portable wide-field refractor for imaging and travel use."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0023")!,
                name: "RedCat 51",
                brand: "William Optics",
                modelName: "RedCat 51",
                category: .telescope,
                apertureMillimeters: 51,
                focalLengthMillimeters: 250,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "",
                filterDescription: "",
                mountDescription: "Petzval refractor astrograph OTA",
                integratedComponents: "",
                accessoryDetails: "",
                specifications: "51 mm apochromatic Petzval astrograph • f/4.9",
                notes: "Small wide-field imaging refractor for deep-sky astrophotography."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0024")!,
                name: "AT72EDII",
                brand: "Astro-Tech",
                modelName: "AT72EDII",
                category: .telescope,
                apertureMillimeters: 72,
                focalLengthMillimeters: 430,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "",
                filterDescription: "",
                mountDescription: "ED refractor OTA",
                integratedComponents: "",
                accessoryDetails: "",
                specifications: "Doublet ED refractor • f/6",
                notes: "Compact consumer ED refractor for visual observing and imaging."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0025")!,
                name: "ED102 Essential",
                brand: "Explore Scientific",
                modelName: "ED102 Essential Series",
                category: .telescope,
                apertureMillimeters: 102,
                focalLengthMillimeters: 714,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "",
                filterDescription: "",
                mountDescription: "Triplet refractor OTA",
                integratedComponents: "",
                accessoryDetails: "",
                specifications: "Air-spaced ED apochromatic triplet • f/7",
                notes: "Mid-size apochromatic refractor for visual and imaging workflows."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0026")!,
                name: "FSQ-106EDX4",
                brand: "Takahashi",
                modelName: "FSQ-106EDX4",
                category: .telescope,
                apertureMillimeters: 106,
                focalLengthMillimeters: 530,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "",
                filterDescription: "",
                mountDescription: "Quadruplet astrograph OTA",
                integratedComponents: "",
                accessoryDetails: "",
                specifications: "Fluorite quadruplet apochromat • f/5",
                notes: "Premium wide-field imaging refractor."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0027")!,
                name: "NP101is",
                brand: "Tele Vue",
                modelName: "NP101is",
                category: .telescope,
                apertureMillimeters: 101,
                focalLengthMillimeters: 540,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "",
                filterDescription: "",
                mountDescription: "Nagler-Petzval refractor OTA",
                integratedComponents: "",
                accessoryDetails: "",
                specifications: "Four-element apochromatic refractor • f/5.4",
                notes: "Premium wide-field visual and imaging refractor."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0028")!,
                name: "FRA400",
                brand: "Askar",
                modelName: "FRA400",
                category: .telescope,
                apertureMillimeters: 72,
                focalLengthMillimeters: 400,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "",
                filterDescription: "",
                mountDescription: "Quintuplet astrograph OTA",
                integratedComponents: "",
                accessoryDetails: "",
                specifications: "72 mm flat-field refractor astrograph • f/5.6",
                notes: "Wide-field astrograph designed for imaging without an added flattener."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0029")!,
                name: "SVX102T",
                brand: "Stellarvue",
                modelName: "SVX102T",
                category: .telescope,
                apertureMillimeters: 102,
                focalLengthMillimeters: 714,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "",
                filterDescription: "",
                mountDescription: "Triplet refractor OTA",
                integratedComponents: "",
                accessoryDetails: "",
                specifications: "Air-spaced apo triplet refractor • f/7",
                notes: "High-performance lightweight refractor for visual and imaging work."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0030")!,
                name: "Messier AR-102xs",
                brand: "BRESSER",
                modelName: "Messier AR-102xs",
                category: .telescope,
                apertureMillimeters: 102,
                focalLengthMillimeters: 460,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "",
                filterDescription: "",
                mountDescription: "Achromatic refractor OTA",
                integratedComponents: "",
                accessoryDetails: "",
                specifications: "Short-tube achromatic refractor • f/4.5",
                notes: "Fast consumer refractor suited to wide-field viewing."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0031",
                name: "PowerSeeker 127EQ",
                brand: "Celestron",
                modelName: "PowerSeeker 127EQ",
                apertureMillimeters: 127,
                focalLengthMillimeters: 1000,
                mountDescription: "Manual German equatorial mount",
                specifications: "Newtonian reflector • f/7.87",
                notes: "Consumer entry reflector from Celestron's PowerSeeker line."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0032",
                name: "Omni XLT 150",
                brand: "Celestron",
                modelName: "Omni XLT 150",
                apertureMillimeters: 150,
                focalLengthMillimeters: 750,
                mountDescription: "Omni CG-4 German equatorial mount",
                specifications: "Parabolic Newtonian reflector • f/5 • StarBright XLT",
                notes: "Classic manual equatorial reflector for visual observing."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0033",
                name: "EdgeHD 8 OTA",
                brand: "Celestron",
                modelName: "EdgeHD 8 Optical Tube Assembly",
                apertureMillimeters: 203.2,
                focalLengthMillimeters: 2032,
                mountDescription: "EdgeHD optical tube assembly",
                specifications: "8 in EdgeHD Schmidt-Cassegrain • f/10",
                notes: "Flat-field SCT optical tube for visual observing and imaging."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0034",
                name: "RASA 8",
                brand: "Celestron",
                modelName: "8 in Rowe-Ackermann Schmidt Astrograph",
                apertureMillimeters: 203,
                focalLengthMillimeters: 400,
                mountDescription: "Astrograph OTA",
                specifications: "Rowe-Ackermann Schmidt Astrograph • f/2",
                notes: "Fast dedicated imaging optical tube."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0035",
                name: "Classic 150P Dobsonian",
                brand: "Sky-Watcher",
                modelName: "Classic 150P",
                apertureMillimeters: 150,
                focalLengthMillimeters: 1200,
                mountDescription: "Dobsonian",
                specifications: "Newtonian reflector • f/8",
                notes: "Traditional visual Dobsonian from Sky-Watcher's Classic line."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0036",
                name: "Classic 250P Dobsonian",
                brand: "Sky-Watcher",
                modelName: "Classic 250P",
                apertureMillimeters: 250,
                focalLengthMillimeters: 1200,
                mountDescription: "Dobsonian",
                specifications: "Newtonian reflector • f/4.8",
                notes: "Larger visual Dobsonian in the Sky-Watcher Classic series."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0037",
                name: "Heritage 130P",
                brand: "Sky-Watcher",
                modelName: "Heritage 130 Tabletop Dobsonian",
                apertureMillimeters: 130,
                focalLengthMillimeters: 650,
                mountDescription: "Tabletop Dobsonian",
                specifications: "Collapsible Newtonian reflector • f/5",
                notes: "Portable tabletop Dobsonian for wide-field beginner observing."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0038",
                name: "Esprit 100ED",
                brand: "Sky-Watcher",
                modelName: "Esprit 100ED Super APO Triplet",
                apertureMillimeters: 100,
                focalLengthMillimeters: 550,
                mountDescription: "Triplet refractor OTA",
                specifications: "Triplet apochromatic refractor • f/5.5",
                notes: "Premium Sky-Watcher imaging refractor."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0039",
                name: "SkyQuest XT8",
                brand: "Orion Telescopes & Binoculars",
                modelName: "SkyQuest XT8 Classic",
                apertureMillimeters: 203,
                focalLengthMillimeters: 1200,
                mountDescription: "Dobsonian",
                specifications: "Newtonian reflector • legacy Orion model",
                notes: "Legacy Orion Dobsonian; Orion's website went offline after the 2024 shutdown."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0040",
                name: "SkyQuest XT10",
                brand: "Orion Telescopes & Binoculars",
                modelName: "SkyQuest XT10",
                apertureMillimeters: 254,
                focalLengthMillimeters: 1200,
                mountDescription: "Dobsonian",
                specifications: "Newtonian reflector • f/4.7 • legacy Orion model",
                notes: "Legacy high-aperture Orion Dobsonian."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0041",
                name: "StarBlast 4.5",
                brand: "Orion Telescopes & Binoculars",
                modelName: "StarBlast 4.5 Astro Reflector",
                apertureMillimeters: 114,
                focalLengthMillimeters: 450,
                mountDescription: "Tabletop alt-azimuth mount",
                specifications: "Newtonian reflector • f/3.9 • legacy Orion model",
                notes: "Legacy compact wide-field tabletop reflector."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0042",
                name: "ED80T CF",
                brand: "Orion Telescopes & Binoculars",
                modelName: "ED80T CF Triplet Apochromatic Refractor",
                apertureMillimeters: 80,
                focalLengthMillimeters: 480,
                mountDescription: "Triplet refractor OTA",
                specifications: "Carbon-fiber ED apo triplet • f/6 • legacy Orion model",
                notes: "Legacy Orion imaging refractor."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0043",
                name: "ETX125 Observer",
                brand: "Meade",
                modelName: "ETX125 Observer",
                apertureMillimeters: 127,
                focalLengthMillimeters: 1900,
                mountDescription: "Computerized dual-fork mount",
                specifications: "Maksutov-Cassegrain • f/15 • legacy Meade model",
                notes: "Portable Meade GoTo Maksutov for lunar and planetary observing."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0044",
                name: "LX90 8 ACF",
                brand: "Meade",
                modelName: "LX90 8 in ACF",
                apertureMillimeters: 203,
                focalLengthMillimeters: 2034,
                mountDescription: "Computerized dual-fork mount",
                specifications: "Advanced Coma-Free catadioptric • f/10 • legacy Meade model",
                notes: "Classic Meade fork-mounted GoTo system."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0045",
                name: "LX200 8 ACF",
                brand: "Meade",
                modelName: "LX200 8 in ACF",
                apertureMillimeters: 203,
                focalLengthMillimeters: 2034,
                mountDescription: "Computerized dual-fork mount",
                specifications: "Advanced Coma-Free catadioptric • f/10 • legacy Meade model",
                notes: "Premium Meade legacy fork-mounted GoTo telescope."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0046",
                name: "LightBridge 12",
                brand: "Meade",
                modelName: "LightBridge 12 in Dobsonian",
                apertureMillimeters: 305,
                focalLengthMillimeters: 1524,
                mountDescription: "Truss Dobsonian",
                specifications: "Newtonian reflector • f/5 • legacy Meade model",
                notes: "Portable truss-tube Meade Dobsonian."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0047",
                name: "Apertura AD6",
                brand: "Apertura",
                modelName: "AD6 Dobsonian",
                apertureMillimeters: 152.4,
                focalLengthMillimeters: 1200,
                mountDescription: "Dobsonian",
                specifications: "Newtonian reflector • f/7.9",
                notes: "Portable 6 in Apertura Dobsonian."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0048",
                name: "Apertura AD10",
                brand: "Apertura",
                modelName: "AD10 Dobsonian",
                apertureMillimeters: 254,
                focalLengthMillimeters: 1250,
                mountDescription: "Dobsonian",
                specifications: "Newtonian reflector • f/4.9",
                notes: "10 in Apertura AD-series visual Dobsonian."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0049",
                name: "Apertura AD12",
                brand: "Apertura",
                modelName: "AD12 Dobsonian",
                apertureMillimeters: 305,
                focalLengthMillimeters: 1520,
                mountDescription: "Dobsonian",
                specifications: "Newtonian reflector • f/5",
                notes: "Large-aperture Apertura AD-series Dobsonian."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0050",
                name: "ZenithStar 61 II",
                brand: "William Optics",
                modelName: "ZenithStar 61 II",
                apertureMillimeters: 61,
                focalLengthMillimeters: 360,
                mountDescription: "Doublet refractor OTA",
                specifications: "Doublet apochromatic refractor • f/5.9",
                notes: "Compact William Optics wide-field refractor."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0051",
                name: "RedCat 61",
                brand: "William Optics",
                modelName: "Cat 61 WIFD",
                apertureMillimeters: 61,
                focalLengthMillimeters: 300,
                mountDescription: "Petzval refractor astrograph OTA",
                specifications: "4-element Petzval astrograph • f/4.9",
                notes: "William Optics wide-field imaging astrograph."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0052",
                name: "Gran Turismo 81",
                brand: "William Optics",
                modelName: "Gran Turismo 81 WIFD",
                apertureMillimeters: 81,
                focalLengthMillimeters: 478,
                mountDescription: "Triplet refractor OTA",
                specifications: "Triplet apochromatic refractor • f/5.9",
                notes: "Mid-size William Optics imaging refractor."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0053",
                name: "Fluorostar 91",
                brand: "William Optics",
                modelName: "Fluorostar 91",
                apertureMillimeters: 91,
                focalLengthMillimeters: 540,
                mountDescription: "Triplet refractor OTA",
                specifications: "Triplet apochromatic refractor • f/5.9",
                notes: "William Optics premium APO refractor."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0054",
                name: "ED80 Essential",
                brand: "Explore Scientific",
                modelName: "ED80 Essential Series",
                apertureMillimeters: 80,
                focalLengthMillimeters: 480,
                mountDescription: "Triplet refractor OTA",
                specifications: "Air-spaced ED apochromatic triplet • f/6",
                notes: "Grab-and-go Explore Scientific APO refractor."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0055",
                name: "ED127 Essential",
                brand: "Explore Scientific",
                modelName: "ED127 Essential Series",
                apertureMillimeters: 127,
                focalLengthMillimeters: 952,
                mountDescription: "Triplet refractor OTA",
                specifications: "Air-spaced ED apochromatic triplet • f/7.5",
                notes: "Larger Explore Scientific APO refractor for visual and imaging use."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0056",
                name: "FirstLight 10 Dobsonian",
                brand: "Explore Scientific",
                modelName: "FirstLight 10 in Dobsonian",
                apertureMillimeters: 254,
                focalLengthMillimeters: 1270,
                mountDescription: "Dobsonian",
                specifications: "Newtonian reflector • f/5",
                notes: "Explore Scientific visual Dobsonian with removable OTA."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0057",
                name: "Messier 6 in Dobson",
                brand: "BRESSER",
                modelName: "Messier 6 in Dobson",
                apertureMillimeters: 150,
                focalLengthMillimeters: 750,
                mountDescription: "Dobsonian",
                specifications: "Newtonian reflector • f/5",
                notes: "Compact BRESSER Messier Dobsonian."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0058",
                name: "Messier 12 in Dobson",
                brand: "BRESSER",
                modelName: "Messier 12 in Dobson",
                apertureMillimeters: 305,
                focalLengthMillimeters: 1525,
                mountDescription: "Dobsonian",
                specifications: "Newtonian reflector • f/5",
                notes: "Large-aperture BRESSER Messier Dobsonian."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0003")!,
                name: "ASI533MC Pro",
                brand: "ZWO",
                modelName: "ASI533MC Pro",
                category: .camera,
                apertureMillimeters: 0,
                focalLengthMillimeters: 0,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "Sony IMX533 color • 3008 x 3008 max pixels • 9.0 MP • 3.76 um pixels",
                filterDescription: "",
                mountDescription: "",
                integratedComponents: "",
                accessoryDetails: "",
                specifications: "Cooled one-shot color astronomy camera",
                notes: "Popular OSC camera for deep-sky imaging."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0004")!,
                name: "ASI2600MM Pro",
                brand: "ZWO",
                modelName: "ASI2600MM Pro",
                category: .camera,
                apertureMillimeters: 0,
                focalLengthMillimeters: 0,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "Sony IMX571 mono APS-C • 6248 x 4176 max pixels • 26 MP • 3.76 um pixels",
                filterDescription: "",
                mountDescription: "",
                integratedComponents: "",
                accessoryDetails: "",
                specifications: "Cooled monochrome astronomy camera",
                notes: "Common mono camera for narrowband and LRGB work."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0013")!,
                name: "ASI2600MC Pro",
                brand: "ZWO",
                modelName: "ASI2600MC Pro",
                category: .camera,
                apertureMillimeters: 0,
                focalLengthMillimeters: 0,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "Sony IMX571 color APS-C • 6248 x 4176 max pixels • 26 MP • 3.76 um pixels",
                filterDescription: "",
                mountDescription: "",
                integratedComponents: "",
                accessoryDetails: "",
                specifications: "Cooled one-shot color astronomy camera",
                notes: "Large-format OSC camera for deep-sky imaging."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0005")!,
                name: "Nagler 13",
                brand: "Tele Vue",
                modelName: "Nagler 13 mm Type 6",
                category: .eyepiece,
                apertureMillimeters: 0,
                focalLengthMillimeters: 0,
                eyepieceFocalLengthMillimeters: 13,
                apparentFieldOfViewDegrees: 82,
                sensorName: "",
                filterDescription: "",
                mountDescription: "",
                integratedComponents: "",
                accessoryDetails: "",
                specifications: "1.25 in eyepiece",
                notes: "Wide-field premium eyepiece."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0006")!,
                name: "Baader Hyperion 24",
                brand: "Baader",
                modelName: "Hyperion 24 mm",
                category: .eyepiece,
                apertureMillimeters: 0,
                focalLengthMillimeters: 0,
                eyepieceFocalLengthMillimeters: 24,
                apparentFieldOfViewDegrees: 68,
                sensorName: "",
                filterDescription: "",
                mountDescription: "",
                integratedComponents: "",
                accessoryDetails: "",
                specifications: "2 in / 1.25 in modular eyepiece",
                notes: "Versatile medium-power visual eyepiece."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0007")!,
                name: "L-eXtreme",
                brand: "Optolong",
                modelName: "L-eXtreme",
                category: .filterSystem,
                apertureMillimeters: 0,
                focalLengthMillimeters: 0,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "",
                filterDescription: "Dual-band narrowband filter • H-alpha / OIII",
                mountDescription: "",
                integratedComponents: "",
                accessoryDetails: "",
                specifications: "2 in mounted filter",
                notes: "Common filter for emission nebula imaging."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0008")!,
                name: "CLS CCD",
                brand: "Astronomik",
                modelName: "CLS CCD",
                category: .filterSystem,
                apertureMillimeters: 0,
                focalLengthMillimeters: 0,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "",
                filterDescription: "Broadband light-pollution filter",
                mountDescription: "",
                integratedComponents: "",
                accessoryDetails: "",
                specifications: "Clip-in / threaded variants",
                notes: "Useful for moderate urban and suburban imaging."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0009")!,
                name: "EQ6-R Pro",
                brand: "Sky-Watcher",
                modelName: "EQ6-R Pro",
                category: .mount,
                apertureMillimeters: 0,
                focalLengthMillimeters: 0,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "",
                filterDescription: "",
                mountDescription: "GoTo equatorial mount",
                integratedComponents: "",
                accessoryDetails: "",
                specifications: "44 lb payload class",
                notes: "Common deep-sky imaging mount."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0010")!,
                name: "Electronic Focuser",
                brand: "ZWO",
                modelName: "EAF",
                category: .accessory,
                apertureMillimeters: 0,
                focalLengthMillimeters: 0,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "",
                filterDescription: "",
                mountDescription: "",
                integratedComponents: "",
                accessoryDetails: "Motorized focuser",
                specifications: "USB powered focuser motor",
                notes: "Often paired with refractors and SCTs."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0014")!,
                name: "EFW 7 x 2 in",
                brand: "ZWO",
                modelName: "EFW 7 x 2 in",
                category: .accessory,
                apertureMillimeters: 0,
                focalLengthMillimeters: 0,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "",
                filterDescription: "",
                mountDescription: "",
                integratedComponents: "",
                accessoryDetails: "Electronic filter wheel",
                specifications: "Seven 2 in filter positions",
                notes: "Common filter wheel for mono deep-sky imaging rigs."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0015")!,
                name: "AVX Mount",
                brand: "Celestron",
                modelName: "Advanced VX Mount",
                category: .mount,
                apertureMillimeters: 0,
                focalLengthMillimeters: 0,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "",
                filterDescription: "",
                mountDescription: "Computerized German equatorial mount",
                integratedComponents: "",
                accessoryDetails: "",
                specifications: "Advanced VX GoTo mount class",
                notes: "Common portable equatorial mount for small and mid-size systems."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0201",
                name: "Ethos 13",
                brand: "Tele Vue",
                modelName: "Ethos 13 mm",
                category: .eyepiece,
                eyepieceFocalLengthMillimeters: 13,
                apparentFieldOfViewDegrees: 100,
                specifications: "2 in / 1.25 in ultra-wide eyepiece",
                notes: "Premium Tele Vue deep-sky eyepiece."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0202",
                name: "Nagler 31 Type 5",
                brand: "Tele Vue",
                modelName: "Nagler 31 mm Type 5",
                category: .eyepiece,
                eyepieceFocalLengthMillimeters: 31,
                apparentFieldOfViewDegrees: 82,
                specifications: "2 in ultra-wide eyepiece",
                notes: "Large true-field premium eyepiece."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0203",
                name: "Panoptic 24",
                brand: "Tele Vue",
                modelName: "Panoptic 24 mm",
                category: .eyepiece,
                eyepieceFocalLengthMillimeters: 24,
                apparentFieldOfViewDegrees: 68,
                specifications: "1.25 in wide-field eyepiece",
                notes: "Common maximum-field 1.25 in visual eyepiece."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0204",
                name: "Delos 10",
                brand: "Tele Vue",
                modelName: "Delos 10 mm",
                category: .eyepiece,
                eyepieceFocalLengthMillimeters: 10,
                apparentFieldOfViewDegrees: 72,
                specifications: "1.25 in long eye relief eyepiece",
                notes: "Premium planetary and deep-sky eyepiece."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0205",
                name: "2x Powermate",
                brand: "Tele Vue",
                modelName: "2x Powermate",
                category: .accessory,
                accessoryDetails: "Telecentric image amplifier / Barlow-style doubler",
                specifications: "2 in 2x Powermate",
                notes: "High-quality amplifier for visual and imaging use."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0206",
                name: "4x Powermate",
                brand: "Tele Vue",
                modelName: "4x Powermate",
                category: .accessory,
                accessoryDetails: "Telecentric image amplifier",
                specifications: "2 in 4x Powermate",
                notes: "High-power amplifier often used for planetary imaging."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0207",
                name: "Hyperion Zoom Mark IV",
                brand: "Baader Planetarium",
                modelName: "Hyperion Zoom Mark IV 8-24 mm",
                category: .eyepiece,
                eyepieceFocalLengthMillimeters: 8,
                apparentFieldOfViewDegrees: 68,
                specifications: "8-24 mm variable focal length zoom eyepiece",
                notes: "Popular Baader zoom eyepiece for visual observing."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0208",
                name: "Morpheus 17.5",
                brand: "Baader Planetarium",
                modelName: "Morpheus 17.5 mm",
                category: .eyepiece,
                eyepieceFocalLengthMillimeters: 17.5,
                apparentFieldOfViewDegrees: 76,
                specifications: "1.25 in / 2 in wide-field eyepiece",
                notes: "Long-eye-relief Baader Morpheus eyepiece."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0209",
                name: "VIP 2x Modular Barlow",
                brand: "Baader Planetarium",
                modelName: "VIP Barlow",
                category: .accessory,
                accessoryDetails: "Modular Barlow lens",
                specifications: "VIP 2x Barlow system",
                notes: "Modular Baader Barlow for visual and imaging trains."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0210",
                name: "82 Degree 30 mm",
                brand: "Explore Scientific",
                modelName: "82 Degree Series 30 mm",
                category: .eyepiece,
                eyepieceFocalLengthMillimeters: 30,
                apparentFieldOfViewDegrees: 82,
                specifications: "2 in waterproof ultra-wide eyepiece",
                notes: "Wide-field Explore Scientific eyepiece."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0211",
                name: "68 Degree 24 mm",
                brand: "Explore Scientific",
                modelName: "68 Degree Series 24 mm",
                category: .eyepiece,
                eyepieceFocalLengthMillimeters: 24,
                apparentFieldOfViewDegrees: 68,
                specifications: "1.25 in waterproof wide-field eyepiece",
                notes: "Compact wide-field eyepiece."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0212",
                name: "2x Focal Extender",
                brand: "Explore Scientific",
                modelName: "2x Focal Extender",
                category: .accessory,
                accessoryDetails: "Telecentric focal extender / Barlow-style amplifier",
                specifications: "2 in 2x focal extender",
                notes: "Image amplifier for visual and imaging use."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0213",
                name: "Series 5000 UWA 14",
                brand: "Meade",
                modelName: "Series 5000 Ultra Wide Angle 14 mm",
                category: .eyepiece,
                eyepieceFocalLengthMillimeters: 14,
                apparentFieldOfViewDegrees: 82,
                specifications: "Legacy ultra-wide angle eyepiece",
                notes: "Legacy Meade wide-field eyepiece."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0214",
                name: "Series 4000 Super Plossl 26",
                brand: "Meade",
                modelName: "Series 4000 Super Plossl 26 mm",
                category: .eyepiece,
                eyepieceFocalLengthMillimeters: 26,
                apparentFieldOfViewDegrees: 52,
                specifications: "Legacy Plossl eyepiece",
                notes: "Common legacy Meade visual eyepiece."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0215",
                name: "X-Cel LX 2x Barlow",
                brand: "Celestron",
                modelName: "X-Cel LX 2x Barlow",
                category: .accessory,
                accessoryDetails: "Barlow lens",
                specifications: "1.25 in 2x Barlow",
                notes: "Celestron visual amplifier for 1.25 in eyepieces."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0216",
                name: "Luminos 23",
                brand: "Celestron",
                modelName: "Luminos 23 mm",
                category: .eyepiece,
                eyepieceFocalLengthMillimeters: 23,
                apparentFieldOfViewDegrees: 82,
                specifications: "2 in ultra-wide eyepiece",
                notes: "Celestron wide-angle visual eyepiece."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0217",
                name: "XWA 13",
                brand: "APM",
                modelName: "XWA 13 mm",
                category: .eyepiece,
                eyepieceFocalLengthMillimeters: 13,
                apparentFieldOfViewDegrees: 100,
                specifications: "100 degree ultra-wide eyepiece",
                notes: "Representative modern ultra-wide eyepiece."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0218",
                name: "SV215 Zoom",
                brand: "SVBONY",
                modelName: "SV215 3-8 mm Zoom",
                category: .eyepiece,
                eyepieceFocalLengthMillimeters: 3,
                apparentFieldOfViewDegrees: 56,
                specifications: "3-8 mm planetary zoom eyepiece",
                notes: "Budget high-power zoom eyepiece."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0219",
                name: "Telrad Reflex Sight",
                brand: "Telrad",
                modelName: "Telrad Reflex Sight",
                category: .accessory,
                accessoryDetails: "Zero-power reflex finder",
                specifications: "Projected bullseye reticle finder",
                notes: "Classic Telrad finder for manual star hopping."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0220",
                name: "StarPointer Pro",
                brand: "Celestron",
                modelName: "StarPointer Pro",
                category: .accessory,
                accessoryDetails: "Reflex finder",
                specifications: "Circular reticle red-dot finder",
                notes: "Low-profile Celestron finder for star alignment."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0221",
                name: "9x50 RACI Finder",
                brand: "Celestron",
                modelName: "9x50 Right-Angle Correct-Image Finder",
                category: .accessory,
                accessoryDetails: "Right-angle correct-image finderscope",
                specifications: "9x50 optical finder",
                notes: "Optical finder for SCTs and refractors."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0222",
                name: "9x50 RACI Finder",
                brand: "Orion Telescopes & Binoculars",
                modelName: "9x50 Right-Angle Correct-Image Finder",
                category: .accessory,
                accessoryDetails: "Legacy right-angle correct-image finderscope",
                specifications: "9x50 optical finder",
                notes: "Legacy Orion optical finder."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0223",
                name: "SV182 6x30 Finder",
                brand: "SVBONY",
                modelName: "SV182 6x30 Finder Scope",
                category: .accessory,
                accessoryDetails: "Optical finderscope",
                specifications: "6x30 finder scope",
                notes: "Budget optical finder."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0224",
                name: "SkySurfer V",
                brand: "Baader Planetarium",
                modelName: "SkySurfer V",
                category: .accessory,
                accessoryDetails: "Red-dot finder",
                specifications: "Weather-resistant red-dot finder",
                notes: "Baader reflex finder for visual pointing."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0225",
                name: "QuikFinder",
                brand: "Rigel Systems",
                modelName: "QuikFinder",
                category: .accessory,
                accessoryDetails: "Zero-power reflex finder",
                specifications: "Pulse-illuminated reflex finder",
                notes: "Compact alternative to a Telrad."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0226",
                name: "CGX",
                brand: "Celestron",
                modelName: "CGX Computerized Equatorial Mount",
                category: .mount,
                mountDescription: "Computerized German equatorial mount",
                specifications: "55 lb payload class",
                notes: "Celestron mid-heavy GoTo equatorial mount."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0227",
                name: "CGX-L",
                brand: "Celestron",
                modelName: "CGX-L Computerized Equatorial Mount",
                category: .mount,
                mountDescription: "Computerized German equatorial mount",
                specifications: "75 lb payload class",
                notes: "Celestron heavy GoTo equatorial mount."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0228",
                name: "HEQ5 Pro",
                brand: "Sky-Watcher",
                modelName: "HEQ5 Pro",
                category: .mount,
                mountDescription: "Computerized German equatorial mount",
                specifications: "30 lb payload class",
                notes: "Portable GoTo equatorial mount."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0229",
                name: "Star Adventurer GTi",
                brand: "Sky-Watcher",
                modelName: "Star Adventurer GTi",
                category: .mount,
                mountDescription: "Portable GoTo equatorial mount",
                specifications: "Lightweight travel imaging mount",
                notes: "Compact mount for camera lenses and small refractors."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0230",
                name: "AZ-GTi",
                brand: "Sky-Watcher",
                modelName: "AZ-GTi",
                category: .mount,
                mountDescription: "Portable computerized alt-azimuth mount",
                specifications: "Wi-Fi enabled GoTo mount",
                notes: "Small GoTo mount for grab-and-go scopes."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0231",
                name: "SV225 Alt-Azimuth Mount",
                brand: "SVBONY",
                modelName: "SV225",
                category: .mount,
                mountDescription: "Manual alt-azimuth mount",
                specifications: "Portable visual mount head",
                notes: "Representative SVBONY manual mount."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0232",
                name: "GEM28",
                brand: "iOptron",
                modelName: "GEM28",
                category: .mount,
                mountDescription: "Computerized German equatorial mount",
                specifications: "28 lb payload class",
                notes: "Portable iOptron GoTo imaging mount."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0233",
                name: "CEM40",
                brand: "iOptron",
                modelName: "CEM40",
                category: .mount,
                mountDescription: "Center-balanced equatorial mount",
                specifications: "40 lb payload class",
                notes: "Mid-size iOptron imaging mount."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0234",
                name: "GM811G",
                brand: "Losmandy",
                modelName: "GM811G",
                category: .mount,
                mountDescription: "GoTo German equatorial mount",
                specifications: "Mid-size Losmandy equatorial mount",
                notes: "Premium modular mount system."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0235",
                name: "AM5",
                brand: "ZWO",
                modelName: "AM5",
                category: .mount,
                mountDescription: "Harmonic drive equatorial / alt-az mount",
                specifications: "Portable strain-wave mount",
                notes: "Modern lightweight imaging mount."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0236",
                name: "Planet Tripod",
                brand: "Berlebach",
                modelName: "Planet",
                category: .mount,
                mountDescription: "Wood astronomy tripod",
                specifications: "Heavy-duty ash tripod",
                notes: "Premium vibration-damping tripod."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0237",
                name: "Tri-Pier",
                brand: "iOptron",
                modelName: "Tri-Pier",
                category: .mount,
                mountDescription: "Hybrid tripod and pier",
                specifications: "Portable tri-pier support",
                notes: "Portable pier-style tripod for iOptron mounts and adapters."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0238",
                name: "Pier-Tech 1",
                brand: "Pier-Tech",
                modelName: "Pier-Tech 1",
                category: .mount,
                mountDescription: "Fixed observatory pier",
                specifications: "Stationary telescope pier",
                notes: "Representative fixed pier mount for observatories."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0239",
                name: "Pier-Tech 2",
                brand: "Pier-Tech",
                modelName: "Pier-Tech 2",
                category: .mount,
                mountDescription: "Adjustable-height observatory pier",
                specifications: "Motorized adjustable telescope pier",
                notes: "Fixed pier option for permanent installations."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0240",
                name: "Heavy Duty Tripod",
                brand: "Celestron",
                modelName: "Heavy Duty Tripod",
                category: .mount,
                mountDescription: "Field tripod",
                specifications: "Heavy-duty tripod for fork and equatorial systems",
                notes: "Common Celestron tripod support."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0241",
                name: "Pier Extension",
                brand: "Sky-Watcher",
                modelName: "Tripod Pier Extension",
                category: .accessory,
                accessoryDetails: "Mount pier extension",
                specifications: "Tripod extension for selected Sky-Watcher mounts",
                notes: "Raises mount head to improve telescope clearance."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0242",
                name: "CHL 2.5 Focuser",
                brand: "MoonLite Telescope Accessories",
                modelName: "CHL 2.5",
                category: .accessory,
                accessoryDetails: "Crayford-style focuser",
                specifications: "2.5 in MoonLite focuser with motor option",
                notes: "Premium MoonLite focuser for imaging and visual use."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0243",
                name: "NiteCrawler WR30",
                brand: "MoonLite Telescope Accessories",
                modelName: "NiteCrawler WR30",
                category: .accessory,
                accessoryDetails: "Rotating motorized focuser",
                specifications: "3 in focuser / rotator",
                notes: "High-end motorized focuser and rotator system."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0244",
                name: "Feather Touch FTF3015B-A",
                brand: "Starlight Instruments",
                modelName: "FTF3015B-A",
                category: .accessory,
                accessoryDetails: "Rack-and-pinion focuser",
                specifications: "3 in Feather Touch focuser",
                notes: "Premium Starlight Instruments focuser."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0245",
                name: "Focus Motor",
                brand: "Celestron",
                modelName: "Focus Motor",
                category: .accessory,
                accessoryDetails: "Electronic focuser motor",
                specifications: "Motorized focus accessory for supported SCT, EdgeHD, and RASA systems",
                notes: "Celestron motor focuser for computer-controlled focusing."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0246",
                name: "FocusCube v3",
                brand: "Pegasus Astro",
                modelName: "FocusCube v3",
                category: .accessory,
                accessoryDetails: "Motorized focuser",
                specifications: "USB / ASCOM / INDI compatible focuser motor",
                notes: "Popular autofocus motor for imaging systems."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0247",
                name: "TCF-Leo",
                brand: "Optec",
                modelName: "TCF-Leo",
                category: .accessory,
                accessoryDetails: "Low-profile motorized focuser",
                specifications: "Temperature-compensating focuser",
                notes: "High-end imaging focuser."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0248",
                name: "nSTEP",
                brand: "Rigel Systems",
                modelName: "nSTEP",
                category: .accessory,
                accessoryDetails: "Stepper focus controller",
                specifications: "Motorized focus controller system",
                notes: "Aftermarket electronic focuser controller."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0249",
                name: "BBHS 2 in Mirror Diagonal",
                brand: "Baader Planetarium",
                modelName: "2 in BBHS Mirror Diagonal",
                category: .accessory,
                accessoryDetails: "Mirror star diagonal",
                specifications: "2 in BBHS diagonal",
                notes: "Premium Baader visual diagonal."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0250",
                name: "T-2 Prism Diagonal",
                brand: "Baader Planetarium",
                modelName: "T-2 Prism Diagonal",
                category: .accessory,
                accessoryDetails: "Prism star diagonal",
                specifications: "T-2 prism diagonal",
                notes: "Compact modular diagonal for visual trains."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0251",
                name: "DuraBright 2 in Diagonal",
                brand: "William Optics",
                modelName: "DuraBright 2 in Diagonal",
                category: .accessory,
                accessoryDetails: "Dielectric star diagonal",
                specifications: "2 in dielectric diagonal",
                notes: "Common William Optics visual diagonal."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0252",
                name: "SCT T-Adapter",
                brand: "Celestron",
                modelName: "T-Adapter SCT",
                category: .accessory,
                accessoryDetails: "Camera adapter",
                specifications: "SCT to T-thread adapter",
                notes: "Connects DSLR / mirrorless camera T-rings to SCT rear cells."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0253",
                name: "f/6.3 Reducer Corrector",
                brand: "Celestron",
                modelName: "f/6.3 Reducer Corrector",
                category: .accessory,
                accessoryDetails: "Reducer / corrector lens",
                specifications: "0.63x reducer-corrector for SCTs",
                notes: "Common SCT reducer for imaging and wider visual fields."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0254",
                name: "Nexus 0.75x Reducer Corrector",
                brand: "Starizona",
                modelName: "Nexus 0.75x",
                category: .accessory,
                accessoryDetails: "Newtonian reducer / coma corrector",
                specifications: "0.75x reducer-corrector",
                notes: "Fast Newtonian imaging corrector."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0255",
                name: "SCT Corrector IV",
                brand: "Starizona",
                modelName: "SCT Corrector IV",
                category: .accessory,
                accessoryDetails: "SCT corrector / reducer",
                specifications: "SCT field corrector accessory",
                notes: "Imaging corrector for classic SCT optical tubes."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0256",
                name: "MPCC Mark III",
                brand: "Baader Planetarium",
                modelName: "MPCC Mark III",
                category: .accessory,
                accessoryDetails: "Coma corrector",
                specifications: "Multi-purpose Newtonian coma corrector",
                notes: "Common imaging corrector for fast Newtonians."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0257",
                name: "Paracorr Type 2",
                brand: "Tele Vue",
                modelName: "Paracorr Type 2",
                category: .accessory,
                accessoryDetails: "Coma corrector",
                specifications: "Visual / imaging Newtonian coma corrector",
                notes: "Premium Tele Vue corrector for fast Dobsonians and Newtonians."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0258",
                name: "Digital Camera Adapter",
                brand: "Tele Vue",
                modelName: "Digital Camera Adapter",
                category: .accessory,
                accessoryDetails: "Camera adapter",
                specifications: "Tele Vue imaging adapter",
                notes: "Camera coupling accessory for Tele Vue optics."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0259",
                name: "M54 / M48 Adapter Set",
                brand: "ZWO",
                modelName: "M54 / M48 Adapter Set",
                category: .accessory,
                accessoryDetails: "Camera spacing adapters",
                specifications: "Threaded M54 / M48 imaging adapters",
                notes: "Common spacer set for cooled astronomy cameras."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0260",
                name: "ASI6200MM Pro",
                brand: "ZWO",
                modelName: "ASI6200MM Pro",
                category: .camera,
                sensorName: "Sony IMX455 mono full-frame • 9576 x 6388 max pixels • 61 MP • 3.76 um pixels",
                specifications: "Cooled monochrome astronomy camera",
                notes: "Large-format ZWO deep-sky camera."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0261",
                name: "ASI585MC Pro",
                brand: "ZWO",
                modelName: "ASI585MC Pro",
                category: .camera,
                sensorName: "Sony STARVIS 2 IMX585 color • 3840 x 2160 max pixels • 8.3 MP",
                specifications: "Cooled one-shot color astronomy camera",
                notes: "Compact color camera for planetary and deep-sky imaging."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0262",
                name: "QHY268M",
                brand: "QHYCCD",
                modelName: "QHY268M",
                category: .camera,
                sensorName: "Sony IMX571 mono APS-C • 6248 x 4176 max pixels • 26 MP • 3.76 um pixels",
                specifications: "Cooled monochrome astronomy camera",
                notes: "QHY mono APS-C deep-sky camera."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0263",
                name: "QHY600M",
                brand: "QHYCCD",
                modelName: "QHY600M",
                category: .camera,
                sensorName: "Sony IMX455 mono full-frame • 9576 x 6388 max pixels • 61 MP • 3.76 um pixels",
                specifications: "Cooled monochrome astronomy camera",
                notes: "High-resolution QHY full-frame camera."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0264",
                name: "Poseidon-C Pro",
                brand: "Player One Astronomy",
                modelName: "Poseidon-C Pro",
                category: .camera,
                sensorName: "Sony IMX571 color APS-C • 6248 x 4176 max pixels • 26 MP • 3.76 um pixels",
                specifications: "Cooled one-shot color astronomy camera",
                notes: "Player One APS-C color deep-sky camera."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0265",
                name: "Atik 460EX",
                brand: "Atik Cameras",
                modelName: "Atik 460EX",
                category: .camera,
                sensorName: "Sony ICX694 mono CCD • 2750 x 2200 max pixels • 6.1 MP",
                specifications: "Cooled monochrome CCD astronomy camera",
                notes: "Legacy Atik narrowband imaging camera."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0266",
                name: "Trius SX-694",
                brand: "Starlight Xpress",
                modelName: "Trius SX-694",
                category: .camera,
                sensorName: "Sony ICX694 mono CCD • 2750 x 2200 max pixels • 6.1 MP",
                specifications: "Cooled monochrome CCD astronomy camera",
                notes: "Legacy Starlight Xpress imaging camera."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0267",
                name: "C3-26000",
                brand: "Moravian Instruments",
                modelName: "C3-26000",
                category: .camera,
                sensorName: "Sony IMX571 mono APS-C • 6248 x 4176 max pixels • 26 MP • 3.76 um pixels",
                specifications: "Cooled monochrome astronomy camera",
                notes: "Moravian APS-C deep-sky imaging camera."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0268",
                name: "EOS Ra",
                brand: "Canon",
                modelName: "EOS Ra",
                category: .camera,
                sensorName: "Modified full-frame mirrorless sensor • 6720 x 4480 max pixels • 30.3 MP",
                specifications: "Astrophotography mirrorless camera",
                notes: "Canon full-frame camera modified for H-alpha response."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0269",
                name: "LRGB Filter Set",
                brand: "Chroma Technology",
                modelName: "LRGB Filter Set",
                category: .filterSystem,
                filterDescription: "LRGB imaging filter set",
                specifications: "Premium parfocal imaging filter set",
                notes: "Representative premium broadband imaging filters."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0270",
                name: "3 nm SHO Filter Set",
                brand: "Chroma Technology",
                modelName: "3 nm SHO Set",
                category: .filterSystem,
                filterDescription: "Narrowband H-alpha / OIII / SII set",
                specifications: "3 nm narrowband filters",
                notes: "Premium narrowband imaging filters."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0271",
                name: "LRGB Gen2",
                brand: "Astrodon",
                modelName: "LRGB Gen2",
                category: .filterSystem,
                filterDescription: "LRGB imaging filter set",
                specifications: "Parfocal Gen2 broadband filters",
                notes: "Legacy premium imaging filter set."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0272",
                name: "3 nm Narrowband Set",
                brand: "Astrodon",
                modelName: "3 nm Narrowband Set",
                category: .filterSystem,
                filterDescription: "H-alpha / OIII / SII narrowband filters",
                specifications: "3 nm narrowband filters",
                notes: "Legacy premium narrowband filter set."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0273",
                name: "ALP-T Dual Band 5 nm",
                brand: "Antlia",
                modelName: "ALP-T Dual Band 5 nm",
                category: .filterSystem,
                filterDescription: "Dual-band H-alpha / OIII filter",
                specifications: "5 nm dual-band imaging filter",
                notes: "Narrow dual-band filter for OSC cameras."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0274",
                name: "L-Ultimate",
                brand: "Optolong",
                modelName: "L-Ultimate",
                category: .filterSystem,
                filterDescription: "Dual-band H-alpha / OIII filter",
                specifications: "3 nm dual-band imaging filter",
                notes: "Common narrow dual-band OSC filter."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0275",
                name: "NBZ",
                brand: "IDAS",
                modelName: "NBZ",
                category: .filterSystem,
                filterDescription: "Dual-band nebula filter",
                specifications: "H-alpha / OIII dual-band filter",
                notes: "Nebula filter optimized for fast optics."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0276",
                name: "CMOS SHO 6.5 nm Set",
                brand: "Baader Planetarium",
                modelName: "CMOS SHO 6.5 nm Set",
                category: .filterSystem,
                filterDescription: "H-alpha / OIII / SII CMOS-optimized set",
                specifications: "6.5 nm narrowband filters",
                notes: "Baader narrowband filter set."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0277",
                name: "EFW 7 x 2 in Filter Wheel",
                brand: "ZWO",
                modelName: "EFW 7 x 2 in",
                category: .filterSystem,
                filterDescription: "Motorized electronic filter wheel",
                specifications: "Seven 2 in positions",
                notes: "Automatic filter wheel for mono camera rigs."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0278",
                name: "CFW3 Large",
                brand: "QHYCCD",
                modelName: "CFW3 Large",
                category: .filterSystem,
                filterDescription: "Motorized electronic filter wheel",
                specifications: "Large-format QHY filter wheel",
                notes: "Automatic filter system for QHY imaging rigs."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0279",
                name: "USB Filter Wheel",
                brand: "Starlight Xpress",
                modelName: "USB Filter Wheel",
                category: .filterSystem,
                filterDescription: "Motorized electronic filter wheel",
                specifications: "USB-controlled filter wheel",
                notes: "Automatic filter wheel for mono imaging."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0280",
                name: "Indigo Filter Wheel",
                brand: "Pegasus Astro",
                modelName: "Indigo Filter Wheel",
                category: .filterSystem,
                filterDescription: "Motorized electronic filter wheel",
                specifications: "USB-controlled filter wheel",
                notes: "Modern automatic filter wheel."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0281",
                name: "SkyPortal WiFi Module",
                brand: "Celestron",
                modelName: "SkyPortal WiFi Module",
                category: .accessory,
                accessoryDetails: "Telescope Wi-Fi control module",
                specifications: "Wi-Fi module for compatible Celestron computerized mounts",
                notes: "Wireless control through SkyPortal / SkySafari workflows."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0282",
                name: "SynScan WiFi Adapter",
                brand: "Sky-Watcher",
                modelName: "SynScan WiFi Adapter",
                category: .accessory,
                accessoryDetails: "Telescope Wi-Fi control module",
                specifications: "Wi-Fi adapter for compatible SynScan mounts",
                notes: "Wireless control for Sky-Watcher GoTo mounts."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0283",
                name: "ASIAIR Plus",
                brand: "ZWO",
                modelName: "ASIAIR Plus",
                category: .accessory,
                accessoryDetails: "Wi-Fi astrophotography controller",
                specifications: "Wireless imaging control computer",
                notes: "Controls cameras, focusers, filter wheels, and mounts."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0284",
                name: "SkyFi III",
                brand: "Simulation Curriculum",
                modelName: "SkyFi III",
                category: .accessory,
                accessoryDetails: "Wireless telescope controller",
                specifications: "Wi-Fi serial telescope control adapter",
                notes: "SkySafari-compatible Wi-Fi telescope bridge."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0285",
                name: "iStarFi Wi-Fi Adapter",
                brand: "iOptron",
                modelName: "iStarFi",
                category: .accessory,
                accessoryDetails: "Telescope Wi-Fi control module",
                specifications: "Wi-Fi adapter for compatible iOptron mounts",
                notes: "Wireless iOptron mount control accessory."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0286",
                name: "Stella Wi-Fi Adapter",
                brand: "Meade",
                modelName: "Stella",
                category: .accessory,
                accessoryDetails: "Legacy Wi-Fi telescope controller",
                specifications: "Wireless control adapter for Meade GoTo systems",
                notes: "Legacy Meade wireless telescope control accessory."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0287",
                name: "2.4 GHz Wi-Fi Adapter",
                brand: "StellarMate",
                modelName: "StellarMate Controller",
                category: .accessory,
                accessoryDetails: "Wi-Fi astrophotography controller",
                specifications: "Wireless INDI imaging controller",
                notes: "Computer-assisted telescope and imaging control accessory."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0288",
                name: "Manual Filter Wheel",
                brand: "ZWO",
                modelName: "Manual Filter Wheel",
                category: .filterSystem,
                filterDescription: "Manual filter wheel",
                specifications: "5 x 1.25 in manual filter wheel",
                notes: "Manual filter system for visual or camera use."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0289",
                name: "SV226 Filter Drawer",
                brand: "SVBONY",
                modelName: "SV226",
                category: .filterSystem,
                filterDescription: "Manual filter drawer",
                specifications: "M48 filter drawer / drawer system",
                notes: "Manual filter swap system for imaging trains."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0290",
                name: "ASI2400MC Pro",
                brand: "ZWO",
                modelName: "ASI2400MC Pro",
                category: .camera,
                sensorName: "Sony IMX410 color full-frame • 6072 x 4042 max pixels • 24 MP",
                specifications: "Cooled one-shot color astronomy camera",
                notes: "Large-pixel full-frame ZWO deep-sky camera."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0291",
                name: "ASI294MM Pro",
                brand: "ZWO",
                modelName: "ASI294MM Pro",
                category: .camera,
                sensorName: "Sony IMX492 mono 4/3 format • 4144 x 2822 default output • 11.7 MP",
                specifications: "Cooled monochrome astronomy camera",
                notes: "Flexible mono camera for LRGB and narrowband imaging."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0292",
                name: "QHY533M",
                brand: "QHYCCD",
                modelName: "QHY533M",
                category: .camera,
                sensorName: "Sony IMX533 mono • 3008 x 3008 max pixels • 9.0 MP",
                specifications: "Cooled monochrome astronomy camera",
                notes: "Square-format QHY mono deep-sky camera."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0293",
                name: "Uranus-M Pro",
                brand: "Player One Astronomy",
                modelName: "Uranus-M Pro",
                category: .camera,
                sensorName: "Sony STARVIS 2 IMX585 mono • 3856 x 2180 max pixels • 8.3 MP",
                specifications: "Cooled monochrome astronomy camera",
                notes: "Player One cooled IMX585 camera for planetary, lunar, solar, and compact deep-sky work."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0294",
                name: "Horizon II",
                brand: "Atik Cameras",
                modelName: "Horizon II",
                category: .camera,
                sensorName: "4/3 format cooled CMOS • 4644 x 3506 max pixels • 16 MP class",
                specifications: "Cooled astronomy camera",
                notes: "Atik CMOS deep-sky camera family entry."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0295",
                name: "X-Cel LX 25",
                brand: "Celestron",
                modelName: "X-Cel LX 25 mm",
                category: .eyepiece,
                eyepieceFocalLengthMillimeters: 25,
                apparentFieldOfViewDegrees: 60,
                specifications: "1.25 in eyepiece",
                notes: "Common Celestron visual eyepiece."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0296",
                name: "Morpheus 9",
                brand: "Baader Planetarium",
                modelName: "Morpheus 9 mm",
                category: .eyepiece,
                eyepieceFocalLengthMillimeters: 9,
                apparentFieldOfViewDegrees: 76,
                specifications: "1.25 in / 2 in wide-field eyepiece",
                notes: "Mid-high-power Baader Morpheus eyepiece."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0297",
                name: "82 Degree 14 mm",
                brand: "Explore Scientific",
                modelName: "82 Degree Series 14 mm",
                category: .eyepiece,
                eyepieceFocalLengthMillimeters: 14,
                apparentFieldOfViewDegrees: 82,
                specifications: "1.25 in waterproof ultra-wide eyepiece",
                notes: "Medium-power Explore Scientific wide-field eyepiece."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0298",
                name: "XW 10",
                brand: "Pentax",
                modelName: "XW 10 mm",
                category: .eyepiece,
                eyepieceFocalLengthMillimeters: 10,
                apparentFieldOfViewDegrees: 70,
                specifications: "1.25 in long-eye-relief eyepiece",
                notes: "Premium visual eyepiece for lunar, planetary, and deep-sky use."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0299",
                name: "DeLite 7",
                brand: "Tele Vue",
                modelName: "DeLite 7 mm",
                category: .eyepiece,
                eyepieceFocalLengthMillimeters: 7,
                apparentFieldOfViewDegrees: 62,
                specifications: "1.25 in long-eye-relief eyepiece",
                notes: "Compact Tele Vue high-power eyepiece."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0300",
                name: "AM3",
                brand: "ZWO",
                modelName: "AM3",
                category: .mount,
                mountDescription: "Harmonic drive equatorial / alt-az mount",
                specifications: "Compact strain-wave travel mount",
                notes: "Smaller ZWO harmonic mount for lightweight imaging rigs."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0301",
                name: "CEM70",
                brand: "iOptron",
                modelName: "CEM70",
                category: .mount,
                mountDescription: "Center-balanced equatorial mount",
                specifications: "70 lb payload class",
                notes: "Higher-capacity iOptron imaging mount."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0302",
                name: "RST-135",
                brand: "Rainbow Astro",
                modelName: "RST-135",
                category: .mount,
                mountDescription: "Harmonic drive equatorial / alt-az mount",
                specifications: "Compact strain-wave travel mount",
                notes: "Premium portable mount for visual and imaging use."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0303",
                name: "G11G",
                brand: "Losmandy",
                modelName: "G11G",
                category: .mount,
                mountDescription: "GoTo German equatorial mount",
                specifications: "Heavy Losmandy equatorial mount class",
                notes: "Classic premium observatory-capable mount."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0304",
                name: "Pocket Powerbox Advance v2",
                brand: "Pegasus Astro",
                modelName: "Pocket Powerbox Advance Gen2",
                category: .accessory,
                accessoryDetails: "Power, USB, and dew-control hub",
                specifications: "Power distribution and data-control box for imaging rigs",
                notes: "Centralizes power, USB, environmental sensing, and dew-heater control."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0305",
                name: "Ultimate Powerbox v3",
                brand: "Pegasus Astro",
                modelName: "Ultimate Powerbox v3",
                category: .accessory,
                accessoryDetails: "Advanced power, USB, and dew-control hub",
                specifications: "Full observatory power and data-control box",
                notes: "Larger Pegasus Astro control hub for complex imaging systems."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0306",
                name: "EAGLE6",
                brand: "PrimaLuceLab",
                modelName: "EAGLE6",
                category: .accessory,
                accessoryDetails: "Telescope control computer and power hub",
                specifications: "Remote control computer with power distribution and wired / wireless control",
                notes: "Integrated computer platform for astrophotography capture and observatory control."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0307",
                name: "StarSense AutoAlign",
                brand: "Celestron",
                modelName: "StarSense AutoAlign",
                category: .accessory,
                accessoryDetails: "Automatic alignment camera accessory",
                specifications: "Plate-solving alignment module for compatible computerized Celestron telescopes",
                notes: "Automates star alignment for supported mounts and optical tubes."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0308",
                name: "PoleMaster",
                brand: "QHYCCD",
                modelName: "PoleMaster",
                category: .accessory,
                accessoryDetails: "Electronic polar alignment camera",
                specifications: "USB polar alignment camera and software workflow",
                notes: "Dedicated polar-alignment camera for equatorial mounts."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0309",
                name: "CAA Camera Angle Adjuster",
                brand: "ZWO",
                modelName: "CAA",
                category: .accessory,
                accessoryDetails: "Electronic camera rotator / angle adjuster",
                specifications: "Motorized camera angle adjuster for imaging trains",
                notes: "Useful for framing repeatability in automated imaging workflows."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0310",
                name: "PixInsight",
                brand: "Pleiades Astrophoto",
                modelName: "PixInsight",
                category: .accessory,
                accessoryDetails: "Dedicated astrophotography processing software",
                specifications: "macOS-capable calibration, registration, integration, and post-processing application",
                notes: "Tahoe workflow candidate; verify current vendor release notes before production use."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0311",
                name: "Siril",
                brand: "Siril",
                modelName: "Siril",
                category: .accessory,
                accessoryDetails: "Dedicated astrophotography processing software",
                specifications: "macOS-capable open-source calibration, stacking, registration, and processing workflow",
                notes: "Tahoe workflow candidate for deep-sky processing."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0312",
                name: "Astro Pixel Processor",
                brand: "Aries Productions",
                modelName: "Astro Pixel Processor",
                category: .accessory,
                accessoryDetails: "Dedicated astrophotography processing software",
                specifications: "macOS-capable calibration, registration, normalization, integration, and mosaic workflow",
                notes: "Tahoe workflow candidate for multi-session and mosaic processing."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0313",
                name: "PHD2 Guiding",
                brand: "Open PHD Guiding",
                modelName: "PHD2",
                category: .accessory,
                accessoryDetails: "Autoguiding software",
                specifications: "macOS-capable telescope guiding application",
                notes: "Common guiding tool for mount corrections during imaging."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0314",
                name: "KStars / Ekos",
                brand: "KDE",
                modelName: "KStars / Ekos",
                category: .accessory,
                accessoryDetails: "Planetarium, capture, scheduling, and INDI control software",
                specifications: "macOS-capable astronomy suite with Ekos imaging workflows",
                notes: "Useful for planning, capture, guiding, plate solving, and equipment control."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0315",
                name: "AstroImager",
                brand: "CloudMakers",
                modelName: "AstroImager",
                category: .accessory,
                accessoryDetails: "Dedicated astrophotography capture software",
                specifications: "macOS astronomy camera capture application",
                notes: "Tahoe workflow candidate for image capture with supported INDIGO devices."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0316",
                name: "AstroGuider",
                brand: "CloudMakers",
                modelName: "AstroGuider",
                category: .accessory,
                accessoryDetails: "Dedicated autoguiding software",
                specifications: "macOS guiding application for supported cameras and mounts",
                notes: "Tahoe workflow candidate for guiding in CloudMakers / INDIGO workflows."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0317",
                name: "SkySafari Pro",
                brand: "Simulation Curriculum",
                modelName: "SkySafari Pro",
                category: .accessory,
                accessoryDetails: "Planetarium and telescope-control software",
                specifications: "macOS / iOS planning and wireless telescope-control workflow",
                notes: "Useful for object lookup, observing lists, and telescope control with compatible adapters."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0318",
                name: "Affinity Photo 2",
                brand: "Affinity",
                modelName: "Photo 2",
                category: .accessory,
                accessoryDetails: "Astrophotography image editing and processing software",
                specifications: "macOS photo editor with stacking, non-destructive layer workflows, macros, and astronomy processing support",
                notes: "Use browser notice for current product details and licensing."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0319",
                name: "JR Ritson Astrophotography Libraries",
                brand: "James Ritson",
                modelName: "Astrophotography Macros / Libraries",
                category: .accessory,
                accessoryDetails: "Affinity Photo astrophotography macro and library workflow",
                specifications: "Tone stretching, masking, star control, sharpening, denoising, and compositing macro library for Affinity workflows",
                notes: "Use browser notice for current download and compatibility details."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0320",
                name: "Photoshop Elements",
                brand: "Adobe",
                modelName: "Photoshop Elements",
                category: .accessory,
                accessoryDetails: "Consumer photo editing software",
                specifications: "macOS photo editor for post-processing and image finishing workflows",
                notes: "Use browser notice for current product details and licensing."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0321",
                name: "Photoshop",
                brand: "Adobe",
                modelName: "Photoshop",
                category: .accessory,
                accessoryDetails: "Professional photo editing and compositing software",
                specifications: "macOS image editor used for astrophotography finishing, compositing, masks, layers, curves, and color work",
                notes: "Use browser notice for current product details and licensing."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0322",
                name: "Lightroom Classic",
                brand: "Adobe",
                modelName: "Lightroom Classic",
                category: .accessory,
                accessoryDetails: "Photo management and processing software",
                specifications: "macOS raw-processing and catalog workflow for organizing, adjusting, and exporting astronomy images",
                notes: "Use browser notice for current product details and licensing."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0323",
                name: "Adobe Camera Raw",
                brand: "Adobe",
                modelName: "Camera Raw",
                category: .accessory,
                accessoryDetails: "Raw conversion and processing workflow",
                specifications: "Raw processing component for Adobe photography workflows",
                notes: "Use browser notice for current product details and compatibility."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0401",
                name: "NexStar 8SE",
                brand: "Celestron",
                modelName: "NexStar 8SE",
                apertureMillimeters: 203.2,
                focalLengthMillimeters: 2032,
                mountDescription: "Computerized single fork alt-azimuth mount",
                specifications: "8 in Schmidt-Cassegrain • f/10",
                notes: "Popular portable GoTo SCT for visual observing and planetary work."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0402",
                name: "NexStar 5SE",
                brand: "Celestron",
                modelName: "NexStar 5SE",
                apertureMillimeters: 125,
                focalLengthMillimeters: 1250,
                mountDescription: "Computerized single fork alt-azimuth mount",
                specifications: "5 in Schmidt-Cassegrain • f/10",
                notes: "Compact GoTo SCT for travel and lunar / planetary observing."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0403",
                name: "CPC 1100 GPS XLT",
                brand: "Celestron",
                modelName: "CPC 1100 GPS XLT",
                apertureMillimeters: 279.4,
                focalLengthMillimeters: 2800,
                mountDescription: "Computerized dual-fork alt-azimuth mount",
                specifications: "11 in Schmidt-Cassegrain • f/10 • StarBright XLT",
                notes: "Large-aperture fork-mounted GoTo SCT."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0404",
                name: "EdgeHD 9.25 OTA",
                brand: "Celestron",
                modelName: "EdgeHD 9.25 Optical Tube Assembly",
                apertureMillimeters: 235,
                focalLengthMillimeters: 2350,
                mountDescription: "EdgeHD optical tube assembly",
                specifications: "9.25 in EdgeHD Schmidt-Cassegrain • f/10",
                notes: "Flat-field SCT optical tube for visual and imaging systems."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0405",
                name: "EdgeHD 11 OTA",
                brand: "Celestron",
                modelName: "EdgeHD 11 Optical Tube Assembly",
                apertureMillimeters: 280,
                focalLengthMillimeters: 2800,
                mountDescription: "EdgeHD optical tube assembly",
                specifications: "11 in EdgeHD Schmidt-Cassegrain • f/10",
                notes: "High-aperture flat-field SCT OTA."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0406",
                name: "RASA 11",
                brand: "Celestron",
                modelName: "11 in Rowe-Ackermann Schmidt Astrograph",
                apertureMillimeters: 279,
                focalLengthMillimeters: 620,
                mountDescription: "Astrograph OTA",
                specifications: "Rowe-Ackermann Schmidt Astrograph • f/2.2",
                notes: "Fast large-aperture dedicated imaging optical tube."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0407",
                name: "Quattro 150P",
                brand: "Sky-Watcher",
                modelName: "Quattro 150P Imaging Newtonian",
                apertureMillimeters: 150,
                focalLengthMillimeters: 600,
                mountDescription: "Imaging Newtonian OTA",
                specifications: "Newtonian astrograph • f/4",
                notes: "Fast Sky-Watcher imaging Newtonian."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0408",
                name: "Quattro 200P",
                brand: "Sky-Watcher",
                modelName: "Quattro 200P Imaging Newtonian",
                apertureMillimeters: 200,
                focalLengthMillimeters: 800,
                mountDescription: "Imaging Newtonian OTA",
                specifications: "Newtonian astrograph • f/4",
                notes: "Popular 8 in fast imaging Newtonian."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0409",
                name: "Esprit 80ED",
                brand: "Sky-Watcher",
                modelName: "Esprit 80ED Super APO Triplet",
                apertureMillimeters: 80,
                focalLengthMillimeters: 400,
                mountDescription: "Triplet refractor OTA",
                specifications: "Triplet apochromatic refractor • f/5",
                notes: "Short wide-field Sky-Watcher imaging refractor."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0410",
                name: "Esprit 120ED",
                brand: "Sky-Watcher",
                modelName: "Esprit 120ED Super APO Triplet",
                apertureMillimeters: 120,
                focalLengthMillimeters: 840,
                mountDescription: "Triplet refractor OTA",
                specifications: "Triplet apochromatic refractor • f/7",
                notes: "Larger Sky-Watcher APO for imaging and visual use."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0411",
                name: "Flextube 300P SynScan",
                brand: "Sky-Watcher",
                modelName: "Flextube 300P SynScan",
                apertureMillimeters: 305,
                focalLengthMillimeters: 1500,
                mountDescription: "Collapsible computerized Dobsonian",
                specifications: "12 in GoTo Newtonian Dobsonian • f/4.9",
                notes: "Large-aperture tracking Dobsonian for visual deep-sky observing."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0412",
                name: "CarbonStar 150",
                brand: "Apertura",
                modelName: "CarbonStar 150 Imaging Newtonian",
                apertureMillimeters: 150,
                focalLengthMillimeters: 600,
                mountDescription: "Carbon-fiber imaging Newtonian OTA",
                specifications: "Newtonian astrograph • f/4",
                notes: "Apertura fast imaging reflector."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0413",
                name: "72EDR",
                brand: "Apertura",
                modelName: "72EDR Doublet Refractor",
                apertureMillimeters: 72,
                focalLengthMillimeters: 432,
                mountDescription: "ED refractor OTA",
                specifications: "ED doublet refractor • f/6",
                notes: "Portable Apertura refractor for travel and imaging."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0414",
                name: "LX200 10 ACF",
                brand: "Meade",
                modelName: "LX200 10 in ACF",
                apertureMillimeters: 254,
                focalLengthMillimeters: 2540,
                mountDescription: "Computerized dual-fork mount",
                specifications: "Advanced Coma-Free catadioptric • f/10 • legacy Meade model",
                notes: "Legacy Meade premium GoTo telescope that may still appear on the used market."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0415",
                name: "LX200 12 ACF",
                brand: "Meade",
                modelName: "LX200 12 in ACF",
                apertureMillimeters: 305,
                focalLengthMillimeters: 3048,
                mountDescription: "Computerized dual-fork mount",
                specifications: "Advanced Coma-Free catadioptric • f/10 • legacy Meade model",
                notes: "Large legacy Meade fork-mounted SCT-class system."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0416",
                name: "ETX90 Observer",
                brand: "Meade",
                modelName: "ETX90 Observer",
                apertureMillimeters: 90,
                focalLengthMillimeters: 1250,
                mountDescription: "Computerized compact fork mount",
                specifications: "Maksutov-Cassegrain • f/13.8 • legacy Meade model",
                notes: "Small legacy Meade travel telescope."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0417",
                name: "Series 6000 80 APO",
                brand: "Meade",
                modelName: "Series 6000 80 mm APO Triplet",
                apertureMillimeters: 80,
                focalLengthMillimeters: 480,
                mountDescription: "Triplet refractor OTA",
                specifications: "Apochromatic triplet refractor • f/6 • legacy Meade model",
                notes: "Legacy Meade imaging refractor."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0418",
                name: "AR152",
                brand: "Explore Scientific",
                modelName: "AR152 Air-Spaced Doublet",
                apertureMillimeters: 152,
                focalLengthMillimeters: 988,
                mountDescription: "Achromatic refractor OTA",
                specifications: "152 mm achromatic refractor • f/6.5",
                notes: "Large Explore Scientific refractor for visual observing."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0419",
                name: "Messier AR-127L",
                brand: "BRESSER",
                modelName: "Messier AR-127L",
                apertureMillimeters: 127,
                focalLengthMillimeters: 1200,
                mountDescription: "Achromatic refractor OTA",
                specifications: "127 mm achromatic refractor • f/9.4",
                notes: "Longer focal-length BRESSER Messier refractor."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0420",
                name: "Messier MC-127",
                brand: "BRESSER",
                modelName: "Messier MC-127",
                apertureMillimeters: 127,
                focalLengthMillimeters: 1900,
                mountDescription: "Maksutov-Cassegrain OTA",
                specifications: "127 mm Maksutov-Cassegrain • f/15",
                notes: "Compact BRESSER lunar and planetary telescope."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0421",
                name: "AT72EDII",
                brand: "Astro-Tech",
                modelName: "AT72EDII",
                apertureMillimeters: 72,
                focalLengthMillimeters: 430,
                mountDescription: "ED refractor OTA",
                specifications: "FPL-53 ED doublet refractor • f/6",
                notes: "Popular small Astro-Tech refractor for imaging and travel."
            ),
            telescopeSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0422",
                name: "FRA400",
                brand: "Askar",
                modelName: "FRA400",
                apertureMillimeters: 72,
                focalLengthMillimeters: 400,
                mountDescription: "Quintuplet astrograph OTA",
                specifications: "Petzval-style flat-field astrograph • f/5.6",
                notes: "Wide-field Askar astrograph for deep-sky imaging."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0423",
                name: "Ethos 21",
                brand: "Tele Vue",
                modelName: "Ethos 21 mm",
                category: .eyepiece,
                eyepieceFocalLengthMillimeters: 21,
                apparentFieldOfViewDegrees: 100,
                specifications: "2 in ultra-wide eyepiece",
                notes: "Large true-field premium Tele Vue eyepiece."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0424",
                name: "Delos 17.3",
                brand: "Tele Vue",
                modelName: "Delos 17.3 mm",
                category: .eyepiece,
                eyepieceFocalLengthMillimeters: 17.3,
                apparentFieldOfViewDegrees: 72,
                specifications: "1.25 in / 2 in long eye relief eyepiece",
                notes: "Premium medium-power visual eyepiece."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0425",
                name: "Panoptic 35",
                brand: "Tele Vue",
                modelName: "Panoptic 35 mm",
                category: .eyepiece,
                eyepieceFocalLengthMillimeters: 35,
                apparentFieldOfViewDegrees: 68,
                specifications: "2 in wide-field eyepiece",
                notes: "Classic low-power Tele Vue eyepiece."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0426",
                name: "Morpheus 12.5",
                brand: "Baader Planetarium",
                modelName: "Morpheus 12.5 mm",
                category: .eyepiece,
                eyepieceFocalLengthMillimeters: 12.5,
                apparentFieldOfViewDegrees: 76,
                specifications: "1.25 in / 2 in wide-field eyepiece",
                notes: "Baader long-eye-relief eyepiece for mid-power observing."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0427",
                name: "Classic Ortho 10",
                brand: "Baader Planetarium",
                modelName: "Classic Ortho 10 mm",
                category: .eyepiece,
                eyepieceFocalLengthMillimeters: 10,
                apparentFieldOfViewDegrees: 50,
                specifications: "1.25 in orthoscopic eyepiece",
                notes: "Planetary-style eyepiece with simple optical design."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0428",
                name: "100 Degree 9 mm",
                brand: "Explore Scientific",
                modelName: "100 Degree Series 9 mm",
                category: .eyepiece,
                eyepieceFocalLengthMillimeters: 9,
                apparentFieldOfViewDegrees: 100,
                specifications: "2 in ultra-wide eyepiece",
                notes: "High-power Explore Scientific ultra-wide eyepiece."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0429",
                name: "Series 5000 UWA 5.5",
                brand: "Meade",
                modelName: "Series 5000 Ultra Wide Angle 5.5 mm",
                category: .eyepiece,
                eyepieceFocalLengthMillimeters: 5.5,
                apparentFieldOfViewDegrees: 82,
                specifications: "Legacy ultra-wide eyepiece",
                notes: "Legacy Meade high-power eyepiece often found used."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0430",
                name: "Series 4000 #140 Barlow",
                brand: "Meade",
                modelName: "#140 2x Apochromatic Barlow",
                category: .accessory,
                accessoryDetails: "Legacy Barlow lens",
                specifications: "1.25 in 2x apochromatic Barlow",
                notes: "Legacy Meade accessory still common on the used market."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0431",
                name: "f/6.3 Focal Reducer",
                brand: "Meade",
                modelName: "f/6.3 Focal Reducer / Field Flattener",
                category: .accessory,
                accessoryDetails: "Legacy reducer / field flattener",
                specifications: "0.63x SCT reducer for compatible Meade SCT / ACF systems",
                notes: "Legacy Meade reducer often available used."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0432",
                name: "ASI533MM Pro",
                brand: "ZWO",
                modelName: "ASI533MM Pro",
                category: .camera,
                sensorName: "Sony IMX533 mono • 3008 x 3008 max pixels • 9.0 MP • 3.76 um pixels",
                specifications: "Cooled monochrome astronomy camera",
                notes: "Square-format mono camera for LRGB and narrowband imaging."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0433",
                name: "ASI2600MC Duo",
                brand: "ZWO",
                modelName: "ASI2600MC Duo",
                category: .camera,
                sensorName: "Sony IMX571 color APS-C imaging sensor plus integrated guide sensor • 6248 x 4176 max imaging pixels",
                specifications: "Cooled one-shot color camera with built-in guide camera",
                notes: "Reduces external guide-scope hardware in supported imaging trains."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0434",
                name: "ASI678MC",
                brand: "ZWO",
                modelName: "ASI678MC",
                category: .camera,
                sensorName: "Sony STARVIS 2 IMX678 color • 3840 x 2160 max pixels • 8.3 MP",
                specifications: "Planetary and lunar color astronomy camera",
                notes: "Small-pixel camera also useful for guiding and compact targets."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0435",
                name: "ASI174MM Mini",
                brand: "ZWO",
                modelName: "ASI174MM Mini",
                category: .camera,
                sensorName: "Sony IMX174 mono • 1936 x 1216 max pixels • 2.3 MP",
                specifications: "Mini guide camera",
                notes: "Guide camera often paired with off-axis guiders."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0436",
                name: "QHY294M Pro",
                brand: "QHYCCD",
                modelName: "QHY294M Pro",
                category: .camera,
                sensorName: "Sony IMX492 mono 4/3 format • 4164 x 2796 and unlocked high-resolution modes",
                specifications: "Cooled monochrome astronomy camera",
                notes: "Flexible QHY mono CMOS camera for deep-sky imaging."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0437",
                name: "Ares-C Pro",
                brand: "Player One Astronomy",
                modelName: "Ares-C Pro",
                category: .camera,
                sensorName: "Sony IMX533 color • 3008 x 3008 max pixels • 9.0 MP",
                specifications: "Cooled one-shot color astronomy camera",
                notes: "Player One square-format cooled camera."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0438",
                name: "EOS 60Da",
                brand: "Canon",
                modelName: "EOS 60Da",
                category: .camera,
                sensorName: "Modified APS-C DSLR sensor • 5184 x 3456 max pixels • 18 MP",
                specifications: "Legacy astrophotography DSLR",
                notes: "Discontinued Canon astronomy DSLR still common used."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0439",
                name: "D810A",
                brand: "Nikon",
                modelName: "D810A",
                category: .camera,
                sensorName: "Modified full-frame DSLR sensor • 7360 x 4912 max pixels • 36.3 MP",
                specifications: "Legacy astrophotography DSLR",
                notes: "Discontinued Nikon astronomy DSLR with H-alpha response."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0440",
                name: "CGEM II",
                brand: "Celestron",
                modelName: "CGEM II Equatorial Mount",
                category: .mount,
                mountDescription: "Computerized German equatorial mount",
                specifications: "Mid-heavy GoTo equatorial mount class",
                notes: "Celestron mount for larger visual and imaging payloads."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0441",
                name: "AZ-EQ6 Pro",
                brand: "Sky-Watcher",
                modelName: "AZ-EQ6 Pro",
                category: .mount,
                mountDescription: "Dual-mode equatorial / alt-azimuth GoTo mount",
                specifications: "Computerized multi-role mount",
                notes: "Flexible Sky-Watcher mount for visual and imaging sessions."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0442",
                name: "CQ350 Pro",
                brand: "Sky-Watcher",
                modelName: "CQ350 Pro",
                category: .mount,
                mountDescription: "Computerized equatorial mount",
                specifications: "High-capacity Sky-Watcher GoTo mount",
                notes: "Large-payload imaging mount."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0443",
                name: "HEM27",
                brand: "iOptron",
                modelName: "HEM27",
                category: .mount,
                mountDescription: "Hybrid harmonic drive equatorial mount",
                specifications: "Portable strain-wave mount",
                notes: "Lightweight iOptron mount for travel imaging rigs."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0444",
                name: "HAE43",
                brand: "iOptron",
                modelName: "HAE43",
                category: .mount,
                mountDescription: "Harmonic drive equatorial / alt-azimuth mount",
                specifications: "Mid-capacity strain-wave mount",
                notes: "Portable mount for larger refractors and imaging payloads."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0445",
                name: "CEM120",
                brand: "iOptron",
                modelName: "CEM120",
                category: .mount,
                mountDescription: "Center-balanced observatory-class equatorial mount",
                specifications: "High-capacity observatory mount",
                notes: "Large iOptron mount for permanent or semi-permanent setups."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0446",
                name: "Paramount MYT",
                brand: "Software Bisque",
                modelName: "Paramount MYT",
                category: .mount,
                mountDescription: "Robotic German equatorial mount",
                specifications: "Portable premium robotic mount",
                notes: "TheSky-integrated mount for imaging and observatory workflows."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0447",
                name: "GM1000HPS",
                brand: "10Micron",
                modelName: "GM1000HPS",
                category: .mount,
                mountDescription: "High-precision absolute-encoder equatorial mount",
                specifications: "Premium imaging mount with model-based tracking",
                notes: "High-end mount for unguided and precision imaging workflows."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0448",
                name: "OAG-L",
                brand: "ZWO",
                modelName: "OAG-L",
                category: .accessory,
                accessoryDetails: "Off-axis guider",
                specifications: "Large-prism off-axis guider for imaging trains",
                notes: "Guiding accessory for larger sensors and filter wheels."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0449",
                name: "Off-Axis Guider",
                brand: "Celestron",
                modelName: "Off-Axis Guider",
                category: .accessory,
                accessoryDetails: "Off-axis guider",
                specifications: "Guiding accessory for SCT, EdgeHD, and imaging systems",
                notes: "Common Celestron guiding adapter."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0450",
                name: "UHC Filter",
                brand: "Lumicon",
                modelName: "UHC",
                category: .filterSystem,
                filterDescription: "Ultra high contrast nebula filter",
                specifications: "Visual nebula contrast filter",
                notes: "Classic visual filter for emission nebulae."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0451",
                name: "UHC Filter",
                brand: "Astronomik",
                modelName: "UHC",
                category: .filterSystem,
                filterDescription: "Ultra high contrast nebula filter",
                specifications: "Visual / imaging nebula contrast filter",
                notes: "Common Astronomik nebula filter."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0452",
                name: "L-Pro",
                brand: "Optolong",
                modelName: "L-Pro",
                category: .filterSystem,
                filterDescription: "Broadband light-pollution suppression filter",
                specifications: "Multi-bandpass imaging filter",
                notes: "Common broadband OSC imaging filter."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0453",
                name: "ColorMagic D1/D2 Set",
                brand: "Askar",
                modelName: "ColorMagic D1 / D2",
                category: .filterSystem,
                filterDescription: "Dual narrowband filter pair",
                specifications: "OSC dual-band filter set for HOO / SHO-style workflows",
                notes: "Filter pair for color-camera nebula imaging."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0454",
                name: "TheSky Professional",
                brand: "Software Bisque",
                modelName: "TheSky Professional",
                category: .accessory,
                accessoryDetails: "Planetarium, telescope control, and imaging support software",
                specifications: "macOS-capable planning and observatory control suite",
                notes: "Useful for advanced telescope control and target planning."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0455",
                name: "Stellarium",
                brand: "Stellarium",
                modelName: "Stellarium",
                category: .accessory,
                accessoryDetails: "Planetarium software",
                specifications: "macOS-capable open-source sky simulation and telescope-control workflow",
                notes: "Useful for visual sky review and planning."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0456",
                name: "Starry Night Pro Plus",
                brand: "Simulation Curriculum",
                modelName: "Starry Night Pro Plus",
                category: .accessory,
                accessoryDetails: "Planetarium and observing-planning software",
                specifications: "macOS-capable sky simulation and planning application",
                notes: "General astronomy planning software."
            ),
            classicSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0457",
                name: "Planetary System Stacker",
                brand: "Planetary System Stacker",
                modelName: "Planetary System Stacker",
                category: .accessory,
                accessoryDetails: "Planetary and lunar image stacking software",
                specifications: "macOS-capable stacking workflow for planetary, lunar, and solar imaging",
                notes: "Useful for high-frame-rate planetary processing."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0101")!,
                name: "Vespera II",
                brand: "Vaonis",
                modelName: "Vespera II",
                category: .smartTelescope,
                apertureMillimeters: 50,
                focalLengthMillimeters: 250,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "Sony IMX585 color • 3840 x 2160 max pixels • 8.3 MP native • 24 MP max CovalENS",
                filterDescription: "",
                mountDescription: "Automated alt-az smart mount",
                integratedComponents: "Built-in camera, autofocus, live mosaic capture, onboard storage",
                accessoryDetails: "",
                specifications: "4 hr battery • 25 GB storage • Altitude: observing min/max not published; manual documents 90 degree solar setup and 110 degree service positions",
                notes: "Compact all-in-one smart telescope."
            ),
            smartSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0131",
                name: "Vespera II X Edition",
                brand: "Vaonis",
                modelName: "Vespera II X Edition",
                apertureMillimeters: 50,
                focalLengthMillimeters: 250,
                sensorName: "Sony IMX585 color • 3840 x 2160 max pixels • 8.3 MP native • 24 MP max CovalENS",
                filterDescription: "Compatible with Vespera II filter accessories",
                mountDescription: "Automated alt-az smart mount",
                integratedComponents: "Built-in camera, autofocus, live mosaic capture, onboard storage, built-in hygrometer",
                specifications: "Limited collector edition of Vespera II • includes high-carbon tripod and hard case • functionally same optics/software as Vespera II",
                notes: "Vaonis limited transparent-shell Vespera II edition for owners who want the exact model in the database."
            ),
            smartSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0132",
                name: "Vespera 3",
                brand: "Vaonis",
                modelName: "Vespera 3",
                apertureMillimeters: 50,
                focalLengthMillimeters: 245,
                sensorName: "Sony IMX585 color • 3840 x 2160 max pixels • 8.3 MP native • 24 MP max mosaic",
                filterDescription: "Optical baffle and compatible Vaonis filter accessories",
                mountDescription: "Automated alt-az smart mount",
                integratedComponents: "Autofocus, live stacking, mosaic mode, automatic multi-night capture, dew control, USB-C transfer",
                specifications: "50 mm flat-field apochromatic quadruplet • f/4.9 • 2.6 x 1.4 degree native FOV • 115 GB storage • 11 hr battery • 5 kg",
                notes: "Current Vaonis 2026 Vespera generation."
            ),
            smartSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0133",
                name: "Vespera Pro 2",
                brand: "Vaonis",
                modelName: "Vespera Pro 2",
                apertureMillimeters: 50,
                focalLengthMillimeters: 245,
                sensorName: "Sony IMX676 color • 3536 x 3536 max pixels • 12.5 MP native • 50 MP max mosaic",
                filterDescription: "Optical baffle and compatible Vaonis filter accessories",
                mountDescription: "Automated alt-az smart mount",
                integratedComponents: "Autofocus, live stacking, mosaic mode, automatic multi-night capture, dew control, USB-C transfer, BalENS processing",
                specifications: "50 mm flat-field apochromatic quadruplet • f/4.9 • 1.6 x 1.6 degree native FOV • 225 GB storage • 11 hr battery • 5 kg",
                notes: "Highest-definition current Vaonis Vespera smart telescope."
            ),
            smartSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0134",
                name: "Hyperia",
                brand: "Vaonis",
                modelName: "Hyperia",
                apertureMillimeters: 150,
                focalLengthMillimeters: 600,
                sensorName: "Full-frame back-illuminated sensor • 45 MP • 3.30 x 2.20 degree field of view",
                filterDescription: "Integrated filter drawer",
                mountDescription: "Professional direct-drive smart observatory mount with field derotator",
                integratedComponents: "Canon-derived 17-lens optical system, direct-drive tracking, field derotator, smart observatory app, AI companion",
                specifications: "150 mm aperture • f/4, approximately 600 mm focal length • public-outreach smart observatory • limited production, deliveries beginning 2027",
                notes: "Institutional and public-outreach Vaonis smart observatory; included for completeness, not typical portable-field use."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0102")!,
                name: "Odyssey Pro",
                brand: "Unistellar",
                modelName: "Odyssey Pro",
                category: .smartTelescope,
                apertureMillimeters: 85,
                focalLengthMillimeters: 320,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "Nikon eyepiece technology • 1.45 micrometer pixels • 33.6 x 45 arcmin field of view",
                filterDescription: "",
                mountDescription: "Motorized alt-az smart mount",
                integratedComponents: "Nikon eyepiece, autofocus, app control, autonomous pointing, live processing, 64 GB storage",
                accessoryDetails: "",
                specifications: "85 mm mirror • 320 mm focal length • f/3.9 • limiting magnitude 17.2 • 5 hr battery • 4 kg telescope weight",
                notes: "Smart eyepiece-assisted observing system."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0103")!,
                name: "Seestar S50",
                brand: "ZWO",
                modelName: "Seestar S50",
                category: .smartTelescope,
                apertureMillimeters: 50,
                focalLengthMillimeters: 250,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "Sony IMX462 color • 1920 x 1080 max pixels • 2.1 MP",
                filterDescription: "Built-in duo-band light-pollution filter and solar-filter support",
                mountDescription: "Automated alt-az smart mount",
                integratedComponents: "Camera, ASIAIR control, dew heater, filter wheel, Wi-Fi, live stacking, 64 GB storage",
                accessoryDetails: "",
                specifications: "50 mm triplet apochromat • 250 mm focal length • f/5 • 6000 mAh battery • 2.5 kg all-in-one smart telescope",
                notes: "Compact portable smart telescope."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0111")!,
                name: "Seestar S30",
                brand: "ZWO",
                modelName: "Seestar S30",
                category: .smartTelescope,
                apertureMillimeters: 30,
                focalLengthMillimeters: 150,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "Sony IMX662 tele color • 1080 x 1920 max pixels • 2.1 MP; wide camera 1920 x 1080",
                filterDescription: "Built-in dark-field, UV/IR cut, and astronomical light-pollution filters; magnetic solar filter",
                mountDescription: "Automated alt-az smart mount",
                integratedComponents: "Triplet apochromatic optics, autofocus, dew heater, Wi-Fi, live stacking",
                accessoryDetails: "",
                specifications: "30 mm triplet apochromat • 150 mm focal length • f/5 • 64 GB eMMC • 6000 mAh battery • 1.65 kg",
                notes: "Smaller Seestar smart telescope for portable wide-field observing."
            ),
            smartSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0135",
                name: "Seestar S30 Pro",
                brand: "ZWO",
                modelName: "Seestar S30 Pro",
                apertureMillimeters: 30,
                focalLengthMillimeters: 160,
                sensorName: "Tele Sony IMX585 • 2160 x 3840 • 8.3 MP; wide Sony IMX586 • 2160 x 3840 • 8.3 MP",
                filterDescription: "Built-in UV/IR cut, astronomical light-pollution, and dark-field filters; magnetic solar filter",
                mountDescription: "Automated alt-az smart mount with equatorial-mode support",
                integratedComponents: "4-element apochromatic lens, dual 4K cameras, autofocus, Wi-Fi, USB-C, Bluetooth, plan mode, mosaic modes, 128 GB eMMC",
                specifications: "30 mm tele lens • 160 mm focal length • f/5.3 • tele FOV 4.6 degrees • 6000 mAh battery with 6 hr lab runtime • 1.65 kg",
                notes: "Current higher-resolution Seestar S30 variant."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0104")!,
                name: "DWARF 3",
                brand: "DWARFLAB",
                modelName: "DWARF 3",
                category: .smartTelescope,
                apertureMillimeters: 35,
                focalLengthMillimeters: 150,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "Sony IMX678 tele color • 3840 x 2160 max pixels • 8.3 MP; wide camera 1920 x 1080",
                filterDescription: "Built-in VIS, Astro, and Dual-Band filters",
                mountDescription: "Motorized tracking smart mount",
                integratedComponents: "Wide-angle and telephoto cameras, NFC pairing, star-chart GoTo, mosaic, multi-night stacking, 128 GB eMMC",
                accessoryDetails: "",
                specifications: "35 mm tele lens • 150 mm focal length • 3 degree field of view • 60 s EQ-mode exposure • 5.5 hr battery • 1.35 kg",
                notes: "Ultra-portable smart telescope and imaging system."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0112")!,
                name: "DWARF II",
                brand: "DWARFLAB",
                modelName: "DWARF II",
                category: .smartTelescope,
                apertureMillimeters: 24,
                focalLengthMillimeters: 100,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "Sony IMX415 tele color • 3840 x 2160 max pixels • 8.3 MP; wide camera 2 MP",
                filterDescription: "",
                mountDescription: "Motorized tracking smart mount",
                integratedComponents: "Wide-angle and telephoto cameras, object tracking, app control",
                accessoryDetails: "",
                specifications: "Portable dual-camera smart telescope • Altitude: Dwarflab recommends targets above 30 degrees when possible; published upper limit not found",
                notes: "Earlier compact DWARFLAB smart telescope."
            ),
            smartSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0136",
                name: "DWARF mini",
                brand: "DWARFLAB",
                modelName: "DWARF mini",
                apertureMillimeters: 30,
                focalLengthMillimeters: 150,
                sensorName: "Sony IMX662 • 1/2.8 in sensor • 2.0 micrometer pixels • 5 MP RAW support",
                filterDescription: "Built-in dark-field, Astro, and dual-band filters",
                mountDescription: "Motorized tracking smart mount with equatorial-mode support",
                integratedComponents: "Telephoto and wide-angle cameras, automatic GoTo, intelligent tracking, one-click post-processing",
                specifications: "30 mm tele lens • approximately f/5 • 90 s EQ-mode exposure • 4 hr battery • 840 g",
                notes: "Ultra-light DWARFLAB smart telescope for portable wide-field use."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0105")!,
                name: "Origin Mark II",
                brand: "Celestron",
                modelName: "Origin Mark II Intelligent Home Observatory",
                category: .smartTelescope,
                apertureMillimeters: 152,
                focalLengthMillimeters: 335,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "Sony IMX678-AAQR1 color BSI CMOS • 3856 x 2180 effective pixels • 8.3 MP • 2.0 micrometer pixels",
                filterDescription: "Integrated filter drawer accepts 1.25 in or 2 in astroimaging filters",
                mountDescription: "Automated home observatory alt-az mount",
                integratedComponents: "StarSense automation, Origin 678C camera, onboard computer, autofocus, dew prevention, live stacking",
                accessoryDetails: "",
                specifications: "6 in Rowe-Ackermann Schmidt astrograph • f/2.2 • 1.32 x 0.75 degree field of view • 97.9 Wh battery with 6+ hr use",
                notes: "Current Origin Mark II configuration; first-generation Origin systems can use the 678C camera upgrade path."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0106")!,
                name: "Solar Filter",
                brand: "Unistellar",
                modelName: "Smart Solar Filter",
                category: .smartAccessory,
                apertureMillimeters: 0,
                focalLengthMillimeters: 0,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "",
                filterDescription: "",
                mountDescription: "",
                integratedComponents: "",
                accessoryDetails: "Solar observing accessory",
                specifications: "Model-specific smart telescope solar filter",
                notes: "Accessory for supported Unistellar systems."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0107")!,
                name: "eVscope 2",
                brand: "Unistellar",
                modelName: "eVscope 2",
                category: .smartTelescope,
                apertureMillimeters: 114,
                focalLengthMillimeters: 450,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "Sony IMX347 integrated sensor • 3200 x 2400 output • 7.7 MP",
                filterDescription: "",
                mountDescription: "Motorized alt-az smart mount",
                integratedComponents: "Nikon eyepiece, live processing, 37-million-star database, 64 GB storage",
                accessoryDetails: "",
                specifications: "114 mm mirror • 450 mm focal length • f/4 • Altitude: app supports altitude/azimuth visible-sky limits; hardware min/max not published",
                notes: "Smart telescope with eyepiece-assisted observing."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0113")!,
                name: "eQuinox 2",
                brand: "Unistellar",
                modelName: "eQuinox 2",
                category: .smartTelescope,
                apertureMillimeters: 114,
                focalLengthMillimeters: 450,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "Integrated sensor • 6.2 MP output resolution",
                filterDescription: "",
                mountDescription: "Motorized alt-az smart mount",
                integratedComponents: "Enhanced Vision live processing, app control, 64 GB storage",
                accessoryDetails: "",
                specifications: "114 mm mirror • 450 mm focal length • f/4 • Altitude: app supports altitude/azimuth visible-sky limits; hardware min/max not published",
                notes: "Smart telescope without electronic eyepiece."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0114")!,
                name: "Vespera Pro",
                brand: "Vaonis",
                modelName: "Vespera Pro",
                category: .smartTelescope,
                apertureMillimeters: 50,
                focalLengthMillimeters: 250,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "Sony IMX676 color • 3536 x 3536 max pixels • 12.5 MP native • 50 MP max CovalENS",
                filterDescription: "",
                mountDescription: "Automated alt-az smart mount",
                integratedComponents: "Autofocus, live mosaic capture, integrated camera, onboard storage",
                accessoryDetails: "",
                specifications: "50 mm aperture • 250 mm focal length • Altitude: observing min/max not published; manual documents 90 degree solar setup and 110 degree service positions",
                notes: "Higher-resolution Vaonis smart telescope system."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0115")!,
                name: "Stellina",
                brand: "Vaonis",
                modelName: "Stellina",
                category: .smartTelescope,
                apertureMillimeters: 80,
                focalLengthMillimeters: 400,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "Sony color astronomy camera • 3096 x 2080 max pixels • 6.4 MP",
                filterDescription: "",
                mountDescription: "Automated alt-az smart mount",
                integratedComponents: "Autofocus, field derotation, app control, live stacking",
                accessoryDetails: "",
                specifications: "80 mm ED refractor • 400 mm focal length • Altitude: observing min/max not published; manual documents 90 degree solar setup position",
                notes: "Larger Vaonis automated smart telescope."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0108")!,
                name: "Vespera Dual Band Filter",
                brand: "Vaonis",
                modelName: "Dual Band Filter",
                category: .smartAccessory,
                apertureMillimeters: 0,
                focalLengthMillimeters: 0,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "",
                filterDescription: "Dual-band nebula filter accessory",
                mountDescription: "",
                integratedComponents: "",
                accessoryDetails: "Smart telescope filter accessory",
                specifications: "Accessory filter for compatible Vespera systems",
                notes: "Useful for emission nebula imaging with Vaonis smart telescopes."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0109")!,
                name: "Seestar S50 Solar Filter",
                brand: "ZWO",
                modelName: "Seestar S50 Solar Filter",
                category: .smartAccessory,
                apertureMillimeters: 0,
                focalLengthMillimeters: 0,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "",
                filterDescription: "White-light solar filter accessory",
                mountDescription: "",
                integratedComponents: "",
                accessoryDetails: "Solar filter for Seestar S50",
                specifications: "Model-specific solar observing accessory",
                notes: "For supported Seestar solar observing workflows."
            ),
            EquipmentSeedRecord(
                id: UUID(uuidString: "0B7D2192-7462-4E7F-8F7A-36A74E1C0110")!,
                name: "Origin Nebula Filter",
                brand: "Celestron",
                modelName: "Origin Nebula Filter",
                category: .smartAccessory,
                apertureMillimeters: 0,
                focalLengthMillimeters: 0,
                eyepieceFocalLengthMillimeters: nil,
                apparentFieldOfViewDegrees: nil,
                sensorName: "",
                filterDescription: "Nebula filter accessory",
                mountDescription: "",
                integratedComponents: "",
                accessoryDetails: "Filter accessory for Celestron Origin systems",
                specifications: "Model-specific smart observatory filter",
                notes: "Accessory for improving nebula contrast in supported Origin systems."
            ),
            smartSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0121",
                name: "Odyssey",
                brand: "Unistellar",
                modelName: "Odyssey",
                apertureMillimeters: 85,
                focalLengthMillimeters: 320,
                sensorName: "Integrated color digital sensor • exact bundled resolution not published",
                mountDescription: "Automated smart mount",
                integratedComponents: "Autonomous pointing, app control, live processing",
                specifications: "All-in-one portable smart telescope • Altitude: app supports visible-sky limits; hardware min/max not published",
                notes: "Non-eyepiece Odyssey smart telescope system."
            ),
            smartSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0122",
                name: "eVscope",
                brand: "Unistellar",
                modelName: "eVscope",
                apertureMillimeters: 114,
                focalLengthMillimeters: 450,
                sensorName: "Integrated digital sensor • first-generation eVscope output resolution varies by model documentation",
                mountDescription: "Motorized alt-az smart mount",
                integratedComponents: "Enhanced Vision live processing, electronic eyepiece, app control",
                specifications: "114 mm mirror • 450 mm focal length • legacy smart telescope",
                notes: "Earlier Unistellar smart telescope often available used."
            ),
            smartSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0123",
                name: "eQuinox",
                brand: "Unistellar",
                modelName: "eQuinox",
                apertureMillimeters: 114,
                focalLengthMillimeters: 450,
                sensorName: "Integrated digital sensor • first-generation eQuinox output resolution varies by model documentation",
                mountDescription: "Motorized alt-az smart mount",
                integratedComponents: "Enhanced Vision live processing, app control, onboard storage",
                specifications: "114 mm mirror • 450 mm focal length • legacy smart telescope",
                notes: "Earlier Unistellar no-eyepiece smart telescope."
            ),
            smartSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0124",
                name: "Vespera",
                brand: "Vaonis",
                modelName: "Vespera",
                apertureMillimeters: 50,
                focalLengthMillimeters: 200,
                sensorName: "Sony IMX462 color • 1920 x 1080 max pixels • 2.1 MP native • CovalENS mosaic support",
                mountDescription: "Automated alt-az smart mount",
                integratedComponents: "Autofocus, live stacking, app control, mosaic capture",
                specifications: "50 mm apochromatic refractor smart telescope • Altitude: observing min/max not published",
                notes: "Original compact Vaonis Vespera platform."
            ),
            smartSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0125",
                name: "Hestia",
                brand: "Vaonis",
                modelName: "Hestia",
                category: .smartAccessory,
                apertureMillimeters: 30,
                focalLengthMillimeters: 0,
                sensorName: "Uses compatible smartphone camera sensor",
                mountDescription: "Manual tabletop smartphone observing platform",
                integratedComponents: "Optical smartphone adapter and Gravity app workflow",
                accessoryDetails: "Smartphone telescope accessory",
                specifications: "Phone-based Vaonis observing system",
                notes: "Listed as a smart accessory because it depends on a phone camera instead of an integrated telescope sensor."
            ),
            smartSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0126",
                name: "Vespera CLS Filter",
                brand: "Vaonis",
                modelName: "CLS Filter",
                category: .smartAccessory,
                filterDescription: "City light suppression filter accessory",
                accessoryDetails: "Smart telescope light-pollution filter",
                specifications: "Compatible with selected Vespera systems",
                notes: "Useful for broadband contrast improvement from light-polluted sites."
            ),
            smartSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0127",
                name: "Vespera Solar Filter",
                brand: "Vaonis",
                modelName: "Solar Filter",
                category: .smartAccessory,
                filterDescription: "White-light solar filter accessory",
                accessoryDetails: "Smart telescope solar observing filter",
                specifications: "Compatible with selected Vespera systems",
                notes: "Solar accessory for supported Vaonis workflows."
            ),
            smartSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0128",
                name: "Unistellar Backpack",
                brand: "Unistellar",
                modelName: "Backpack",
                category: .smartAccessory,
                accessoryDetails: "Transport case / backpack",
                specifications: "Carry accessory for compatible Unistellar smart telescopes",
                notes: "Travel accessory for smart telescope sessions."
            ),
            smartSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0129",
                name: "Seestar S30 Solar Filter",
                brand: "ZWO",
                modelName: "Seestar S30 Solar Filter",
                category: .smartAccessory,
                filterDescription: "White-light solar filter accessory",
                accessoryDetails: "Solar filter for Seestar S30",
                specifications: "Model-specific solar observing accessory",
                notes: "For supported Seestar S30 solar observing workflows."
            ),
            smartSeedRecord(
                id: "0B7D2192-7462-4E7F-8F7A-36A74E1C0130",
                name: "DWARF 3 Magnetic Solar Filters",
                brand: "DWARFLAB",
                modelName: "Magnetic Solar Filters",
                category: .smartAccessory,
                filterDescription: "Magnetic solar filters",
                accessoryDetails: "Solar filter set for DWARF 3",
                specifications: "Model-specific solar filter accessory",
                notes: "Solar imaging accessory for DWARF 3."
            )
        ].filter { $0.category.catalogGroup == .smartTelescope }
    }

    static func groupedRecords(from profiles: [EquipmentProfile]) -> [EquipmentCatalogGroup: [EquipmentProfile]] {
        Dictionary(grouping: profiles) { $0.catalogGroup }
    }

    static func sortedProfiles(_ profiles: [EquipmentProfile]) -> [EquipmentProfile] {
        profiles.sorted {
            if $0.catalogGroup == $1.catalogGroup {
                if $0.category == $1.category {
                    return $0.groupedDisplayName.localizedStandardCompare($1.groupedDisplayName) == .orderedAscending
                }
                return categorySortRank($0.category) < categorySortRank($1.category)
            }
            return $0.catalogGroup.displayName.localizedStandardCompare($1.catalogGroup.displayName) == .orderedAscending
        }
    }

    private static func categorySortRank(_ category: EquipmentCategory) -> Int {
        switch category {
        case .telescope, .smartTelescope:
            0
        case .mount:
            1
        case .camera:
            2
        case .eyepiece:
            3
        case .filterSystem:
            4
        case .accessory, .smartAccessory:
            5
        }
    }

    private static func stampRefreshDate(_ date: Date, for group: EquipmentCatalogGroup, defaults: UserDefaults = .standard) {
        switch group {
        case .classic:
            break
        case .smartTelescope:
            defaults.set(date, forKey: smartRefreshKey)
        }
    }

    private static func initialInstallDate(defaults: UserDefaults = .standard, now: Date = .now) -> Date {
        if let date = defaults.object(forKey: initialInstallDateKey) as? Date {
            return date
        }

        defaults.set(now, forKey: initialInstallDateKey)
        return now
    }

    private static func applyRecords(_ records: [EquipmentSeedRecord], context: ModelContext) throws {
        let existingProfiles = try context.fetch(FetchDescriptor<EquipmentProfile>())
        let existingByID = Dictionary(uniqueKeysWithValues: existingProfiles.map { ($0.id, $0) })

        for record in records {
            if let existing = existingByID[record.id] {
                existing.name = record.name
                existing.brand = record.brand
                existing.modelName = record.modelName
                existing.category = record.category
                existing.apertureMillimeters = record.apertureMillimeters
                existing.focalLengthMillimeters = record.focalLengthMillimeters
                existing.eyepieceFocalLengthMillimeters = record.eyepieceFocalLengthMillimeters
                existing.apparentFieldOfViewDegrees = record.apparentFieldOfViewDegrees
                existing.sensorName = record.sensorName
                existing.filterDescription = record.filterDescription
                existing.mountDescription = record.mountDescription
                existing.integratedComponents = record.integratedComponents
                existing.accessoryDetails = record.accessoryDetails
                existing.specifications = record.specifications
                existing.notes = record.notes
            } else {
                context.insert(
                    EquipmentProfile(
                        id: record.id,
                        name: record.name,
                        brand: record.brand,
                        modelName: record.modelName,
                        catalogGroup: record.category.catalogGroup,
                        category: record.category,
                        apertureMillimeters: record.apertureMillimeters,
                        focalLengthMillimeters: record.focalLengthMillimeters,
                        eyepieceFocalLengthMillimeters: record.eyepieceFocalLengthMillimeters,
                        apparentFieldOfViewDegrees: record.apparentFieldOfViewDegrees,
                        sensorName: record.sensorName,
                        filterDescription: record.filterDescription,
                        mountDescription: record.mountDescription,
                        integratedComponents: record.integratedComponents,
                        accessoryDetails: record.accessoryDetails,
                        specifications: record.specifications,
                        notes: record.notes
                    )
                )
            }
        }

        try context.save()
    }

    private static func removeClassicEquipmentData(context: ModelContext) throws {
        var didDeleteData = false

        for profile in try context.fetch(FetchDescriptor<EquipmentProfile>())
        where profile.catalogGroup != .smartTelescope || profile.category.catalogGroup != .smartTelescope {
            context.delete(profile)
            didDeleteData = true
        }

        for configuration in try context.fetch(FetchDescriptor<DefaultEquipmentConfiguration>())
        where configuration.catalogGroup != .smartTelescope {
            context.delete(configuration)
            didDeleteData = true
        }

        for configuration in try context.fetch(FetchDescriptor<SavedEquipmentConfiguration>())
        where configuration.catalogGroup != .smartTelescope {
            context.delete(configuration)
            didDeleteData = true
        }

        if didDeleteData {
            try context.save()
        }
    }
}
