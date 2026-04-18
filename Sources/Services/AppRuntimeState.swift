import Foundation
import Observation

enum InternetConnectivityStatus {
    case unchecked
    case checking
    case connected
    case disconnected
}

enum InternetConnectivityChecker {
    static func hasInternetConnection(
        url: URL = URL(string: "https://www.apple.com/library/test/success.html")!,
        timeout: TimeInterval = 4
    ) async -> Bool {
        var request = URLRequest(
            url: url,
            cachePolicy: .reloadIgnoringLocalAndRemoteCacheData,
            timeoutInterval: timeout
        )
        request.httpMethod = "GET"
        request.setValue("no-cache", forHTTPHeaderField: "Cache-Control")

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            guard let httpResponse = response as? HTTPURLResponse else { return false }
            return (200..<400).contains(httpResponse.statusCode)
        } catch {
            return false
        }
    }
}

struct SingleNightTargetObservationPeriod: Equatable {
    var start: Date?
    var end: Date?
}

struct SingleNightObservationDraft {
    var selectedLocationID: UUID?
    var selectedTargetID: String?
    var addedTargetIDs: [String]
    var targetObservationPeriods: [String: SingleNightTargetObservationPeriod]
    var observationDateTime: Date
    var observationTimeZoneIdentifier: String
    var telescopeCaptureStartOverrideDate: Date?
    var dsoLimitingMagnitudeText: String
    var targetAzimuthLowLimitText: String
    var targetAzimuthHighLimitText: String
    var targetAltitudeLowLimitText: String
    var targetAltitudeHighLimitText: String
    var selectedTargetTypeNames: Set<String>
    var targetSortModeRawValue: String
    var hasInitializedTargetTypeSelection: Bool
    var didManuallyAdjustTargetTypes: Bool
}

@MainActor
@Observable
final class AppRuntimeState {
    static let noInternetMessage = """
    Sorry, an internet connection is required to update online databases and resources.
    The program uses information from the Web to refresh location information,
    equipment references, manuals, star charts, and calculation data.
    NO WEB DATA IS SAVED (other than updated databases).
    """

    var internetConnectivityStatus: InternetConnectivityStatus = .unchecked
    var isStartupDataRefreshInProgress = false
    var storageWarning: String?
    var refreshWarnings: [String]
    var pendingLocationSelectionReturnSectionRawValue: String?
    var pendingTelescopeCaptureStartDate: Date?
    var pendingTelescopeCaptureStartDestinationRawValue: String?
    var pendingSingleNightPlanRequest = false
    var singleNightObservationDraft: SingleNightObservationDraft?

    init(storageWarning: String? = nil, refreshWarnings: [String] = []) {
        self.storageWarning = storageWarning
        self.refreshWarnings = refreshWarnings
    }

    var activeWarnings: [String] {
        deduplicated([storageWarning].compactMap { $0 } + refreshWarnings)
    }

    var noInternetMessage: String? {
        internetConnectivityStatus == .disconnected ? Self.noInternetMessage : nil
    }

    var bannerText: String? {
        let warnings = activeWarnings
        guard !warnings.isEmpty else { return nil }
        return warnings.joined(separator: "  ")
    }

    func setRefreshWarnings(_ warnings: [String]) {
        refreshWarnings = deduplicated(warnings)
    }

    private func deduplicated(_ values: [String]) -> [String] {
        var seen = Set<String>()
        var results: [String] = []

        for value in values {
            let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            guard seen.insert(trimmed).inserted else { continue }
            results.append(trimmed)
        }

        return results
    }
}
