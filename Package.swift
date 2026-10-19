// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Minority",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Minority", targets: ["Minority"])
    ],
    targets: [
        .executableTarget(name: "Minority")
    ]
)
