// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "open-wispr",
    platforms: [.macOS(.v13)],
    targets: [
        .target(
            name: "CWhisper",
            path: "Sources/CWhisper",
            cSettings: [
                .headerSearchPath("include"),
                .unsafeFlags(["-I/opt/homebrew/include", "-I/usr/local/include"]),
            ],
            linkerSettings: [
                .unsafeFlags([
                    "-L/opt/homebrew/lib",
                    "-L/usr/local/lib",
                    "-lwhisper",
                    "-lggml",
                    "-Xlinker", "-rpath", "-Xlinker", "/opt/homebrew/lib",
                    "-Xlinker", "-rpath", "-Xlinker", "/usr/local/lib",
                ]),
            ]
        ),
        .target(
            name: "OpenWisprLib",
            dependencies: ["CWhisper"],
            path: "Sources/OpenWisprLib",
            linkerSettings: [
                .linkedFramework("CoreAudio"),
                .linkedFramework("AVFoundation"),
                .linkedFramework("AppKit"),
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
