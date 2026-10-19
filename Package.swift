// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "Minority",
    platforms: [.macOS(.v15)],
    products: [
        .executable(name: "Minority", targets: ["Minority"]),
        .library(name: "MinorityPersistence", targets: ["MinorityPersistence"])
    ],
    dependencies: [
        .package(url: "https://github.com/groue/GRDB.swift.git", from: "7.0.0")
    ],
    targets: [
        .target(name: "MinorityPersistence", dependencies: [.product(name: "GRDB", package: "GRDB.swift")]),
        .executableTarget(name: "Minority", dependencies: ["MinorityPersistence"]),
        .executableTarget(name: "MinorityPersistenceChecks", dependencies: [
            "MinorityPersistence",
            .product(name: "GRDB", package: "GRDB.swift")
        ], path: "Tests/MinorityTests")
    ]
)
