// swift-tools-version: 5.9
import PackageDescription

// Three targets, one plugin: the C core (noise_suppressor.h + RNNoise), the suppressor's iOS
// interface on it (NSPNoiseSuppressor), and the flutter_webrtc add-on that hands captured frames to
// that interface. flutter_webrtc is a sibling package: Flutter lays the app's plugins out side by
// side and rewrites this path to the one flutter_webrtc gets there.
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
    ],
    targets: [
        // The C core. The Android build compiles the same files (android/src/main/cpp).
        .target(
            name: "NoiseSuppressionCore",
            path: "Sources/NoiseSuppressionCore",
            publicHeadersPath: "include",
            cSettings: [
                .headerSearchPath("rnnoise/include"),
                // RNNoise keeps its FFT state in a global called `common`.
                .define("common", to: "ns_rnnoise_common"),
            ]
        ),
        // The suppressor's interface, NSPNoiseSuppressor, and its RNNoise implementation. Knows
        // nothing about WebRTC.
        .target(
            name: "NoiseSuppression",
            dependencies: ["NoiseSuppressionCore"],
            path: "Sources/NoiseSuppression",
            publicHeadersPath: "include/NoiseSuppression"
        ),
        // The add-on: flutter_webrtc's capture slot to NSPNoiseSuppressor.
        .target(
            name: "flutter_webrtc_noise_suppression",
            dependencies: [
                "NoiseSuppression",
                .product(name: "FlutterFramework", package: "FlutterFramework"),
                .product(name: "flutter-webrtc", package: "flutter_webrtc"),
                .product(name: "WebRTC", package: "flutter_webrtc"),
            ],
            path: "Sources/flutter_webrtc_noise_suppression",
            resources: [
                .process("PrivacyInfo.xcprivacy")
            ]
        ),
    ]
)
