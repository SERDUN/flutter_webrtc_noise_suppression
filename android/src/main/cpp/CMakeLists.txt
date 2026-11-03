cmake_minimum_required(VERSION 3.18.1)
project(flutter_webrtc_noise_suppression C)

# The C sources are one copy, inside the iOS Swift package (SwiftPM cannot reach
# sources outside its package directory); Android builds the same files.
set(SOURCES "${CMAKE_CURRENT_SOURCE_DIR}/../../../../ios/flutter_webrtc_noise_suppression/Sources")
set(CORE "${SOURCES}/NoiseSuppressionCore")
set(RNN "${CORE}/rnnoise/src")
set(R2 "${SOURCES}/NoiseSuppressionRnnoise2")

# The two RNNoise versions are compiled apart, each with its own include path:
# both ship a header named rnnoise.h. The newer one is built from its units/,
# which rename its globals (rnnoise2_prefix.h), so both link into one library.
add_library(ns_rnnoise2 OBJECT
  "${R2}/ns_rnnoise2.c"
  "${R2}/units/ns2_celt_lpc.c"
  "${R2}/units/ns2_denoise.c"
  "${R2}/units/ns2_kiss_fft.c"
  "${R2}/units/ns2_nnet.c"
  "${R2}/units/ns2_nnet_default.c"
  "${R2}/units/ns2_parse_lpcnet_weights.c"
  "${R2}/units/ns2_pitch.c"
  "${R2}/units/ns2_rnn.c"
  "${R2}/units/ns2_rnnoise_data_little.c"
  "${R2}/units/ns2_rnnoise_tables.c"
)
target_include_directories(ns_rnnoise2 PRIVATE "${R2}/include" "${R2}/rnnoise/include" "${R2}/rnnoise/src")
target_compile_options(ns_rnnoise2 PRIVATE -O3 -fvisibility=hidden -w)

add_library(flutter_webrtc_noise_suppression SHARED
  noise_suppressor_jni.c
  "${CORE}/noise_suppressor.c"
  "${RNN}/celt_lpc.c"
  "${RNN}/denoise.c"
  "${RNN}/kiss_fft.c"
  "${RNN}/pitch.c"
  "${RNN}/rnn.c"
  "${RNN}/rnn_data.c"
  $<TARGET_OBJECTS:ns_rnnoise2>
)

target_include_directories(flutter_webrtc_noise_suppression PRIVATE "${CORE}/include" "${CORE}/rnnoise/include" "${R2}/include")

# RNNoise v0.1.1 keeps its FFT state in a global called `common`; give it a name
# no other library in the process can collide with.
target_compile_definitions(flutter_webrtc_noise_suppression PRIVATE common=ns_rnnoise_common)

# The engine is optimized in debug builds too; only the JNI entry points are
# exported; the vendored RNNoise sources are compiled as they are.
target_compile_options(flutter_webrtc_noise_suppression PRIVATE -O3 -fvisibility=hidden -w)

target_link_libraries(flutter_webrtc_noise_suppression m)
