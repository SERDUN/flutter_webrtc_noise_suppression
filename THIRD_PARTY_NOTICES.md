# Third-party notices

## RNNoise

`ios/flutter_webrtc_noise_suppression/Sources/NoiseSuppressionCore/rnnoise/` is RNNoise v0.1.1 (xiph/rnnoise, commit `6cbfd53eb348a8d394e0757b4025c6ded34eb2b6`), Copyright (c) 2017-2024 Jean-Marc Valin, Mozilla, Xiph.Org Foundation and others, under its own BSD 3-Clause license: [rnnoise/COPYING](ios/flutter_webrtc_noise_suppression/Sources/NoiseSuppressionCore/rnnoise/COPYING). The Android build compiles the same files.

## RNNoise main

`ios/flutter_webrtc_noise_suppression/Sources/NoiseSuppressionRnnoise2/rnnoise/` is RNNoise from xiph/rnnoise main (gitlab.xiph.org, commit `70f1d256acd4b34a572f999a05c87bf00b67730d`, 2025) with its "little" model (`rnnoise_data_little.c` from `rnnoise_data-0a8755f8e2d834eff6a54714ecc7d75f9932e845df35f8b59bc52a7cfe6e8b37.tar.gz`, sha256 checked), Copyright (c) Jean-Marc Valin, Mozilla, Xiph.Org Foundation and others, under its BSD 3-Clause license: [rnnoise/COPYING](ios/flutter_webrtc_noise_suppression/Sources/NoiseSuppressionRnnoise2/rnnoise/COPYING). The vendored files are as published; `units/` and `rnnoise2_prefix.h` are this plugin's.
