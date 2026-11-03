/* Every global symbol of the vendored RNNoise (xiph/rnnoise main 70f1d25), renamed with ns2_.
 *
 * The plugin also carries RNNoise v0.1.1, whose globals have the same names (rnnoise_create,
 * rnn_fft_*, rnn_pitch_*, ...). Each unit in units/ includes this header before its vendored source,
 * so both versions link into one library and the vendored files stay as they were published.
 * The list is `nm -g --defined-only` of the compiled sources; a symbol missing here is a
 * duplicate-symbol error at link time, not a silent mix-up. */
#ifndef NS_RNNOISE2_PREFIX_H
#define NS_RNNOISE2_PREFIX_H
#define compute_rnn ns2_compute_rnn
#define eband20ms ns2_eband20ms
#define init_rnnoise ns2_init_rnnoise
#define rnn_autocorr ns2_rnn_autocorr
#define rnn_biquad ns2_rnn_biquad
#define rnn_compute_activation_c ns2_rnn_compute_activation_c
#define rnn_compute_conv2d_c ns2_rnn_compute_conv2d_c
#define rnn_compute_frame_features ns2_rnn_compute_frame_features
#define rnn_compute_generic_conv1d ns2_rnn_compute_generic_conv1d
#define rnn_compute_generic_dense ns2_rnn_compute_generic_dense
#define rnn_compute_generic_gru ns2_rnn_compute_generic_gru
#define rnn_compute_glu ns2_rnn_compute_glu
#define rnn_compute_linear_c ns2_rnn_compute_linear_c
#define rnn_conv2d_init ns2_rnn_conv2d_init
#define rnn_dct_table ns2_rnn_dct_table
#define rnn_fft_alloc ns2_rnn_fft_alloc
#define rnn_fft_alloc_arch_c ns2_rnn_fft_alloc_arch_c
#define rnn_fft_alloc_twiddles ns2_rnn_fft_alloc_twiddles
#define rnn_fft_c ns2_rnn_fft_c
#define rnn_fft_free ns2_rnn_fft_free
#define rnn_fft_free_arch_c ns2_rnn_fft_free_arch_c
#define rnn_fft_impl ns2_rnn_fft_impl
#define rnn_frame_analysis ns2_rnn_frame_analysis
#define rnn_half_window ns2_rnn_half_window
#define rnn_ifft_c ns2_rnn_ifft_c
#define rnn_kfft ns2_rnn_kfft
#define rnn_linear_init ns2_rnn_linear_init
#define rnn_lpc ns2_rnn_lpc
#define rnn_parse_weights ns2_rnn_parse_weights
#define rnn_pitch_downsample ns2_rnn_pitch_downsample
#define rnn_pitch_filter ns2_rnn_pitch_filter
#define rnn_pitch_search ns2_rnn_pitch_search
#define rnn_pitch_xcorr ns2_rnn_pitch_xcorr
#define rnn_remove_doubling ns2_rnn_remove_doubling
#define rnnoise_arrays ns2_rnnoise_arrays
#define rnnoise_create ns2_rnnoise_create
#define rnnoise_destroy ns2_rnnoise_destroy
#define rnnoise_get_frame_size ns2_rnnoise_get_frame_size
#define rnnoise_get_size ns2_rnnoise_get_size
#define rnnoise_init ns2_rnnoise_init
#define rnnoise_model_free ns2_rnnoise_model_free
#define rnnoise_model_from_buffer ns2_rnnoise_model_from_buffer
#define rnnoise_model_from_file ns2_rnnoise_model_from_file
#define rnnoise_model_from_filename ns2_rnnoise_model_from_filename
#define rnnoise_process_frame ns2_rnnoise_process_frame
#endif
