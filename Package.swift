// swift-tools-version: 5.9
import PackageDescription

// Pixel Veil builds as a SwiftPM executable. Without Xcode we can't compile
// asset catalogs or the Metal `.metal` source, so:
//   * Assets.xcassets is excluded — SwiftUI falls back to the system accent.
//   * The .metal file is excluded; shaders are compiled from a Swift string
//     at runtime (see MetalPatternShaders.swift + MetalPatternView.swift).
// The .build output is post-processed into PixelVeil.app by build.sh.

let package = Package(
    name: "PixelVeil",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "PixelVeil",
            path: "PixelVeil",
            exclude: [
                "Resources/Info.plist",
                "Resources/PixelVeil.entitlements",
                "Resources/Assets.xcassets",
                "Shaders/PatternShaders.metal"
            ],
            linkerSettings: [
                .linkedFramework("Carbon"),
                .linkedFramework("ServiceManagement")
            ]
        )
    ]
)
