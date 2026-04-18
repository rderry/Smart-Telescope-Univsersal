import XCTest
@testable import AstronomyObservationPlanning

final class ElevationLookupServiceTests: XCTestCase {
    func testUSGSElevationParserAcceptsNumericValue() throws {
        let json = """
        {
          "location": {
            "x": -122.141876,
            "y": 47.561006,
            "spatialReference": { "wkid": 4326, "latestWkid": 4326 }
          },
          "locationId": 0,
          "value": 224.36332565033977,
          "rasterId": 100755,
          "resolution": 1
        }
        """

        let elevation = try ElevationLookupService.usgsElevationMeters(from: Data(json.utf8))

        XCTAssertEqual(elevation, 224.36332565033977, accuracy: 0.0001)
    }

    func testUSGSElevationParserAcceptsStringValue() throws {
        let json = """
        {
          "value": "42.277534485"
        }
        """

        let elevation = try ElevationLookupService.usgsElevationMeters(from: Data(json.utf8))

        XCTAssertEqual(elevation, 42.277534485, accuracy: 0.0001)
    }

    func testOpenMeteoElevationParserUsesFirstElevation() throws {
        let json = """
        {
          "elevation": [1609.0]
        }
        """

        let elevation = try ElevationLookupService.openMeteoElevationMeters(from: Data(json.utf8))

        XCTAssertEqual(elevation, 1609.0, accuracy: 0.0001)
    }
}
