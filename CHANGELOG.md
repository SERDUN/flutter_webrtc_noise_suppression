## Unreleased

* `measure(engine:)` times an engine on the device: 3 s of white noise, mean and p99 per frame, attenuation.
* The detach line carries the call's time per frame: mean, p99, max and the frames over 10 ms.
* `attach(dumpInputSeconds:)`, Android only: the slot input written as a WAV on detach, for diagnostics.
* Engines by name: `NoiseSuppressorRegistry` (Android and iOS) takes an engine registered by the app or another plugin; `WebrtcNoiseSuppressionEngine` is a class named by that name, `engines()` lists them. RNNoise v0.1.1 (`rnnoise`) ships registered.
* `attach(engines:)` puts a chain of engines into the slot, run in order; one detach line per engine.
* A format adapter in front of an engine of another rate or frame length: low-pass, decimation by a whole factor, the engine's frames, interpolation; `measure` reports its delay as `latencyMs`.
* Engines are created off the main thread; an attach overtaken by a later attach or a detach answers false.

## 0.0.1

* Experimental. The noise_suppression plugin's suppressor (RNNoise v0.1.1) in flutter_webrtc's capture post-processing slot, Android and iOS, switched from Dart with `WebrtcNoiseSuppressionBridge.attach` / `detach`.
