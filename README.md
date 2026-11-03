# flutter_webrtc_noise_suppression

A [flutter_webrtc](https://github.com/flutter-webrtc/flutter-webrtc) add-on: noise suppression of the voice an app sends. It puts the suppressor of [noise_suppression](https://github.com/SERDUN/noise_suppression) into flutter_webrtc's capture post-processing slot, after the platform's echo cancellation and noise suppression and right before the encoder. Android and iOS. Experimental.

## The two plugins

| Plugin | What it is | Depends on |
|---|---|---|
| `noise_suppression` | the suppressor behind its own interface (`NoiseSuppressor`, `NSPNoiseSuppressor`, C `noise_suppressor.h`); knows nothing about WebRTC | nothing |
| `flutter_webrtc_noise_suppression` (this one) | the add-on: takes flutter_webrtc's captured frames and hands them to that interface | `flutter_webrtc`, `noise_suppression` |

flutter_webrtc offers the slot through public interfaces: `AudioProcessingAdapter.ExternalAudioFrameProcessing` on Android, `ExternalAudioProcessingDelegate` and `AudioManager.capturePostProcessingAdapter` on iOS. Nothing is looked up by name, and nothing goes into the app's `MainActivity` or `AppDelegate`: the plugin is registered by `GeneratedPluginRegistrant` like any other.

## Use

```yaml
dependencies:
  flutter_webrtc_noise_suppression:
    git:
      url: https://github.com/SERDUN/flutter_webrtc_noise_suppression.git
      ref: <commit>
```

```dart
const bridge = WebrtcNoiseSuppressionBridge();
await bridge.attach(); // true: the suppressor is in the slot; every call's microphone is denoised
await bridge.detach(); // true: it was there and is out
```

`attach` returns false when flutter_webrtc has not built its factory yet (it does on its first use: `getUserMedia`, `createPeerConnection`) or the suppressor cannot be created; the audio is then left as it was. Attach when the microphone track opens and detach when it stops. On detach the native side logs one line: `detached: processed=N unchanged=M [what the slot announced]` (logcat tag `WebrtcNoiseSuppression`, os_log subsystem `com.portaone.flutter_webrtc_noise_suppression`).

## Pins

This plugin is made for flutter_webrtc's fork `portaone/flutter-webrtc` at `po/1.6.3-1` and noise_suppression at `9c84a59`; its `pubspec.yaml` names both. An app takes the same specs - pub resolves one copy of each for the whole app, so a spec that differs is a resolution error.

## Traps

- **Android engines.** Each Flutter engine has its own flutter_webrtc plugin. Each engine also gets its own instance of this plugin, which reaches the flutter_webrtc of that engine, never `FlutterWebRTCPlugin.sharedSingleton`: that names the engine created last, and in an app with background engines (push, call services) it may be one whose factory is never initialized.
- **Android libwebrtc.** `AudioProcessingAdapter` extends libwebrtc's `ExternalAudioProcessingFactory.AudioProcessing`, and flutter_webrtc takes libwebrtc as `implementation`, so `android/build.gradle` names it `compileOnly` at flutter_webrtc's version (`io.github.webrtc-sdk:android:150.7871.04`). Change both together.
- **iOS is process-wide.** flutter_webrtc keeps one `AudioManager` for the process: one attached suppressor covers every engine.
- **The rate.** A processor added while the microphone already runs is never told the rate; the length of the first frame (10 ms) gives it.
- **iOS log level.** The two lines a call are os_log's default level: on an iPhone the log stream dropped info lines of this subsystem.
- iOS 15.0 is the lowest target (noise_suppression's; Xcode 27 accepts nothing older). The iOS build goes through Swift Package Manager (`ios/flutter_webrtc_noise_suppression/Package.swift` names `../flutter_webrtc` and `../noise_suppression`, the siblings Flutter lays out); the podspec has not been built.

## Checks

```sh
flutter analyze && flutter test
cd example && flutter test integration_test   # on a device: attach, attach again, detach, detach again
cd example/ios && xcodebuild test -workspace Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,name=<iPhone>' -only-testing:RunnerTests
```

## License

BSD 3-Clause, see [LICENSE](LICENSE).
