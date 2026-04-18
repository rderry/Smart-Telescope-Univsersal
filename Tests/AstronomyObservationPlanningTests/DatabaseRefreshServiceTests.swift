import SwiftData
import XCTest
@testable import AstronomyObservationPlanning

final class DatabaseRefreshServiceTests: XCTestCase {
    func testWeeklyScheduleIsDueAfterSevenDays() {
        let schedule = DatabaseRefreshSchedule(refreshInterval: 7 * 24 * 60 * 60)
        let now = Date(timeIntervalSince1970: 1_775_520_000)

        XCTAssertTrue(schedule.isDue(lastSuccess: nil, now: now))
        XCTAssertFalse(schedule.isDue(lastSuccess: now.addingTimeInterval(-6 * 24 * 60 * 60), now: now))
        XCTAssertTrue(schedule.isDue(lastSuccess: now.addingTimeInterval(-7 * 24 * 60 * 60), now: now))
    }

    func testOpenNGCParserBuildsMessierRecordFromRemoteRow() {
        let header = "Name;Type;RA;Dec;Const;MajAx;MinAx;PosAng;B-Mag;V-Mag;J-Mag;H-Mag;K-Mag;SurfBr;Hubble;Pax;Pm-RA;Pm-Dec;RadVel;Redshift;Cstar U-Mag;Cstar B-Mag;Cstar V-Mag;M;NGC;IC;Cstar Names;Identifiers;Common names;NED notes;OpenNGC notes;Sources"
        let row = "NGC0224;G;00:42:44.35;+41:16:08.6;And;177.83;69.66;35;4.29;3.44;2.09;1.28;0.98;23.63;Sb;6.0000;;;-300;-0.001000;;;;031;;;;2MASX J00424433+4116074,IRAS 00400+4059,MCG +07-02-016,PGC 002557,UGC 00454;Andromeda Galaxy;;;Type:1|RA:1|Dec:1|Const:99|MajAx:3|MinAx:3|PosAng:3|B-Mag:3|V-Mag:2|J-Mag:2|H-Mag:2|K-Mag:2|SurfBr:3|Hubble:3|Pax:2|RadVel:2|Redshift:2"
        let text = header + "\n" + row

        let records = OpenNGCRemoteCatalogParser().parseCatalogRecords(from: text)

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.catalogID, "M31")
        XCTAssertEqual(records.first?.catalogFamily, .messier)
        XCTAssertEqual(records.first?.primaryDesignation, "NGC 224")
        XCTAssertEqual(records.first?.commonName, "Andromeda Galaxy")
    }

    func testOpenNGCParserBuildsAddendumAsterismRecord() {
        let header = "Name;Type;RA;Dec;Const;MajAx;MinAx;PosAng;B-Mag;V-Mag;J-Mag;H-Mag;K-Mag;SurfBr;Hubble;Pax;Pm-RA;Pm-Dec;RadVel;Redshift;Cstar U-Mag;Cstar B-Mag;Cstar V-Mag;M;NGC;IC;Cstar Names;Identifiers;Common names;NED notes;OpenNGC notes;Sources"
        let row = "Cl399;*Ass;19:25:24.0;+20:11:00;Vul;70.00;;;3.93;3.60;;;;;;;;;;;;;;;;;;;Brocchi's Cluster,Al Sufi's Cluster,Coathanger Asterism;;;Type:2|RA:2|Dec:2|Const:99|MajAx:99|B-Mag:2|V-Mag:2"
        let text = header + "\n" + row

        let records = OpenNGCRemoteCatalogParser().parseCatalogRecords(from: text)

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.catalogID, "Cl399")
        XCTAssertEqual(records.first?.catalogFamily, .openNGCAddendum)
        XCTAssertEqual(records.first?.objectType, .asterism)
        XCTAssertEqual(records.first?.commonName, "Brocchi's Cluster")
    }

    @MainActor
    func testCatalogRefreshPrunesMissingUnretainedTargets() throws {
        let container = ModelContainerFactory.makeInMemoryContainer()
        let context = ModelContext(container)

        let staleObject = DSOObject(
            catalogID: "NGC 9999",
            commonName: "Stale Object",
            primaryDesignation: "NGC 9999",
            catalogFamily: .ngc,
            objectType: .galaxy,
            constellation: "Peg",
            rightAscensionHours: 0,
            declinationDegrees: 0,
            magnitude: 10,
            angularSizeArcMinutes: 5
        )
        let retainedObject = DSOObject(
            catalogID: "NGC 8888",
            commonName: "Retained Object",
            primaryDesignation: "NGC 8888",
            catalogFamily: .ngc,
            objectType: .galaxy,
            constellation: "Peg",
            rightAscensionHours: 0,
            declinationDegrees: 0,
            magnitude: 10,
            angularSizeArcMinutes: 5,
            locallyRetainedAt: Date(timeIntervalSince1970: 1_775_520_000),
            localRetentionReason: "Selected for a plan"
        )
        context.insert(staleObject)
        context.insert(retainedObject)

        try CatalogService.applyRecords(
            [
                CatalogSeedRecord(
                    catalogID: "M31",
                    commonName: "Andromeda Galaxy",
                    primaryDesignation: "NGC 224",
                    catalogFamily: .messier,
                    alternateDesignations: ["M31"],
                    objectType: .galaxy,
                    constellation: "And",
                    rightAscensionHours: 0.712,
                    declinationDegrees: 41.269,
                    magnitude: 3.4,
                    angularSizeArcMinutes: 178,
                    surfaceBrightness: 13.5
                )
            ],
            context: context,
            pruneMissingUnreferenced: true
        )

        let objects = try context.fetch(FetchDescriptor<DSOObject>())
        XCTAssertFalse(objects.contains { $0.catalogID == "NGC 9999" })
        XCTAssertTrue(objects.contains { $0.catalogID == "NGC 8888" })
        XCTAssertTrue(objects.contains { $0.catalogID == "M31" })
    }

    func testJPLCometParserBuildsCometFeedRecord() throws {
        let json = """
        {
          "fields": ["Designation", "Full name", "Rise time", "Transit time", "Set time", "Max. time observable", "R.A.", "Dec.", "Vmag"],
          "data": [
            ["2024 E1", "C/2024 E1 (Wierzchos)", "17:55*", "22:57*", "04:00", "01:00", "04:52:50", "+14 40'20\\"", "14.0T"]
          ]
        }
        """
        let request = JPLCometFeedRequest(
            site: TransientFeedReferenceSite(
                name: "Mountain Dark Site",
                latitude: 38.9972,
                longitude: -105.5478,
                elevationMeters: 2_800
            ),
            observationDate: Date(timeIntervalSince1970: 1_775_520_000)
        )
        let fetchedAt = Date(timeIntervalSince1970: 1_775_520_600)

        let records = try JPLCometFeedParser().parseRecords(from: Data(json.utf8), request: request, fetchedAt: fetchedAt)

        XCTAssertEqual(records.count, 1)
        XCTAssertEqual(records.first?.transientType, .comet)
        XCTAssertEqual(records.first?.displayName, "C/2024 E1 (Wierzchos)")
        XCTAssertEqual(records.first?.magnitude, 14.0)
        XCTAssertEqual(records.first?.rightAscensionHours ?? 0, 4.8805, accuracy: 0.0001)
        XCTAssertEqual(records.first?.declinationDegrees ?? 0, 14.6722, accuracy: 0.0001)
    }
}
