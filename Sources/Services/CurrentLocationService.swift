import CoreLocation
import Foundation

struct CurrentLocationResult {
    let latitude: Double
    let longitude: Double
    let altitudeMeters: Double?
    let altitudeSource: CurrentLocationAltitudeSource?
    let horizontalAccuracyMeters: Double
    let verticalAccuracyMeters: Double?
    let formattedAddress: String?
    let countryCode: String?
    let countryName: String?
    let timeZoneIdentifier: String?
}

enum CurrentLocationAltitudeSource {
    case gps
    case terrainLookup
}

enum CurrentLocationError: LocalizedError {
    case locationServicesDisabled
    case authorizationDenied
    case authorizationRestricted
    case noLocation
    case unknownAuthorization

    var errorDescription: String? {
        switch self {
        case .locationServicesDisabled:
            "Location Services are turned off in macOS System Settings."
        case .authorizationDenied:
            "Location access was denied. Enable Location Services for Smart Scope Observation Planner in macOS System Settings."
        case .authorizationRestricted:
            "Location access is restricted on this Mac."
        case .noLocation:
            "macOS did not return a current GPS location."
        case .unknownAuthorization:
            "macOS returned an unsupported Location Services authorization state."
        }
    }
}

@MainActor
enum CurrentLocationService {
    static func requestCurrentLocation() async throws -> CurrentLocationResult {
        let request = CurrentLocationRequest()
        let location = try await request.location()
        let lookup = try? await LocationGeocodingService.reverseGeocodeCoordinates(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude
        )

        let gpsAltitudeMeters = location.verticalAccuracy >= 0 && location.altitude.isFinite
            ? location.altitude
            : nil
        let terrainElevationMeters = gpsAltitudeMeters == nil
            ? try? await ElevationLookupService.elevationMeters(
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude
            )
            : nil
        let altitudeMeters = gpsAltitudeMeters ?? terrainElevationMeters
        let altitudeSource: CurrentLocationAltitudeSource? = if gpsAltitudeMeters != nil {
            .gps
        } else if terrainElevationMeters != nil {
            .terrainLookup
        } else {
            nil
        }
        let verticalAccuracyMeters = location.verticalAccuracy >= 0
            ? location.verticalAccuracy
            : nil

        return CurrentLocationResult(
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            altitudeMeters: altitudeMeters,
            altitudeSource: altitudeSource,
            horizontalAccuracyMeters: location.horizontalAccuracy,
            verticalAccuracyMeters: verticalAccuracyMeters,
            formattedAddress: lookup?.formattedAddress,
            countryCode: lookup?.countryCode,
            countryName: lookup?.countryName,
            timeZoneIdentifier: lookup?.timeZoneIdentifier
        )
    }
}

@MainActor
private final class CurrentLocationRequest: NSObject, @preconcurrency CLLocationManagerDelegate {
    private let manager = CLLocationManager()
    private var continuation: CheckedContinuation<CLLocation, Error>?
    private var lastLocation: CLLocation?
    private var timeoutTask: Task<Void, Never>?
    private var didRequestLocation = false

    func location() async throws -> CLLocation {
        guard CLLocationManager.locationServicesEnabled() else {
            throw CurrentLocationError.locationServicesDisabled
        }

        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyBestForNavigation
        manager.distanceFilter = kCLDistanceFilterNone

        return try await withCheckedThrowingContinuation { continuation in
            self.continuation = continuation
            handleAuthorizationStatus(manager.authorizationStatus)
        }
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        handleAuthorizationStatus(manager.authorizationStatus)
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else {
            finish(throwing: CurrentLocationError.noLocation)
            return
        }

        lastLocation = preferredLocation(current: lastLocation, candidate: location)

        if location.verticalAccuracy >= 0 {
            finish(returning: location)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        if let lastLocation {
            finish(returning: lastLocation)
            return
        }

        finish(throwing: error)
    }

    private func handleAuthorizationStatus(_ status: CLAuthorizationStatus) {
        switch status {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedAlways, .authorizedWhenInUse:
            requestLocationIfNeeded()
        case .denied:
            finish(throwing: CurrentLocationError.authorizationDenied)
        case .restricted:
            finish(throwing: CurrentLocationError.authorizationRestricted)
        @unknown default:
            finish(throwing: CurrentLocationError.unknownAuthorization)
        }
    }

    private func requestLocationIfNeeded() {
        guard !didRequestLocation else { return }
        didRequestLocation = true
        manager.startUpdatingLocation()
        manager.requestLocation()
        timeoutTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            self?.finishWithBestAvailableLocation()
        }
    }

    private func finishWithBestAvailableLocation() {
        guard continuation != nil else { return }

        if let lastLocation {
            finish(returning: lastLocation)
        } else {
            finish(throwing: CurrentLocationError.noLocation)
        }
    }

    private func finish(returning location: CLLocation) {
        continuation?.resume(returning: location)
        cleanup()
    }

    private func finish(throwing error: Error) {
        continuation?.resume(throwing: error)
        cleanup()
    }

    private func cleanup() {
        timeoutTask?.cancel()
        timeoutTask = nil
        continuation = nil
        manager.stopUpdatingLocation()
        manager.delegate = nil
    }

    private func preferredLocation(current: CLLocation?, candidate: CLLocation) -> CLLocation {
        guard let current else { return candidate }

        let candidateHasElevation = candidate.verticalAccuracy >= 0
        let currentHasElevation = current.verticalAccuracy >= 0

        if candidateHasElevation != currentHasElevation {
            return candidateHasElevation ? candidate : current
        }

        if candidate.horizontalAccuracy >= 0,
           current.horizontalAccuracy < 0 || candidate.horizontalAccuracy < current.horizontalAccuracy {
            return candidate
        }

        return candidate.timestamp > current.timestamp ? candidate : current
    }
}
