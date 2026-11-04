import Flutter
import UIKit
import flutter_webrtc_noise_suppression

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    // An engine of the app's own, registered without touching the plugin: the device tests put it
    // into a chain and measure it through the format adapter.
    NoiseSuppressorRegistry.register("example-identity-16k") { Identity16k() }
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)
  }
}

/// Leaves 10 ms frames of 16 kHz as they are.
private final class Identity16k: NSObject, NSPNoiseSuppressor {
  var engine: String { "example identity 16 kHz" }
  var engineSampleRate: Int { 16_000 }
  var engineFrameSize: Int { 160 }

  func initialize(withSampleRate sampleRateHz: Int) -> Bool { sampleRateHz == 16_000 }

  func processSamples(_ samples: UnsafeMutablePointer<Float>, count: Int) -> NSPNoiseSuppressorResult {
    count == 160 ? .processed : .unsupportedFrame
  }

  func releaseEngine() {}
}
