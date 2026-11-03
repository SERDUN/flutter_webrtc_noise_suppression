import Flutter
import Foundation
import WebRTC
import flutter_webrtc
import NoiseSuppression
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
      let engine = (call.arguments as? [String: Any])?["engine"] as? String
      guard let model = Self.model(engine) else {
        result(FlutterError(code: "unknown_engine", message: "unknown engine \(engine ?? "")", details: nil))
        return
      }
      result(Self.attach(model))
    case "detach":
      result(Self.detach())
    case "measure":
      let engine = (call.arguments as? [String: Any])?["engine"] as? String
      guard let model = Self.model(engine) else {
        result(FlutterError(code: "unknown_engine", message: "unknown engine \(engine ?? "")", details: nil))
        return
      }
      // 3 s of audio is a few hundred ms of work on a slow phone: off the main thread.
      DispatchQueue.global(qos: .userInitiated).async {
        let measured = Self.measure(model)
        DispatchQueue.main.async { result(measured) }
      }
    default:
      result(FlutterMethodNotImplemented)
    }
  }

  /// The engine names of the Dart API; a missing one is RNNoise v0.1.1.
  private static func model(_ engine: String?) -> NSPRnnoiseModel? {
    switch engine {
    case nil, "rnnoise": return NSPRnnoiseModel.v0_1
    case "rnnoise-little": return NSPRnnoiseModel.little
    default: return nil
    }
  }

  /// Returns true when a suppressor of `model` is in the slot after the call. One of another model is
  /// taken out first: the slot holds one suppressor at a time.
  private static func attach(_ model: NSPRnnoiseModel) -> Bool {
    if let attached = processor {
      if attached.model == model { return true }
      _ = detach()
    }
    guard let suppressor = NSPRnnoiseSuppressor(model: model) else {
      // The call keeps the platform processing only, which is what it had before.
      os_log("not attached: suppressor not created", log: log, type: .error)
      return false
    }
    let created = SuppressorFrameProcessor(suppressor: suppressor, model: model)
    AudioManager.sharedInstance().capturePostProcessingAdapter.addProcessing(created)
    processor = created
    os_log("attached %{public}@", log: log, type: .default, suppressor.engine)
    return true
  }

  /// Runs 3 s of white noise through a fresh suppressor of `model`, frame by frame as the slot would:
  /// the time per frame on this phone and the attenuation once the model has settled (the first
  /// second is skipped). A check of the engine on a device, not of call quality.
  private static func measure(_ model: NSPRnnoiseModel) -> Any {
    guard let suppressor = NSPRnnoiseSuppressor(model: model) else {
      return FlutterError(code: "no_engine", message: "suppressor not created", details: nil)
    }
    defer { suppressor.releaseEngine() }
    _ = suppressor.initialize(withSampleRate: NSPRnnoiseSuppressor.sampleRate)
    let n = NSPRnnoiseSuppressor.frameSize
    var frame = [Float](repeating: 0, count: n)
    var seed: UInt32 = 12345
    var times = [Double]()
    var inRms = 0.0, outRms = 0.0
    for f in 0..<300 {
      for i in 0..<n {
        seed = seed &* 1103515245 &+ 12345
        frame[i] = 3000 * (Float((seed >> 8) & 0xffff) / 32768 - 1)
      }
      let before = sqrt(frame.reduce(0.0) { $0 + Double($1 * $1) } / Double(n))
      let start = DispatchTime.now().uptimeNanoseconds
      _ = frame.withUnsafeMutableBufferPointer { suppressor.processSamples($0.baseAddress!, count: n) }
      times.append(Double(DispatchTime.now().uptimeNanoseconds - start) / 1000)
      if f >= 100 {
        inRms += before
        outRms += sqrt(frame.reduce(0.0) { $0 + Double($1 * $1) } / Double(n))
      }
    }
    times.sort()
    return [
      "engine": suppressor.engine,
      "meanUs": times.reduce(0, +) / Double(times.count),
      "p99Us": times[times.count * 99 / 100],
      "attenuationDb": 20 * log10(inRms / outRms),
    ] as [String: Any]
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
  let model: NSPRnnoiseModel
  private var initialized = false
  private var processed = 0
  private var unchanged = 0
  private var lastResult: NSPNoiseSuppressorResult?
  private var announced = ""

  // Time per frame in the call, without allocating on the audio thread: 200 us buckets up to 20 ms,
  // the last one for everything longer.
  private static let bucketNs: UInt64 = 200_000
  private static let bucketCount = 100
  private var buckets = [Int](repeating: 0, count: SuppressorFrameProcessor.bucketCount + 1)
  private var totalNs: UInt64 = 0
  private var maxNs: UInt64 = 0

  init(suppressor: NSPNoiseSuppressor, model: NSPRnnoiseModel) {
    self.suppressor = suppressor
    self.model = model
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
    let start = DispatchTime.now().uptimeNanoseconds
    let result = suppressor.processSamples(audioBuffer.rawBuffer(forChannel: 0), count: frames)
    let spent = DispatchTime.now().uptimeNanoseconds - start
    totalNs += spent
    maxNs = max(maxNs, spent)
    buckets[min(Int(spent / Self.bucketNs), Self.bucketCount)] += 1
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
    let frames = processed + unchanged
    let meanUs = frames == 0 ? 0 : totalNs / UInt64(frames) / 1000
    let overBudget = buckets[Int(10_000_000 / Self.bucketNs)...].reduce(0, +)
    return "\(suppressor.engine) processed=\(processed) unchanged=\(unchanged) mean_us=\(meanUs)"
      + " p99_us=\(percentileUs(0.99)) max_us=\(maxNs / 1000) over_10ms=\(overBudget) \(announced)"
  }

  /// The upper edge of the bucket the `q` quantile falls in; the last bucket reads as its floor.
  private func percentileUs(_ q: Double) -> UInt64 {
    let frames = buckets.reduce(0, +)
    if frames == 0 { return 0 }
    var seen = 0
    for (i, count) in buckets.enumerated() {
      seen += count
      if Double(seen) >= q * Double(frames) {
        return UInt64(i == Self.bucketCount ? i : i + 1) * Self.bucketNs / 1000
      }
    }
    return UInt64(Self.bucketCount) * Self.bucketNs / 1000
  }

  func releaseEngine() {
    suppressor.releaseEngine()
  }

  private func note(_ event: String) {
    if announced.count < 400 { announced += "[\(event)]" }
  }
}
