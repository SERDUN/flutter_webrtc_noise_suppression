# Host checks of the C core. `make test` needs a C compiler only.
CORE := ios/flutter_webrtc_noise_suppression/Sources/NoiseSuppressionCore
RNN := $(CORE)/rnnoise/src
SRC := $(CORE)/noise_suppressor.c $(RNN)/celt_lpc.c $(RNN)/denoise.c $(RNN)/kiss_fft.c \
       $(RNN)/pitch.c $(RNN)/rnn.c $(RNN)/rnn_data.c
CFLAGS ?= -O2
BUILD := build/native

.PHONY: test clean
test: $(BUILD)/noise_suppressor_test
	$(BUILD)/noise_suppressor_test

$(BUILD)/noise_suppressor_test: test/native/noise_suppressor_test.c $(SRC) $(CORE)/include/noise_suppressor.h
	mkdir -p $(BUILD)
	$(CC) $(CFLAGS) -I$(CORE)/include -I$(CORE)/rnnoise/include -Dcommon=ns_rnnoise_common \
	  -w test/native/noise_suppressor_test.c $(SRC) -lm -o $@

clean:
	rm -rf build
