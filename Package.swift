// swift-tools-version: 6.2
import PackageDescription

let package = Package(
    name: "AstronomyObservationPlanning",
    platforms: [
        .macOS(.v15)
    ],
    products: [
        .executable(
            name: "AstronomyObservationPlanning",
            targets: ["AstronomyObservationPlanning"]
        )
    ],
    targets: [
        .executableTarget(
            name: "AstronomyObservationPlanning",
            path: "Sources",
            resources: [
                .process("Resources")
            ]
        ),
        .testTarget(
            name: "AstronomyObservationPlanningTests",
            dependencies: ["AstronomyObservationPlanning"],
            path: "Tests/AstronomyObservationPlanningTests"
        )
    ]
)
