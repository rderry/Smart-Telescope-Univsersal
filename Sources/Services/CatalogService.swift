import Foundation
import SwiftData

struct CatalogSeedRecord: Codable {
    let catalogID: String
    let commonName: String
    let primaryDesignation: String
    let catalogFamily: CatalogFamily
    let alternateDesignations: [String]
    let objectType: DSOType
    let constellation: String
    let rightAscensionHours: Double
    let declinationDegrees: Double
    let magnitude: Double
    let angularSizeArcMinutes: Double
    let surfaceBrightness: Double?
}

enum CatalogService {
    private static let openNGCCatalogURL = URL(string: "https://raw.githubusercontent.com/mattiaverga/OpenNGC/master/database_files/NGC.csv")!
    private static let openNGCAddendumURL = URL(string: "https://raw.githubusercontent.com/mattiaverga/OpenNGC/master/database_files/addendum.csv")!
    private static let openNGCSourceName = "OpenNGC / BigSkyAstro Local Common Catalog"
    private static let openNGCSourceURL = "https://github.com/mattiaverga/OpenNGC"
    private static let session = RemoteServiceSessionFactory.makeSession(
        timeoutIntervalForRequest: 15,
        timeoutIntervalForResource: 30
    )

    @MainActor
    static func bootstrapCatalogIfNeeded(context: ModelContext) throws {
        try applyRecords(bundledCatalogRecords(), context: context)
    }

    static func bundledCatalogRecords() throws -> [CatalogSeedRecord] {
        guard let url = AppResourceBundle.current.url(forResource: "dso_catalog", withExtension: "json") else { return [] }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([CatalogSeedRecord].self, from: data)
    }

    @MainActor
    static func refreshCatalogFromInternet(context: ModelContext) async throws {
        let remoteRecords = try await remoteCatalogRecords()
        let mergedRecords = merge(remoteRecords: remoteRecords, withBundledFallback: try bundledCatalogRecords())
        try applyRecords(mergedRecords, context: context, pruneMissingUnreferenced: true)
    }

    static func remoteCatalogRecords() async throws -> [CatalogSeedRecord] {
        async let catalogRecords = remoteCatalogRecords(from: openNGCCatalogURL)
        async let addendumRecords = remoteCatalogRecords(from: openNGCAddendumURL)

        let primaryRecords = try await catalogRecords
        let supplementalRecords = try await addendumRecords
        return mergeDownloadedRecords(primaryRecords + supplementalRecords)
    }

    private static func remoteCatalogRecords(from url: URL) async throws -> [CatalogSeedRecord] {
        var request = URLRequest(url: url)
        request.setValue("SmartScopeObservationPlanner/1.0 BigSkyAstro", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw CatalogRefreshError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw CatalogRefreshError.requestFailed(statusCode: httpResponse.statusCode)
        }

        return OpenNGCRemoteCatalogParser().parseCatalogRecords(from: data)
    }

    private static func mergeDownloadedRecords(_ records: [CatalogSeedRecord]) -> [CatalogSeedRecord] {
        Dictionary(grouping: records, by: \.catalogID)
            .compactMap { _, groupedRecords in
                groupedRecords.sorted {
                    if $0.catalogFamily == $1.catalogFamily {
                        return $0.primaryDesignation.localizedStandardCompare($1.primaryDesignation) == .orderedAscending
                    }

                    return $0.catalogFamily.displayName.localizedStandardCompare($1.catalogFamily.displayName) == .orderedAscending
                }
                .first
            }
            .sorted {
                if $0.catalogFamily == $1.catalogFamily {
                    return $0.catalogID.localizedStandardCompare($1.catalogID) == .orderedAscending
                }

                return $0.catalogFamily.displayName.localizedStandardCompare($1.catalogFamily.displayName) == .orderedAscending
            }
    }

    static func merge(
        remoteRecords: [CatalogSeedRecord],
        withBundledFallback bundledRecords: [CatalogSeedRecord]
    ) -> [CatalogSeedRecord] {
        var recordsByID = Dictionary(uniqueKeysWithValues: remoteRecords.map { ($0.catalogID, $0) })

        for bundledRecord in bundledRecords {
            if let remoteRecord = recordsByID[bundledRecord.catalogID] {
                recordsByID[bundledRecord.catalogID] = mergedRecord(remote: remoteRecord, bundled: bundledRecord)
            } else {
                recordsByID[bundledRecord.catalogID] = bundledRecord
            }
        }

        return recordsByID.values.sorted {
            if $0.catalogFamily == $1.catalogFamily {
                return $0.catalogID.localizedStandardCompare($1.catalogID) == .orderedAscending
            }

            return $0.catalogFamily.displayName.localizedStandardCompare($1.catalogFamily.displayName) == .orderedAscending
        }
    }

    @MainActor
    static func applyRecords(
        _ records: [CatalogSeedRecord],
        context: ModelContext,
        pruneMissingUnreferenced: Bool = false
    ) throws {
        let existingObjects = try context.fetch(FetchDescriptor<DSOObject>())
        let referencedCatalogIDs = try referencedCatalogIDs(context: context)
        let incomingCatalogIDs = Set(records.map(\.catalogID))

        for object in existingObjects
        where !referencedCatalogIDs.contains(object.catalogID) && !object.isLocallyRetained {
            if !MagnitudeVisibilityPolicy.allows(magnitude: object.magnitude)
                || (pruneMissingUnreferenced && !incomingCatalogIDs.contains(object.catalogID)) {
                context.delete(object)
            }
        }

        let visibleRecords = records.filter { MagnitudeVisibilityPolicy.allows(magnitude: $0.magnitude) }
        let visibleExistingObjects = try context.fetch(FetchDescriptor<DSOObject>())
        let existingByID = Dictionary(uniqueKeysWithValues: visibleExistingObjects.map { ($0.catalogID, $0) })

        for record in visibleRecords {
            if let existing = existingByID[record.catalogID] {
                existing.commonName = record.commonName
                existing.primaryDesignation = record.primaryDesignation
                existing.catalogFamily = record.catalogFamily
                existing.alternateDesignations = record.alternateDesignations
                existing.objectType = record.objectType
                existing.constellation = record.constellation
                existing.rightAscensionHours = record.rightAscensionHours
                existing.declinationDegrees = record.declinationDegrees
                existing.magnitude = record.magnitude
                existing.angularSizeArcMinutes = record.angularSizeArcMinutes
                existing.surfaceBrightness = record.surfaceBrightness
                existing.sourceName = sourceName(for: record)
                existing.sourceURLString = sourceURLString(for: record)
            } else {
                context.insert(
                    DSOObject(
                        catalogID: record.catalogID,
                        commonName: record.commonName,
                        primaryDesignation: record.primaryDesignation,
                        catalogFamily: record.catalogFamily,
                        alternateDesignations: record.alternateDesignations,
                        objectType: record.objectType,
                        constellation: record.constellation,
                        rightAscensionHours: record.rightAscensionHours,
                        declinationDegrees: record.declinationDegrees,
                        magnitude: record.magnitude,
                        angularSizeArcMinutes: record.angularSizeArcMinutes,
                        surfaceBrightness: record.surfaceBrightness,
                        sourceName: sourceName(for: record),
                        sourceURLString: sourceURLString(for: record)
                    )
                )
            }
        }

        try context.save()
    }

    private static func sourceName(for record: CatalogSeedRecord) -> String {
        switch record.catalogFamily {
        case .messier, .ngc, .caldwell, .ic, .sharpless2, .lbn, .openNGCAddendum:
            openNGCSourceName
        }
    }

    private static func sourceURLString(for record: CatalogSeedRecord) -> String {
        switch record.catalogFamily {
        case .messier, .ngc, .caldwell, .ic, .sharpless2, .lbn, .openNGCAddendum:
            openNGCSourceURL
        }
    }

    private static func mergedRecord(remote: CatalogSeedRecord, bundled: CatalogSeedRecord) -> CatalogSeedRecord {
        let commonName = bundled.commonName.isEmpty ? remote.commonName : bundled.commonName
        let primaryDesignation = bundled.primaryDesignation.isEmpty ? remote.primaryDesignation : bundled.primaryDesignation
        let constellation = bundled.constellation.count > remote.constellation.count ? bundled.constellation : remote.constellation
        let alternateDesignations = deduplicatedDesignations(
            bundled.alternateDesignations + remote.alternateDesignations + [bundled.catalogID, remote.catalogID]
        )

        return CatalogSeedRecord(
            catalogID: remote.catalogID,
            commonName: commonName,
            primaryDesignation: primaryDesignation,
            catalogFamily: remote.catalogFamily,
            alternateDesignations: alternateDesignations,
            objectType: remote.objectType,
            constellation: constellation,
            rightAscensionHours: remote.rightAscensionHours,
            declinationDegrees: remote.declinationDegrees,
            magnitude: remote.magnitude,
            angularSizeArcMinutes: remote.angularSizeArcMinutes,
            surfaceBrightness: remote.surfaceBrightness ?? bundled.surfaceBrightness
        )
    }

    private static func deduplicatedDesignations(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var deduplicated: [String] = []

        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }

            let key = trimmed.lowercased()
            guard seen.insert(key).inserted else { continue }
            deduplicated.append(trimmed)
        }

        return deduplicated
    }

    @MainActor
    private static func referencedCatalogIDs(context: ModelContext) throws -> Set<String> {
        let plannedTargets = try context.fetch(FetchDescriptor<PlannedTarget>())
        let observationEntries = try context.fetch(FetchDescriptor<ObservationEntry>())

        let plannedIDs = plannedTargets.compactMap { $0.object?.catalogID }
        let loggedIDs = observationEntries.compactMap { $0.object?.catalogID }
        return Set(plannedIDs + loggedIDs)
    }
}

enum CatalogRefreshError: LocalizedError {
    case invalidResponse
    case requestFailed(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            "The live catalog service returned an unreadable response."
        case .requestFailed(let statusCode):
            "The live catalog service returned HTTP \(statusCode)."
        }
    }
}

struct OpenNGCRemoteCatalogParser {
    func parseCatalogRecords(from data: Data) -> [CatalogSeedRecord] {
        parseCatalogRecords(from: String(decoding: data, as: UTF8.self))
    }

    func parseCatalogRecords(from text: String) -> [CatalogSeedRecord] {
        let normalizedText = text.replacingOccurrences(of: "\r\n", with: "\n").replacingOccurrences(of: "\r", with: "\n")
        let lines = normalizedText
            .split(separator: "\n", omittingEmptySubsequences: true)
            .map(String.init)

        guard let headerLine = lines.first else { return [] }
        let headers = parseDelimitedLine(headerLine, delimiter: ";")
        guard !headers.isEmpty else { return [] }

        var recordsByID: [String: CatalogSeedRecord] = [:]

        for line in lines.dropFirst() {
            let values = parseDelimitedLine(line, delimiter: ";")
            let row = OpenNGCRow(headers: headers, values: values)

            guard let record = row.primaryCatalogRecord else { continue }
            recordsByID[record.catalogID] = record
        }

        return recordsByID.values.sorted { $0.catalogID.localizedStandardCompare($1.catalogID) == .orderedAscending }
    }

    func parseDelimitedLine(_ line: String, delimiter: Character) -> [String] {
        var values: [String] = []
        var current = ""
        var insideQuotes = false

        for character in line {
            if character == "\"" {
                insideQuotes.toggle()
                continue
            }

            if character == delimiter && !insideQuotes {
                values.append(current)
                current = ""
            } else {
                current.append(character)
            }
        }

        values.append(current)
        return values
    }
}

private struct OpenNGCRow {
    private let fields: [String: String]

    init(headers: [String], values: [String]) {
        var mappedFields: [String: String] = [:]

        for (index, header) in headers.enumerated() {
            mappedFields[header] = index < values.count ? values[index] : ""
        }

        fields = mappedFields
    }

    var primaryCatalogRecord: CatalogSeedRecord? {
        guard let objectType = mappedObjectType else { return nil }
        guard let magnitude = parsedMagnitude else { return nil }
        guard let rightAscensionHours = Self.parseRightAscension(fields["RA"] ?? "") else { return nil }
        guard let declinationDegrees = Self.parseDeclination(fields["Dec"] ?? "") else { return nil }
        guard let family = mappedCatalogFamily else { return nil }
        guard let catalogID = normalizedCatalogID else { return nil }

        let angularSize = max(parsedDouble("MajAx") ?? parsedDouble("MinAx") ?? 1.0, 1.0)
        let designation = normalizedPrimaryDesignation
        let alternateDesignations = Self.deduplicated([
            catalogID,
            designation,
            normalizedMessierID,
            normalizedCrossReference(prefix: "NGC", field: "NGC"),
            normalizedCrossReference(prefix: "IC", field: "IC")
        ] + splitField("Identifiers") + splitField("Common names"))

        return CatalogSeedRecord(
            catalogID: catalogID,
            commonName: primaryCommonName,
            primaryDesignation: designation,
            catalogFamily: family,
            alternateDesignations: alternateDesignations,
            objectType: objectType,
            constellation: fields["Const"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "",
            rightAscensionHours: rightAscensionHours,
            declinationDegrees: declinationDegrees,
            magnitude: magnitude,
            angularSizeArcMinutes: angularSize,
            surfaceBrightness: parsedDouble("SurfBr")
        )
    }

    private var mappedObjectType: DSOType? {
        let rawType = fields["Type"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        switch rawType {
        case "G", "GPair", "GTrpl", "GGroup":
            return .galaxy
        case "PN":
            return .planetaryNebula
        case "HII", "EmN", "Neb":
            return .emissionNebula
        case "RfN":
            return .reflectionNebula
        case "OCl", "Cl+N":
            return .openCluster
        case "*Ass":
            return .asterism
        case "GCl":
            return .globularCluster
        case "DrkN":
            return .darkNebula
        case "SNR":
            return .supernovaRemnant
        default:
            return nil
        }
    }

    private var mappedCatalogFamily: CatalogFamily? {
        if normalizedMessierID != nil {
            return .messier
        }

        if normalizedCaldwellID != nil {
            return .caldwell
        }

        if normalizedPrimaryDesignation.hasPrefix("NGC ") {
            return .ngc
        }

        if normalizedPrimaryDesignation.hasPrefix("IC ") {
            return .ic
        }

        return .openNGCAddendum
    }

    private var normalizedCatalogID: String? {
        normalizedMessierID ?? normalizedCaldwellID ?? normalizedNGCICName(fields["Name"] ?? "") ?? normalizedAddendumDesignation
    }

    private var normalizedPrimaryDesignation: String {
        normalizedNGCICName(fields["Name"] ?? "") ?? (fields["Name"] ?? "")
    }

    private var normalizedMessierID: String? {
        guard let rawValue = fields["M"]?.trimmingCharacters(in: .whitespacesAndNewlines), !rawValue.isEmpty else {
            return nil
        }

        guard let messierNumber = Int(rawValue) else { return nil }
        return "M\(messierNumber)"
    }

    private var normalizedCaldwellID: String? {
        let rawName = fields["Name"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard rawName.hasPrefix("C") else { return nil }

        let suffix = rawName.dropFirst()
        let digits = suffix.prefix { $0.isNumber }
        guard let caldwellNumber = Int(digits) else { return nil }
        return "C\(caldwellNumber)"
    }

    private var normalizedAddendumDesignation: String? {
        let rawName = fields["Name"]?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        guard !rawName.isEmpty else { return nil }
        return rawName
    }

    private var primaryCommonName: String {
        splitField("Common names").first ?? ""
    }

    private var parsedMagnitude: Double? {
        parsedDouble("V-Mag") ?? parsedDouble("B-Mag")
    }

    private func parsedDouble(_ field: String) -> Double? {
        guard let rawValue = fields[field]?.trimmingCharacters(in: .whitespacesAndNewlines), !rawValue.isEmpty else {
            return nil
        }

        return Double(rawValue)
    }

    private func splitField(_ field: String) -> [String] {
        let rawValue = fields[field] ?? ""
        return rawValue
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func normalizedCrossReference(prefix: String, field: String) -> String? {
        guard let rawValue = fields[field]?.trimmingCharacters(in: .whitespacesAndNewlines), !rawValue.isEmpty else {
            return nil
        }

        return Self.normalizedCrossReference(prefix: prefix, rawValue: rawValue)
    }

    private func normalizedNGCICName(_ rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        if trimmed.hasPrefix("NGC") {
            let suffix = String(trimmed.dropFirst(3))
            return Self.normalizedCrossReference(prefix: "NGC", rawValue: suffix)
        }

        if trimmed.hasPrefix("IC") {
            let suffix = String(trimmed.dropFirst(2))
            return Self.normalizedCrossReference(prefix: "IC", rawValue: suffix)
        }

        return trimmed
    }

    private static func normalizedCrossReference(prefix: String, rawValue: String) -> String? {
        let trimmed = rawValue.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let digits = trimmed.prefix { $0.isNumber }
        let suffix = trimmed.dropFirst(digits.count)
        let normalizedDigits = String(digits.drop { $0 == "0" })
        let valuePortion = normalizedDigits.isEmpty ? String(digits) : normalizedDigits
        let normalizedSuffix = suffix.trimmingCharacters(in: .whitespacesAndNewlines)
        let combined = valuePortion + normalizedSuffix

        guard !combined.isEmpty else { return nil }
        return "\(prefix) \(combined)"
    }

    private static func parseRightAscension(_ rawValue: String) -> Double? {
        let components = rawValue
            .split(separator: ":")
            .map { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }

        guard components.count >= 3, let hours = components[0], let minutes = components[1], let seconds = components[2] else {
            return nil
        }

        return hours + (minutes / 60) + (seconds / 3600)
    }

    private static func parseDeclination(_ rawValue: String) -> Double? {
        let cleaned = rawValue
            .replacingOccurrences(of: ":", with: " ")
            .replacingOccurrences(of: "°", with: " ")
            .replacingOccurrences(of: "'", with: " ")
            .replacingOccurrences(of: "\"", with: " ")
            .replacingOccurrences(of: "′", with: " ")
            .replacingOccurrences(of: "″", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        let components = cleaned.split(whereSeparator: \.isWhitespace)
        guard components.count >= 3 else { return nil }

        guard let degrees = Double(components[0]), let minutes = Double(components[1]), let seconds = Double(components[2]) else {
            return nil
        }

        let sign = degrees < 0 || cleaned.hasPrefix("-") ? -1.0 : 1.0
        let absoluteDegrees = abs(degrees) + (minutes / 60) + (seconds / 3600)
        return sign * absoluteDegrees
    }

    private static func deduplicated(_ values: [String?]) -> [String] {
        var seen = Set<String>()
        var deduplicated: [String] = []

        for value in values {
            guard let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            guard seen.insert(key).inserted else { continue }
            deduplicated.append(trimmed)
        }

        return deduplicated
    }
}
