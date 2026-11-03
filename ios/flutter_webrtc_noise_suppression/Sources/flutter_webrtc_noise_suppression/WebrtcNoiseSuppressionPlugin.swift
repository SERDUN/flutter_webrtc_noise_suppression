import Flutter
import Foundation
import WebRTC
import flutter_webrtc
import noise_suppression
import os.log

/// Puts an `NSPNoiseSuppressor` into flutter_webrtc's capture post-processing slot.
///
/// The two plugins know nothing about each other: flutter_webrtc offers the slot through
/// `ExternalAudioProcessingDelegate` and `AudioManager.capturePostProcessingAdapter`,
/// noise_suppression offers `NSPNoiseSuppressor`. This plugin is the only place that joins them,
/// so neither depends on the other and the suppressor can be replaced without touching
/// flutter_webrtc.
///
/// flutter_webrtc keeps one `AudioManager` for the process, so the slot, and the state here, are
/// process-wide: one attached processor covers every call, whichever engine asked. Every method
/// call runs on the main thread.
public final class WebrtcNoiseSuppressionPlugin: NSObject, FlutterPlugin {
  private static let channelName = "com.portaone.flutter_webrtc_noise_suppression"
  private static let log = OSLog(subsystem: "com.portaone.flutter_webrtc_noise_suppression", category: "WebrtcNoiseSuppression")
  private static var processor: SuppressorFrameProcessor?
  // Two lines a call, at the default level: the device log keeps and streams it for any subsystem,
  // while an info line of a subsystem it has no configuration for may never reach a reader.

  public static func register(with registrar: FlutterPluginRegistrar) {
    let channel = FlutterMethodChannel(name: channelName, binaryMessenger: registrar.messenger())
    registrar.addMethodCallDelegate(WebrtcNoiseSuppressionPlugin(), channel: channel)
  }

  public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
    switch call.method {
    case "attach":
      result(Self.attach())
    case "detach":
      result(Self.detach())
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// Returns true when a suppressor is in the slot after the call.
  private static func attach() -> Bool {
    if processor != nil { return true }
    guard let suppressor = NSPRnnoiseSuppressor() else {
      // The call keeps the platform processing only, which is what it had before.
      os_log("not attached: suppressor not created", log: log, type: .error)
      return false
    }
    let created = SuppressorFrameProcessor(suppressor: suppressor)
    AudioManager.sharedInstance().capturePostProcessingAdapter.addProcessing(created)
    processor = created
    os_log("attached %{public}@", log: log, type: .default, suppressor.engine)
    return true
  }

  /// Returns true when a suppressor was in the slot and has been removed.
  private static func detach() -> Bool {
    guard let attached = processor else { return false }
    // The adapter calls processors under the lock that removeProcessing: takes, so once it
    // returns no frame is in flight and the engine can be freed.
    AudioManager.sharedInstance().capturePostProcessingAdapter.removeProcessing(attached)
    attached.releaseEngine()
    processor = nil
    os_log("detached: %{public}@", log: log, type: .default, attached.summary())
    return true
  }
}

/// Adapts flutter_webrtc's frames to `NSPNoiseSuppressor`.
///
/// libwebrtc calls it on the capture thread with 10 ms of audio after its own processing (and,
/// with voice processing on, after Apple's echo cancellation, noise suppression and gain
/// control), right before the encoder. The adapter serializes all three callbacks under one
/// lock. The buffer of channel 0 is full band even when the frame reports several bands: the
/// post-processor runs after the bands were merged back.
private final class SuppressorFrameProcessor: NSObject, ExternalAudioProcessingDelegate {
  private let suppressor: NSPNoiseSuppressor
  private var initialized = false
  private var processed = 0
  private var unchanged = 0
  private var lastResult: NSPNoiseSuppressorResult?
  private var announced = ""

  init(suppressor: NSPNoiseSuppressor) {
    self.suppressor = suppressor
  }

  func audioProcessingInitialize(withSampleRate sampleRateHz: Int, channels: Int) {
    note("initialize(\(sampleRateHz), \(channels))")
    suppressor.initialize(withSampleRate: sampleRateHz)
    initialized = true
  }

  func audioProcessingProcess(_ audioBuffer: RTCAudioBuffer) {
    guard audioBuffer.channels > 0 else { return }
    let frames = audioBuffer.frames
    // A processor added while the microphone is already running is never told the rate: the
    // adapter announces it only when the stream starts. A frame is 10 ms, so its length gives the
    // rate. The first initialize allocates nothing.
    if !initialized {
      suppressor.initialize(withSampleRate: frames * 100)
      initialized = true
    }
    // A frame the engine cannot take comes back unchanged, so the call keeps the audio it would
    // have had without the suppressor.
    let result = suppressor.processSamples(audioBuffer.rawBuffer(forChannel: 0), count: frames)
    if result == .processed { processed += 1 } else { unchanged += 1 }
    if result != lastResult {
      lastResult = result
      note("result \(result.rawValue) at frame \(processed + unchanged) (\(frames) samples, \(audioBuffer.bands) bands)")
    }
  }

  func audioProcessingRelease() {
    // The engine belongs to the plugin and is freed on detach.
  }

  /// The call's one log line: how many frames were denoised and how many left unchanged (a rate or
  /// length the engine does not take), and what the slot announced. Read after the processor left
  /// the slot, so no frame is counted at the same time.
  func summary() -> String {
    "processed=\(processed) unchanged=\(unchanged) \(announced)"
  }

  func releaseEngine() {
    suppressor.releaseEngine()
  }

  private func note(_ event: String) {
    if announced.count < 400 { announced += "[\(event)]" }
  }
}
