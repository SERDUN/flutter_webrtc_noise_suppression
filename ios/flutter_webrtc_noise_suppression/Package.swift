// swift-tools-version: 5.9
import PackageDescription

// Flutter puts every plugin's package side by side (ios/Flutter/ephemeral/Packages/.packages), so
// the two plugins this one joins are its siblings, as FlutterFramework is.
let package = Package(
    name: "flutter_webrtc_noise_suppression",
    platforms: [
        .iOS("15.0")
    ],
    products: [
        .library(name: "flutter-webrtc-noise-suppression", targets: ["flutter_webrtc_noise_suppression"])
    ],
    dependencies: [
        .package(name: "FlutterFramework", path: "../FlutterFramework"),
        .package(name: "flutter_webrtc", path: "../flutter_webrtc"),
        .package(name: "noise_suppression", path: "../noise_suppression"),
    ],
    targets: [
        .target(
            name: "flutter_webrtc_noise_suppression",
            dependencies: [
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "flutter-webrtc", package: "flutter_webrtc"),
                .product(name: "WebRTC", package: "flutter_webrtc"),
                .product(name: "noise-suppression", package: "noise_suppression"),
            ],
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        )
    ]
)
