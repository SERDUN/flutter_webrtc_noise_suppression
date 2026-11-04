## Unreleased

* `measure(engine:)` times an engine on the device: 3 s of white noise, mean and p99 per frame, attenuation.
* The detach line carries the call's time per frame: mean, p99, max and the frames over 10 ms.
* `attach(dumpInputSeconds:)`, Android only: the slot input written as a WAV on detach, for diagnostics.
* The `engine` parameter of `attach` and `measure`; RNNoise v0.1.1 (`rnnoise`) is the one engine.

## 0.0.1

* Experimental. The noise_suppression plugin's suppressor (RNNoise v0.1.1) in flutter_webrtc's capture post-processing slot, Android and iOS, switched from Dart with `WebrtcNoiseSuppressionBridge.attach` / `detach`.
