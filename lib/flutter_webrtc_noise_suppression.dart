import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// An engine of the suppressor.
enum WebrtcNoiseSuppressionEngine {
  /// RNNoise v0.1.1: the cheapest; strong on steady and impulsive noise, weak on other voices.
  rnnoise('rnnoise'),

  /// RNNoise main (2025) with its little model: about 2.3x the CPU of [rnnoise] and about 5 MB of
  /// weights; much stronger on other voices.
  rnnoiseLittle('rnnoise-little');

  const WebrtcNoiseSuppressionEngine(this.wire);

  /// The name the native side knows it by.
  final String wire;
}

/// RNNoise in flutter_webrtc's capture post-processing slot, switched from Dart.
///
/// The native side of this plugin (Android `WebrtcNoiseSuppressionPlugin`, iOS
/// `WebrtcNoiseSuppressionPlugin`) puts the noise_suppression plugin's suppressor into the slot,
/// after the platform's own echo cancellation and noise suppression and before the encoder.
/// Android binds it to the engine that called; iOS keeps one for the process.
class WebrtcNoiseSuppressionBridge {
  const WebrtcNoiseSuppressionBridge({@visibleForTesting MethodChannel? channel})
    : _channel = channel ?? const MethodChannel(channelName);

  /// The channel the native side answers on.
  static const channelName = 'com.portaone.flutter_webrtc_noise_suppression';

  final MethodChannel _channel;

  /// Whether the native side exists on this platform: Android and iOS only.
  static bool get isSupported =>
      !kIsWeb && (defaultTargetPlatform == TargetPlatform.android || defaultTargetPlatform == TargetPlatform.iOS);

  /// Puts a suppressor of [engine] into the slot; one of another engine is taken out first. True
  /// when it is there after the call; false when flutter_webrtc has no audio processing yet or the
  /// suppressor could not be created.
  ///
  /// [dumpInputSeconds] is diagnostics, Android only: the first that many seconds of what reaches
  /// the slot, before the suppressor, are kept and written on detach as a 48 kHz 16-bit WAV into the
  /// app's external files directory (`adb pull` reads it from a release build).
  Future<bool> attach({
    WebrtcNoiseSuppressionEngine engine = WebrtcNoiseSuppressionEngine.rnnoise,
    int dumpInputSeconds = 0,
  }) async =>
      await _channel.invokeMethod<bool>('attach', {
        'engine': engine.wire,
        if (dumpInputSeconds > 0) 'dumpInputSeconds': dumpInputSeconds,
      }) ??
      false;

  /// Runs 3 s of white noise through a fresh suppressor of [engine] on this device, outside the
  /// slot: the time per 10 ms frame and the attenuation. A check that the engine fits the phone's
  /// audio thread, not a measurement of call quality.
  Future<WebrtcNoiseSuppressionMeasurement> measure({
    WebrtcNoiseSuppressionEngine engine = WebrtcNoiseSuppressionEngine.rnnoise,
  }) async {
    final map = await _channel.invokeMapMethod<String, Object?>('measure', {'engine': engine.wire}) ?? const {};
    return WebrtcNoiseSuppressionMeasurement(
      engine: map['engine'] as String? ?? '',
      meanUs: (map['meanUs'] as num?)?.toDouble() ?? double.nan,
      p99Us: (map['p99Us'] as num?)?.toDouble() ?? double.nan,
      attenuationDb: (map['attenuationDb'] as num?)?.toDouble() ?? double.nan,
    );
  }

  /// Takes the suppressor out of the slot. True when one was there.
  Future<bool> detach() async => await _channel.invokeMethod<bool>('detach') ?? false;
}

/// What [WebrtcNoiseSuppressionBridge.measure] saw on the device.
@immutable
class WebrtcNoiseSuppressionMeasurement {
  const WebrtcNoiseSuppressionMeasurement({
    required this.engine,
    required this.meanUs,
    required this.p99Us,
    required this.attenuationDb,
  });

  /// The engine's name and version, as the native side reports it.
  final String engine;

  /// Mean and 99th percentile time per 10 ms frame, microseconds: the budget is 10000.
  final double meanUs;
  final double p99Us;

  /// White noise in against out once the model has settled, dB.
  final double attenuationDb;

  @override
  String toString() =>
      '$engine: mean ${meanUs.toStringAsFixed(0)} us, p99 ${p99Us.toStringAsFixed(0)} us, '
      'attenuation ${attenuationDb.toStringAsFixed(1)} dB';
}
