import Foundation
import SwiftData

struct TransientFeedSeedRecord: Codable {
    let feedID: String
    let displayName: String
    let transientType: TransientType
    let constellation: String
    let rightAscensionHours: Double
    let declinationDegrees: Double
    let magnitude: Double?
    let discoveryDate: String
    let lastUpdated: String
    let sourceName: String
    let notes: String
}

struct TransientFeedReferenceSite: Equatable, Sendable {
    let name: String
    let latitude: Double
    let longitude: Double
    let elevationMeters: Double
}

enum TransientFeedService {
    private static let session = RemoteServiceSessionFactory.makeSession(
        timeoutIntervalForRequest: 15,
        timeoutIntervalForResource: 30
    )

    @MainActor
    static func bootstrapFeedIfNeeded(context: ModelContext) throws {
        try applyRecords(bundledFeedRecords(), context: context)
    }

    static func bundledFeedRecords() throws -> [TransientFeedSeedRecord] {
        guard let url = AppResourceBundle.current.url(forResource: "transient_feed", withExtension: "json") else { return [] }

        let data = try Data(contentsOf: url)
        return try JSONDecoder().decode([TransientFeedSeedRecord].self, from: data)
    }

    @MainActor
    static func refreshFeedFromInternet(
        context: ModelContext,
        referenceSite: TransientFeedReferenceSite,
        now: Date = .now
    ) async throws {
        let remoteRecords = try await remoteTransientRecords(referenceSite: referenceSite, now: now)
        let mergedRecords = try merge(remoteRecords: remoteRecords, withBundledFallback: bundledFeedRecords())
        try applyRecords(mergedRecords, context: context)
    }

    static func remoteTransientRecords(
        referenceSite: TransientFeedReferenceSite,
        now: Date = .now
    ) async throws -> [TransientFeedSeedRecord] {
        let requestDetails = JPLCometFeedRequest(site: referenceSite, observationDate: now)
        guard let url = requestDetails.url else {
            throw TransientFeedRefreshError.invalidRequest
        }

        var request = URLRequest(url: url)
        request.setValue("SmartScopeObservationPlanner/1.0 BigSkyAstro", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw TransientFeedRefreshError.invalidResponse
        }

        guard 200..<300 ~= httpResponse.statusCode else {
            throw TransientFeedRefreshError.requestFailed(statusCode: httpResponse.statusCode)
        }

        return try JPLCometFeedParser().parseRecords(from: data, request: requestDetails, fetchedAt: now)
    }

    static func merge(
        remoteRecords: [TransientFeedSeedRecord],
        withBundledFallback bundledRecords: [TransientFeedSeedRecord]
    ) throws -> [TransientFeedSeedRecord] {
        var recordsByID = Dictionary(uniqueKeysWithValues: remoteRecords.map { ($0.feedID, $0) })
        let remoteContainsLiveComets = remoteRecords.contains(where: { $0.transientType == .comet })

        for bundledRecord in bundledRecords {
            if remoteContainsLiveComets && bundledRecord.transientType == .comet {
                continue
            }

            if recordsByID[bundledRecord.feedID] == nil {
                recordsByID[bundledRecord.feedID] = bundledRecord
            }
        }

        return recordsByID.values.sorted { $0.lastUpdated > $1.lastUpdated }
    }

    @MainActor
    static func applyRecords(_ records: [TransientFeedSeedRecord], context: ModelContext) throws {
        let formatter = ISO8601DateFormatter()
        let existingItems = try context.fetch(FetchDescriptor<TransientFeedItem>())

        for item in existingItems
        where !MagnitudeVisibilityPolicy.allows(optionalMagnitude: item.magnitude)
            && !item.isLocallyRetained
        {
            context.delete(item)
        }

        let visibleRecords = records.filter { MagnitudeVisibilityPolicy.allows(optionalMagnitude: $0.magnitude) }
        let visibleExistingItems = try context.fetch(FetchDescriptor<TransientFeedItem>())
        let existingByFeedID = Dictionary(uniqueKeysWithValues: visibleExistingItems.map { ($0.feedID, $0) })

        for record in visibleRecords {
            guard
                let discoveryDate = formatter.date(from: record.discoveryDate),
                let lastUpdated = formatter.date(from: record.lastUpdated)
            else {
                continue
            }

            if let existing = existingByFeedID[record.feedID] {
                existing.displayName = record.displayName
                existing.transientType = record.transientType
                existing.constellation = record.constellation
                existing.rightAscensionHours = record.rightAscensionHours
                existing.declinationDegrees = record.declinationDegrees
                existing.magnitude = record.magnitude
                existing.discoveryDate = discoveryDate
                existing.lastUpdated = lastUpdated
                existing.sourceName = record.sourceName
                existing.notes = record.notes
            } else {
                context.insert(
                    TransientFeedItem(
                        feedID: record.feedID,
                        displayName: record.displayName,
                        transientType: record.transientType,
                        constellation: record.constellation,
                        rightAscensionHours: record.rightAscensionHours,
                        declinationDegrees: record.declinationDegrees,
                        magnitude: record.magnitude,
                        discoveryDate: discoveryDate,
                        lastUpdated: lastUpdated,
                        sourceName: record.sourceName,
                        notes: record.notes
                    )
                )
            }
        }

        try context.save()
    }
}

enum TransientFeedRefreshError: LocalizedError {
    case invalidRequest
    case invalidResponse
    case requestFailed(statusCode: Int)

    var errorDescription: String? {
        switch self {
        case .invalidRequest:
            "Could not build the live transient request."
        case .invalidResponse:
            "The live transient service returned an unreadable response."
        case .requestFailed(let statusCode):
            "The live transient service returned HTTP \(statusCode)."
        }
    }
}

struct JPLCometFeedRequest {
    let site: TransientFeedReferenceSite
    let observationDate: Date

    var url: URL? {
        var components = URLComponents(string: "https://ssd-api.jpl.nasa.gov/sbwobs.api")
        components?.queryItems = [
            URLQueryItem(name: "lat", value: coordinateString(site.latitude)),
            URLQueryItem(name: "lon", value: coordinateString(site.longitude)),
            URLQueryItem(name: "alt", value: altitudeKilometersString(site.elevationMeters)),
            URLQueryItem(name: "obs-time", value: formattedDate(observationDate)),
            URLQueryItem(name: "sb-kind", value: "c"),
            URLQueryItem(name: "elev-min", value: "20"),
            URLQueryItem(name: "vmag-max", value: "14"),
            URLQueryItem(name: "mag-required", value: "true"),
            URLQueryItem(name: "fmt-ra-dec", value: "true"),
            URLQueryItem(name: "maxoutput", value: "12"),
            URLQueryItem(name: "output-sort", value: "vmag")
        ]
        return components?.url
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private func coordinateString(_ value: Double) -> String {
        String(format: "%.4f", value)
    }

    private func altitudeKilometersString(_ meters: Double) -> String {
        String(format: "%.1f", max(meters / 1_000, 0))
    }
}

struct JPLCometFeedParser {
    private let isoFormatter = ISO8601DateFormatter()

    func parseRecords(from data: Data, request: JPLCometFeedRequest, fetchedAt: Date) throws -> [TransientFeedSeedRecord] {
        let payload = try JSONDecoder().decode(JPLCometResponse.self, from: data)

        guard
            let designationIndex = payload.fields.firstIndex(of: "Designation"),
            let fullNameIndex = payload.fields.firstIndex(of: "Full name"),
            let rightAscensionIndex = payload.fields.firstIndex(of: "R.A."),
            let declinationIndex = payload.fields.firstIndex(of: "Dec."),
            let magnitudeIndex = payload.fields.firstIndex(of: "Vmag")
        else {
            return []
        }

        let discoveryDateString = isoFormatter.string(from: request.observationDate)
        let fetchedDateString = isoFormatter.string(from: fetchedAt)

        return payload.data.compactMap { row in
            guard
                row.indices.contains(designationIndex),
                row.indices.contains(fullNameIndex),
                row.indices.contains(rightAscensionIndex),
                row.indices.contains(declinationIndex),
                row.indices.contains(magnitudeIndex),
                let rightAscensionHours = parseRightAscension(row[rightAscensionIndex]),
                let declinationDegrees = parseDeclination(row[declinationIndex])
            else {
                return nil
            }

            let designation = row[designationIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let displayName = row[fullNameIndex].trimmingCharacters(in: .whitespacesAndNewlines)
            let magnitude = parseMagnitude(row[magnitudeIndex])
            let feedID = "COMET-" + sanitizedIdentifier(designation)
            let notes = "Observable comet feed for \(request.site.name) on \(discoveryDateString.prefix(10))."

            return TransientFeedSeedRecord(
                feedID: feedID,
                displayName: displayName.isEmpty ? designation : displayName,
                transientType: .comet,
                constellation: "",
                rightAscensionHours: rightAscensionHours,
                declinationDegrees: declinationDegrees,
                magnitude: magnitude,
                discoveryDate: discoveryDateString,
                lastUpdated: fetchedDateString,
                sourceName: "NASA/JPL Small-Body Observability API",
                notes: notes
            )
        }
    }

    func parseMagnitude(_ rawValue: String) -> Double? {
        let cleaned = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .filter { "0123456789.-".contains($0) }

        guard !cleaned.isEmpty else { return nil }
        return Double(cleaned)
    }

    func parseRightAscension(_ rawValue: String) -> Double? {
        let components = rawValue
            .split(separator: ":")
            .map { Double($0.trimmingCharacters(in: .whitespacesAndNewlines)) }

        guard components.count >= 3, let hours = components[0], let minutes = components[1], let seconds = components[2] else {
            return nil
        }

        return hours + (minutes / 60) + (seconds / 3600)
    }

    func parseDeclination(_ rawValue: String) -> Double? {
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

    private func sanitizedIdentifier(_ rawValue: String) -> String {
        rawValue
            .replacingOccurrences(of: "/", with: "-")
            .replacingOccurrences(of: " ", with: "")
            .replacingOccurrences(of: "(", with: "")
            .replacingOccurrences(of: ")", with: "")
    }
}

private struct JPLCometResponse: Decodable {
    let fields: [String]
    let data: [[String]]
}
