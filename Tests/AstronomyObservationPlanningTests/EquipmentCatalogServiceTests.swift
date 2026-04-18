import XCTest
@testable import AstronomyObservationPlanning

@MainActor
final class EquipmentCatalogServiceTests: XCTestCase {
    func testBundledEquipmentSeedIncludesCurrentSmartScopeFamilies() {
        let records = EquipmentCatalogService.bundledSeedRecords()
        let uniqueIDs = Set(records.map(\.id))

        XCTAssertEqual(records.count, uniqueIDs.count)
        XCTAssertGreaterThanOrEqual(records.count, 30)
        XCTAssertTrue(records.contains { $0.name == "Vespera 3" && $0.brand == "Vaonis" })
        XCTAssertTrue(records.contains { $0.name == "Vespera Pro 2" && $0.brand == "Vaonis" })
        XCTAssertTrue(records.contains { $0.name == "Hyperia" && $0.brand == "Vaonis" })
        XCTAssertTrue(records.contains { $0.name == "Seestar S30 Pro" && $0.brand == "ZWO" })
        XCTAssertTrue(records.contains { $0.name == "DWARF mini" && $0.brand == "DWARFLAB" })
        XCTAssertTrue(records.contains { $0.name == "Origin Mark II" && $0.brand == "Celestron" })
        XCTAssertTrue(records.contains { $0.name == "Odyssey" && $0.category == .smartTelescope })
        XCTAssertTrue(records.contains { $0.name == "Hestia" && $0.category == .smartAccessory })
    }
}
