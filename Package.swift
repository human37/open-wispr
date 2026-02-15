// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "open-wispr",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "open-wispr",
            path: "Sources/OpenWispr",
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("CoreAudio"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AppKit"),
            ]
        ),
    ]
)
