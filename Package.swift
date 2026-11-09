// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "QuickAuth",
    platforms: [.macOS(.v13)],
    products: [.executable(name: "QuickAuth", targets: ["QuickAuth"])],
    targets: [
        .target(name: "CArgon2", exclude: ["LICENSE"], publicHeadersPath: "include",
                cSettings: [.headerSearchPath("src"), .define("ARGON2_NO_THREADS")]),
        .target(name: "QuickAuthCore", dependencies: ["CArgon2"]),
        .executableTarget(name: "QuickAuth", dependencies: ["QuickAuthCore"]),
        .testTarget(name: "QuickAuthCoreTests", dependencies: ["QuickAuthCore"],
                    resources: [.copy("Fixtures")])
    ]
)
