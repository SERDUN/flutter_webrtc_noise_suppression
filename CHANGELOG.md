## Unreleased

* `measure(engine:)` times an engine on the device: 3 s of white noise, mean and p99 per frame, attenuation.
* The detach line carries the call's time per frame: mean, p99, max and the frames over 10 ms.
* `attach(dumpInputSeconds:)`, Android only: the slot input written as a WAV on detach, for diagnostics.
* Engines by name: an internal `NoiseSuppressorRegistry` (Android and iOS), where a new engine of the plugin is one line; `WebrtcNoiseSuppressionEngine` is a class of the engines the plugin ships, RNNoise v0.1.1 (`rnnoise`). An app cannot register its own engine.
* `attach(engines:)` puts a chain of engines into the slot, run in order; one detach line per engine.
* A format adapter in front of an engine of another rate or frame length, both ways: down (low-pass, decimation by a whole factor, the engine's frames, interpolation) and up (interpolation, the engine's frames, decimation). RNNoise now denoises calls on G.711 and G.722, where libwebrtc's slot runs at 16 kHz and every frame used to pass unchanged; `measure` reports the adapter's delay as `latencyMs`.
* Engines are created off the main thread; an attach overtaken by a later attach or a detach answers false.

## 0.0.1

* Experimental. The noise_suppression plugin's suppressor (RNNoise v0.1.1) in flutter_webrtc's capture post-processing slot, Android and iOS, switched from Dart with `WebrtcNoiseSuppressionBridge.attach` / `detach`.
