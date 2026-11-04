# flutter_webrtc_noise_suppression

A [flutter_webrtc](https://github.com/flutter-webrtc/flutter-webrtc) add-on: noise suppression of the voice an app sends. RNNoise runs in flutter_webrtc's capture post-processing slot, after the platform's echo cancellation and noise suppression and right before the encoder. Android and iOS. Experimental.

## Engines

| `WebrtcNoiseSuppressionEngine` | What | Weights | CPU (M5 host, per 10 ms frame) |
|---|---|---|---|
| `rnnoise` (default) | RNNoise v0.1.1 | ~90 KB | ~80 us |

`measure(engine:)` gives the time per frame and the attenuation on the device it runs on.

## Inside

| Layer | Where | Knows about |
|---|---|---|
| C core: `noise_suppressor.h` over RNNoise (48 kHz, 480-sample frames), engine chosen at creation | `ios/flutter_webrtc_noise_suppression/Sources/NoiseSuppressionCore` (Android compiles the same files, `android/src/main/cpp`) | nothing |
| The suppressor's interface: `NoiseSuppressor` / `RnnoiseSuppressor` (Android, JNI), `NSPNoiseSuppressor` / `NSPRnnoiseSuppressor` (iOS) | `android/src/main/java`, `ios/.../Sources/NoiseSuppression` | the C core only |
| The add-on: `WebrtcNoiseSuppressionPlugin`, which takes flutter_webrtc's captured frames and hands them to the interface | `android/src/main/kotlin`, `ios/.../Sources/flutter_webrtc_noise_suppression` | flutter_webrtc and the interface |
| Dart: `WebrtcNoiseSuppressionBridge` (`attach`, `detach`) | `lib/` | the channel |

The add-on works with the suppressor only through its interface, so another engine is another implementation of `NoiseSuppressor` and the add-on does not change. flutter_webrtc is reached through its public interfaces: `AudioProcessingAdapter.ExternalAudioFrameProcessing` on Android, `ExternalAudioProcessingDelegate` and `AudioManager.capturePostProcessingAdapter` on iOS. Nothing is looked up by name, and nothing goes into the app's `MainActivity` or `AppDelegate`: the plugin is registered by `GeneratedPluginRegistrant` like any other.

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

## Requirements

`flutter_webrtc: ^1.6.3`. The capture slot, the Android controller's accessor and the SPM `WebRTC` product the plugin uses are flutter_webrtc's public API (checked at `v1.6.3`; the slot itself is there since `v1.0.0`).

## Traps

- **Android engines.** Each Flutter engine has its own flutter_webrtc plugin. Each engine also gets its own instance of this plugin, which reaches the flutter_webrtc of that engine, never `FlutterWebRTCPlugin.sharedSingleton`: that names the engine created last, and in an app with background engines (push, call services) it may be one whose factory is never initialized.
- **Android libwebrtc.** `AudioProcessingAdapter` extends libwebrtc's `ExternalAudioProcessingFactory.AudioProcessing`, and flutter_webrtc takes libwebrtc as `implementation`, so `android/build.gradle` names it `compileOnly` at upstream 1.6.3's version (`io.github.webrtc-sdk:android:150.7871.04`). Only the `AudioProcessing` interface is used, and the app's flutter_webrtc brings the libwebrtc that runs.
- **iOS is process-wide.** flutter_webrtc keeps one `AudioManager` for the process: one attached suppressor covers every engine.
- **The rate.** A processor added while the microphone already runs is never told the rate; the length of the first frame (10 ms) gives it.
- **iOS log level.** The two lines a call are os_log's default level: on an iPhone the log stream dropped info lines of this subsystem.
- **The example's Xcode project.** `flutter create --template=plugin` puts a reference to `ios/flutter_webrtc_noise_suppression` into the example's Runner project, for editing. Xcode then resolves that original `Package.swift`, whose `../flutter_webrtc` exists only in the copy Flutter writes to `build/ios/SourcePackages` (with the paths rewritten to the hashed names git dependencies get), and the build stops with `cannot be accessed`. The reference is removed here; apps never had it.
- **The example's build directory.** With Swift Package Manager Flutter copies the whole plugin directory, `example/` included, into `example/build/ios/SourcePackages`, so every iOS build nests the copy of the one before it, until a build stops with `Failed to copy plugin ... Assertion failed: (pathbufsz > fts_pathlen)`. Run `flutter clean` in `example/` when that happens. An app that takes the plugin from git has no such directory in its copy.
- **RNNoise main and x86.** On x86 ABIs (emulators) the newer RNNoise takes its SSE path, which needs `x86/x86cpu.h` and `rnnoise/src` on the include path; run-time CPU detection is off.
- **RNNoise 0.2 tag.** The `v0.2` tag does not build on ARM or without SIMD (`vec.h` names an `os_support.h` it does not ship); main fixed that, which is one reason main is vendored, not the tag.
- **RNNoise's global.** RNNoise keeps its FFT state in a global named `common`; every build defines `common=ns_rnnoise_common` so it cannot collide with another library in the process.
- **RNNoise's first frame.** RNNoise builds its FFT tables with `malloc` on the first frame; `ns_create` runs one frame of silence so that happens off the audio thread. `rnnoise_init` on a live state leaks its buffers; `ns_reset` replaces the state instead (it allocates, so not per frame).
- iOS 15.0 is the lowest target (Xcode 27 accepts nothing older). The iOS build goes through Swift Package Manager (`ios/flutter_webrtc_noise_suppression/Package.swift` names `../flutter_webrtc`, the sibling Flutter lays out); the podspec has not been built.

## Checks

```sh
make test                 # the C core on the host: white noise attenuated by more than 10 dB, bad frames untouched
flutter analyze && flutter test
cd example && flutter test integration_test   # on a device: attach, attach again, detach, detach again
cd example/ios && xcodebuild test -workspace Runner.xcworkspace -scheme Runner \
  -destination 'platform=iOS Simulator,name=<iPhone>' -only-testing:RunnerTests
```

## License

BSD 3-Clause, see [LICENSE](LICENSE). RNNoise is under its own BSD 3-Clause license: [THIRD_PARTY_NOTICES.md](THIRD_PARTY_NOTICES.md).
