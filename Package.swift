// swift-tools-version: 5.9
import PackageDescription

// The shared package intentionally contains no Apple framework.  The XcodeGen
// project described in project.yml assembles the SwiftUI and platform targets
// around these products on a Mac runner.
let package = Package(
    name: "Polygo",
    defaultLocalization: "fr",
    platforms: [
        .iOS(.v17),
        .macOS(.v14)
    ],
    products: [
        .library(name: "PolygoCore", targets: ["PolygoCore"]),
        .library(name: "PolygoSRS", targets: ["PolygoSRS"]),
        .library(name: "PolygoPersistence", targets: ["PolygoPersistence"])
    ],
    targets: [
        .target(
            name: "PolygoCore",
            path: "Sources/PolygoCore"
        ),
        // These paths are owned by the persistence and scheduler workers.  The
        // declarations live here so the eventual package has one stable graph.
        .target(
            name: "PolygoSRS",
            dependencies: ["PolygoCore"],
            path: "Sources/PolygoSRS"
        ),
        .target(
            name: "PolygoPersistence",
            dependencies: ["PolygoCore", "PolygoSRS"],
            path: "Sources/PolygoPersistence"
        ),
        .testTarget(
            name: "PolygoCoreTests",
            dependencies: ["PolygoCore"],
            path: "Tests/PolygoCoreTests"
        ),
        .testTarget(
            name: "PolygoSRSTests",
            dependencies: ["PolygoSRS", "PolygoCore"],
            path: "Tests/PolygoSRSTests"
        ),
        .testTarget(
            name: "PolygoPersistenceTests",
            dependencies: ["PolygoPersistence", "PolygoSRS", "PolygoCore"],
            path: "Tests/PolygoPersistenceTests"
        )
    ]
)
