cmake_minimum_required(VERSION 3.18.1)
project(flutter_webrtc_noise_suppression C)

# The C sources are one copy, inside the iOS Swift package (SwiftPM cannot reach
# sources outside its package directory); Android builds the same files.
set(SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/../../../../ios/flutter_webrtc_noise_suppression/Sources")
set(CORE "${SOURCES}/NoiseSuppressionCore")
set(RNN "${CORE}/rnnoise/src")

add_library(flutter_webrtc_noise_suppression SHARED
  noise_suppressor_jni.c
  "${CORE}/noise_suppressor.c"
  "${RNN}/celt_lpc.c"
  "${RNN}/denoise.c"
  "${RNN}/kiss_fft.c"
  "${RNN}/pitch.c"
  "${RNN}/rnn.c"
  "${RNN}/rnn_data.c"
)

target_include_directories(flutter_webrtc_noise_suppression PRIVATE "${CORE}/include" "${CORE}/rnnoise/include")

# RNNoise v0.1.1 keeps its FFT state in a global called `common`; give it a name
# no other library in the process can collide with.
target_compile_definitions(flutter_webrtc_noise_suppression PRIVATE common=ns_rnnoise_common)

# The engine is optimized in debug builds too; only the JNI entry points are
# exported; the vendored RNNoise sources are compiled as they are.
target_compile_options(flutter_webrtc_noise_suppression PRIVATE -O3 -fvisibility=hidden -w)

target_link_libraries(flutter_webrtc_noise_suppression m)
