// swift-tools-version: 5.10
import PackageDescription

let package = Package(
    name: "AppleFleetsMac",
    platforms: [.macOS(.v14)],
    products: [
        .executable(name: "applefleets", targets: ["AppleFleetsCLI"])
    ],
    dependencies: [
        .package(
            url: "https://github.com/skyblanket/swift-render.git",
            revision: "bf1f0cb60feea843ec8ca36c7f037db3aaf4de97"
        )
    ],
    targets: [
        .executableTarget(
            name: "AppleFleetsCLI",
            dependencies: [.product(name: "SwiftRender", package: "swift-render")]
        ),
        .testTarget(name: "AppleFleetsCLITests", dependencies: ["AppleFleetsCLI"])
    ]
)

