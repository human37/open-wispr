// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "open-wispr",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "OpenWisprLib",
            path: "Sources/OpenWisprLib",
            linkerSettings: [
                .linkedFramework("CoreAudio"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AppKit"),
                .linkedFramework("CoreMedia"),
                .linkedFramework("ScreenCaptureKit"),
            ]
        ),
        .executableTarget(
            name: "open-wispr",
            dependencies: ["OpenWisprLib"],
            path: "Sources/OpenWispr"
        ),
        .testTarget(
            name: "OpenWisprTests",
            dependencies: ["OpenWisprLib"],
            path: "Tests/OpenWisprTests"
        ),
    ]
)
