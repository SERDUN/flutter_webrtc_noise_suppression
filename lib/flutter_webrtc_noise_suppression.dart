import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

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

  /// Puts the suppressor into the slot. True when it is there after the call; false when
  /// flutter_webrtc has no audio processing yet or the suppressor could not be created.
  Future<bool> attach() async => await _channel.invokeMethod<bool>('attach') ?? false;

  /// Takes the suppressor out of the slot. True when one was there.
  Future<bool> detach() async => await _channel.invokeMethod<bool>('detach') ?? false;
}
