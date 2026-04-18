import XCTest
@testable import AstronomyObservationPlanning

final class SolarHorizonServiceTests: XCTestCase {
    func testWesternLongitudeEveningStartFallsWithinSameLocalNight() throws {
        let site = ObservingSite(
            name: "Denver",
            latitude: 39.7392,
            longitude: -104.9903,
            timeZoneIdentifier: "America/Denver"
        )
        let timeZone = try XCTUnwrap(TimeZone(identifier: "America/Denver"))
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone

        let referenceDate = try XCTUnwrap(calendar.date(from: DateComponents(
            timeZone: timeZone,
            year: 2026,
            month: 4,
            day: 18,
            hour: 21,
            minute: 20
        )))

        let events = SolarHorizonService.sunBelowHorizonEvents(for: site, on: referenceDate)
        let start = try XCTUnwrap(events.start)
        let end = try XCTUnwrap(events.end)

        XCTAssertLessThan(start, referenceDate)
        XCTAssertLessThan(referenceDate, end)
        XCTAssertEqual(calendar.component(.day, from: start), 18)
        XCTAssertEqual(calendar.component(.day, from: end), 19)
    }
}
