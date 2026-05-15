// swift-tools-version:5.9
import PackageDescription

let package = Package(
    name: "Parcelite",
    platforms: [.macOS(.v13)],
    products: [
        .executable(name: "Parcelite", targets: ["Parcelite"]),
        .library(name: "ParceliteCore", targets: ["ParceliteCore"]),
    ],
    targets: [
        .target(name: "ParceliteCore", path: "Sources/ParceliteCore"),
        .executableTarget(
            name: "Parcelite",
            dependencies: ["ParceliteCore"],
            path: "Sources/Parcelite"
        ),
        .testTarget(
            name: "ParceliteCoreTests",
            dependencies: ["ParceliteCore"],
            path: "Tests/ParceliteCoreTests",
            resources: [.process("Fixtures")]
        ),
    ]
)
