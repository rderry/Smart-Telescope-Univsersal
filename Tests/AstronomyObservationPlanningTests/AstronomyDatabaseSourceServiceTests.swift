import XCTest
@testable import AstronomyObservationPlanning

final class AstronomyDatabaseSourceServiceTests: XCTestCase {
    func testRegistryIncludesLargeSolarSystemAndUniverseBackbones() {
        let ids = Set(AstronomyDatabaseSourceService.sources.map(\.id))

        XCTAssertTrue(ids.contains("esa-gaia-dr3"))
        XCTAssertTrue(ids.contains("cds-simbad"))
        XCTAssertTrue(ids.contains("cds-vizier"))
        XCTAssertTrue(ids.contains("nasa-ipac-ned"))
        XCTAssertTrue(ids.contains("jpl-small-body-database"))
        XCTAssertTrue(ids.contains("minor-planet-center"))
        XCTAssertGreaterThanOrEqual(AstronomyDatabaseSourceService.sources(in: .universe).count, 5)
        XCTAssertGreaterThanOrEqual(AstronomyDatabaseSourceService.sources(in: .solarSystem).count, 3)
    }

    func testRegistryIncludesCompiledLocalPlanningCatalogs() {
        let ids = Set(AstronomyDatabaseSourceService.sources.map(\.id))

        XCTAssertTrue(ids.contains("bigskyastro-local-common-dso"))
        XCTAssertTrue(ids.contains("bigskyastro-local-transient-seed"))
        XCTAssertTrue(
            AstronomyDatabaseSourceService.sources.contains {
                $0.id == "bigskyastro-local-common-dso"
                && $0.accessDescription.localizedCaseInsensitiveContains("Bundled local")
            }
        )
    }

    func testLargestCatalogsStayRemoteForAppSize() {
        let remoteBackbones = AstronomyDatabaseSourceService.sources.filter {
            $0.accessDescription.localizedCaseInsensitiveContains("remote")
        }

        XCTAssertGreaterThanOrEqual(remoteBackbones.count, 8)
        XCTAssertTrue(
            AstronomyDatabaseSourceService.sources.contains {
                $0.id == "esa-gaia-dr3"
                && $0.accessDescription.localizedCaseInsensitiveContains("too large")
            }
        )
    }
}
