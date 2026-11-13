// swift-tools-version: 6.0
import PackageDescription

let package = Package(
    name: "RemarkableShare",
    platforms: [.macOS(.v15)],
    targets: [
        // Pure, dependency-free logic (command building, checksums, auth seeding).
        // Everything here is unit-tested.
        .target(
            name: "RemarkableShareCore",
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        // The menu bar app itself (SwiftUI + WebKit). Bundled into a .app by scripts/build.sh.
        .executableTarget(
            name: "RemarkableShare",
            dependencies: ["RemarkableShareCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
        .testTarget(
            name: "RemarkableShareCoreTests",
            dependencies: ["RemarkableShareCore"],
            swiftSettings: [.swiftLanguageMode(.v5)]
        ),
    ]
)
