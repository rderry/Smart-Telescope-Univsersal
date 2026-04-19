import Foundation

enum AstronomyDatabaseDomain: String, CaseIterable, Identifiable {
    case solarSystem
    case universe
    case planningCatalog

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .solarSystem: "Solar System"
        case .universe: "Universe"
        case .planningCatalog: "Planning Catalog"
        }
    }
}

struct AstronomyDatabaseSource: Identifiable, Equatable {
    let id: String
    let name: String
    let provider: String
    let domain: AstronomyDatabaseDomain
    let scaleDescription: String
    let contentsDescription: String
    let accessDescription: String
    let sourceURL: URL
    let appUse: String
}

enum AstronomyDatabaseSourceService {
    static let sources: [AstronomyDatabaseSource] = [
        AstronomyDatabaseSource(
            id: "esa-gaia-dr3",
            name: "Gaia Archive DR3",
            provider: "European Space Agency",
            domain: .universe,
            scaleDescription: "Billion-source Milky Way astrometry and photometry catalog.",
            contentsDescription: "Stars, extended sources, astrometry, photometry, radial velocities, and astrophysical parameters.",
            accessDescription: "Remote query source; too large to bundle with the app.",
            sourceURL: URL(string: "https://gea.esac.esa.int/archive/")!,
            appUse: "Future star-field, calibration, and cross-match source."
        ),
        AstronomyDatabaseSource(
            id: "cds-simbad",
            name: "SIMBAD Astronomical Database",
            provider: "CDS Strasbourg",
            domain: .universe,
            scaleDescription: "Large object-identification and literature cross-reference database.",
            contentsDescription: "Object identifiers, coordinates, object types, bibliography links, and cross-identifications.",
            accessDescription: "Remote query source; best used for lookup and cross-identification.",
            sourceURL: URL(string: "https://simbad.cds.unistra.fr/simbad/")!,
            appUse: "Future identifier resolver for targets entered by the observer."
        ),
        AstronomyDatabaseSource(
            id: "cds-vizier",
            name: "VizieR Catalog Service",
            provider: "CDS Strasbourg",
            domain: .universe,
            scaleDescription: "Federated astronomical catalog service covering many survey catalogs.",
            contentsDescription: "Published tables from star, galaxy, nebula, variable-star, and survey catalogs.",
            accessDescription: "Remote query source; use selected catalogs rather than bundling the whole service.",
            sourceURL: URL(string: "https://vizier.cds.unistra.fr/viz-bin/VizieR")!,
            appUse: "Future catalog expansion source for specialized observing lists."
        ),
        AstronomyDatabaseSource(
            id: "nasa-ipac-ned",
            name: "NASA/IPAC Extragalactic Database",
            provider: "NASA/IPAC",
            domain: .universe,
            scaleDescription: "Largest practical public extragalactic backbone found: current NED holdings list more than 1.1 billion distinct objects.",
            contentsDescription: "Galaxies, quasars, extragalactic distances, redshifts, photometry, diameters, spectra, images, and literature links.",
            accessDescription: "Public remote TAP/API query source; use constrained searches because NED limits high-volume automated access.",
            sourceURL: URL(string: "https://ned.ipac.caltech.edu/")!,
            appUse: "Primary online galaxy database for lookup and enrichment; the app keeps a smaller local observing catalog for offline planning."
        ),
        AstronomyDatabaseSource(
            id: "nasa-exoplanet-archive",
            name: "NASA Exoplanet Archive",
            provider: "NASA/IPAC",
            domain: .universe,
            scaleDescription: "Authoritative exoplanet and host-star archive.",
            contentsDescription: "Confirmed planets, candidate planets, host stars, transit data, radial-velocity data, and TAP tables.",
            accessDescription: "Remote query source; small result sets can be cached later.",
            sourceURL: URL(string: "https://exoplanetarchive.ipac.caltech.edu/")!,
            appUse: "Future exoplanet and host-star planning source."
        ),
        AstronomyDatabaseSource(
            id: "heasarc",
            name: "HEASARC",
            provider: "NASA Goddard",
            domain: .universe,
            scaleDescription: "High-energy astrophysics archive and catalog service.",
            contentsDescription: "X-ray, gamma-ray, ultraviolet, and mission catalog data for high-energy targets.",
            accessDescription: "Remote query source for specialized target enrichment.",
            sourceURL: URL(string: "https://heasarc.gsfc.nasa.gov/")!,
            appUse: "Future high-energy source cross-reference."
        ),
        AstronomyDatabaseSource(
            id: "jpl-small-body-database",
            name: "JPL Small-Body Database APIs",
            provider: "NASA/JPL",
            domain: .solarSystem,
            scaleDescription: "Authoritative orbital data and query APIs for small bodies.",
            contentsDescription: "Asteroids, comets, orbital elements, close approaches, observability, and Horizons-linked ephemerides.",
            accessDescription: "Remote query source; current app already uses JPL small-body observability for comets.",
            sourceURL: URL(string: "https://ssd.jpl.nasa.gov/api.html")!,
            appUse: "Primary solar-system backbone for comets, asteroids, and future ephemeris planning."
        ),
        AstronomyDatabaseSource(
            id: "minor-planet-center",
            name: "Minor Planet Center Orbits",
            provider: "International Astronomical Union Minor Planet Center",
            domain: .solarSystem,
            scaleDescription: "Primary global clearinghouse for minor-planet and comet astrometry/orbit data.",
            contentsDescription: "MPCORB-style orbit files, NEO services, comet data, designations, and observation-linked orbit services.",
            accessDescription: "Remote or selected-file update source; do not bundle the entire orbit stream by default.",
            sourceURL: URL(string: "https://minorplanetcenter.org/mpcops/orbits/")!,
            appUse: "Future asteroid and comet catalog expansion source."
        ),
        AstronomyDatabaseSource(
            id: "jpl-horizons",
            name: "JPL Horizons",
            provider: "NASA/JPL",
            domain: .solarSystem,
            scaleDescription: "Ephemeris service for solar-system bodies and spacecraft.",
            contentsDescription: "Precise positions, apparent coordinates, rise/set/transit data, and observer-centered ephemerides.",
            accessDescription: "Remote calculation source; cache only user-requested planning results.",
            sourceURL: URL(string: "https://ssd.jpl.nasa.gov/horizons/")!,
            appUse: "Future precise solar-system target position calculator."
        ),
        AstronomyDatabaseSource(
            id: "bigskyastro-local-common-dso",
            name: "BigSkyAstro Local Common Deep-Sky Catalog",
            provider: "BigSkyAstro",
            domain: .planningCatalog,
            scaleDescription: "Compiled directly with the app for the most common amateur-observing targets.",
            contentsDescription: "Messier, NGC, IC, Caldwell, Sharpless 2, and Lynds bright-nebula planning targets seeded from the local app resources.",
            accessDescription: "Bundled local database; used immediately offline while larger online databases remain transparent in the background.",
            sourceURL: URL(string: "https://github.com/mattiaverga/OpenNGC")!,
            appUse: "Primary compiled planning catalog; selected online targets are retained locally for observation until removed."
        ),
        AstronomyDatabaseSource(
            id: "bigskyastro-local-transient-seed",
            name: "BigSkyAstro Local Transient Seed Catalog",
            provider: "BigSkyAstro",
            domain: .planningCatalog,
            scaleDescription: "Small compiled fallback for common transient-style observing categories.",
            contentsDescription: "Seed comet, asteroid, and transient records used when live services are unavailable or still refreshing.",
            accessDescription: "Bundled local database; live JPL records update it when the app starts or when the observer refreshes manually.",
            sourceURL: URL(string: "https://ssd.jpl.nasa.gov/api.html")!,
            appUse: "Offline safety net for current-list planning and transparent live-refresh merging."
        ),
        AstronomyDatabaseSource(
            id: "openngc",
            name: "OpenNGC",
            provider: "OpenNGC project",
            domain: .planningCatalog,
            scaleDescription: "Practical amateur-observing deep-sky catalog for NGC, IC, Messier, and addendum targets.",
            contentsDescription: "NGC/IC objects, Messier cross-matches, addendum targets, common names, coordinates, magnitudes, and object types.",
            accessDescription: "Remote refresh source for compact offline planning targets; NED is the preferred online galaxy database.",
            sourceURL: URL(string: "https://github.com/mattiaverga/OpenNGC")!,
            appUse: "Offline/common-target seed for the current target list while NED remains the online galaxy backbone."
        ),
        AstronomyDatabaseSource(
            id: "aavso-vsx",
            name: "AAVSO Variable Star Index",
            provider: "AAVSO",
            domain: .planningCatalog,
            scaleDescription: "Large variable-star index for observer planning and identification.",
            contentsDescription: "Variable-star identifiers, coordinates, variability types, magnitude ranges, and periods.",
            accessDescription: "Remote query source for a future variable-star planning mode.",
            sourceURL: URL(string: "https://www.aavso.org/vsx/")!,
            appUse: "Future variable-star target database source."
        )
    ]

    static func sources(in domain: AstronomyDatabaseDomain) -> [AstronomyDatabaseSource] {
        sources.filter { $0.domain == domain }
    }
}
