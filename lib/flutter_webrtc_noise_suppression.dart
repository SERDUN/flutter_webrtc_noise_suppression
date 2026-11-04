import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// An engine of the suppressor, by the name the native side registered it under.
///
/// [rnnoise] ships with the plugin. Another engine is registered natively (Android
/// `NoiseSuppressorRegistry.register`, iOS `NoiseSuppressorRegistry.register`) by the app or another
/// plugin, and named here with `const WebrtcNoiseSuppressionEngine('its-name')`;
/// [WebrtcNoiseSuppressionBridge.engines] lists what the native side has.
@immutable
class WebrtcNoiseSuppressionEngine {
  const WebrtcNoiseSuppressionEngine(this.wire);

  /// RNNoise v0.1.1: strong on steady and impulsive noise, weak on other voices.
  static const rnnoise = WebrtcNoiseSuppressionEngine('rnnoise');

  /// The name the native side knows it by.
  final String wire;

  @override
  bool operator ==(Object other) => other is WebrtcNoiseSuppressionEngine && other.wire == wire;

  @override
  int get hashCode => wire.hashCode;

  @override
  String toString() => 'WebrtcNoiseSuppressionEngine($wire)';
}

/// Noise suppression in flutter_webrtc's capture post-processing slot, switched from Dart.
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

  /// Puts a chain of [engines] into the slot: every frame goes through them in this order. A chain
  /// already there is taken out first; the same chain again is left as it is. True when the chain
  /// is there after the call; false when flutter_webrtc has no audio processing yet, an engine could
  /// not be created, or a later [attach] or a [detach] came while the engines were being created
  /// (they are created off the main thread, a model may take most of a second). An engine the
  /// native side has not registered fails the call with a [PlatformException] `unknown_engine`.
  ///
  /// [dumpInputSeconds] is diagnostics, Android only: the first that many seconds of what reaches
  /// the slot, before the suppressor, are kept and written on detach as a 48 kHz 16-bit WAV into the
  /// app's external files directory (`adb pull` reads it from a release build).
  Future<bool> attach({
    List<WebrtcNoiseSuppressionEngine> engines = const [WebrtcNoiseSuppressionEngine.rnnoise],
    int dumpInputSeconds = 0,
  }) async =>
      await _channel.invokeMethod<bool>('attach', {
        'engines': [for (final e in engines) e.wire],
        if (dumpInputSeconds > 0) 'dumpInputSeconds': dumpInputSeconds,
      }) ??
      false;

  /// The engines the native side has registered, by name.
  Future<List<WebrtcNoiseSuppressionEngine>> engines() async => [
    for (final name in await _channel.invokeListMethod<String>('engines') ?? const <String>[])
      WebrtcNoiseSuppressionEngine(name),
  ];

  /// Runs 3 s of white noise through a fresh suppressor of [engine] on this device, outside the
  /// slot but through the same format adapter: the time per 10 ms frame, the attenuation and the
  /// delay the adapter adds. A check that the engine fits the phone's audio thread, not a
  /// measurement of call quality.
  Future<WebrtcNoiseSuppressionMeasurement> measure({
    WebrtcNoiseSuppressionEngine engine = WebrtcNoiseSuppressionEngine.rnnoise,
  }) async {
    final map = await _channel.invokeMapMethod<String, Object?>('measure', {'engine': engine.wire}) ?? const {};
    return WebrtcNoiseSuppressionMeasurement(
      engine: map['engine'] as String? ?? '',
      meanUs: (map['meanUs'] as num?)?.toDouble() ?? double.nan,
      p99Us: (map['p99Us'] as num?)?.toDouble() ?? double.nan,
      attenuationDb: (map['attenuationDb'] as num?)?.toDouble() ?? double.nan,
      latencyMs: (map['latencyMs'] as num?)?.toDouble() ?? 0,
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
    this.latencyMs = 0,
  });

  /// The engine's name and version, as the native side reports it.
  final String engine;

  /// Mean and 99th percentile time per 10 ms frame, microseconds: the budget is 10000.
  final double meanUs;
  final double p99Us;

  /// White noise in against out once the model has settled, dB.
  final double attenuationDb;

  /// The delay the format adapter adds for an engine of another rate or frame length, ms; 0 for an
  /// engine that takes the slot's frames as they are.
  final double latencyMs;

  @override
  String toString() =>
      '$engine: mean ${meanUs.toStringAsFixed(0)} us, p99 ${p99Us.toStringAsFixed(0)} us, '
      'attenuation ${attenuationDb.toStringAsFixed(1)} dB'
      '${latencyMs > 0 ? ', adapter delay ${latencyMs.toStringAsFixed(1)} ms' : ''}';
}
