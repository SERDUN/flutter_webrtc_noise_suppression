# Host checks of the C core. `make test` needs a C compiler only.
SRC_DIR := ios/flutter_webrtc_noise_suppression/Sources
CORE := $(SRC_DIR)/NoiseSuppressionCore
RNN := $(CORE)/rnnoise/src
CORE_SRC := $(CORE)/noise_suppressor.c $(RNN)/celt_lpc.c $(RNN)/denoise.c $(RNN)/kiss_fft.c \
            $(RNN)/pitch.c $(RNN)/rnn.c $(RNN)/rnn_data.c
CFLAGS ?= -O2
BUILD := build/native

.PHONY: test clean
test: $(BUILD)/noise_suppressor_test
	$(BUILD)/noise_suppressor_test

$(BUILD)/noise_suppressor_test: test/native/noise_suppressor_test.c $(CORE_SRC) $(CORE)/include/noise_suppressor.h
	mkdir -p $(BUILD)
	$(CC) $(CFLAGS) -I$(CORE)/include -I$(CORE)/rnnoise/include -Dcommon=ns_rnnoise_common \
	  -w test/native/noise_suppressor_test.c $(CORE_SRC) -lm -o $@

clean:
	rm -rf build
