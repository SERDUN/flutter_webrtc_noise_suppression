# Host checks of the C core. `make test` needs a C compiler only.
#
# The two RNNoise versions are compiled apart, each with its own include path: both ship a header
# named rnnoise.h. The newer one is built from its units/, which rename its globals.
SRC_DIR := ios/flutter_webrtc_noise_suppression/Sources
CORE := $(SRC_DIR)/NoiseSuppressionCore
RNN := $(CORE)/rnnoise/src
R2 := $(SRC_DIR)/NoiseSuppressionRnnoise2
CORE_SRC := $(CORE)/noise_suppressor.c $(RNN)/celt_lpc.c $(RNN)/denoise.c $(RNN)/kiss_fft.c \
            $(RNN)/pitch.c $(RNN)/rnn.c $(RNN)/rnn_data.c
R2_SRC := $(R2)/ns_rnnoise2.c $(wildcard $(R2)/units/*.c)
CFLAGS ?= -O2
BUILD := build/native

.PHONY: test clean
test: $(BUILD)/noise_suppressor_test
	$(BUILD)/noise_suppressor_test

$(BUILD)/rnnoise2.a: $(R2_SRC) $(wildcard $(R2)/rnnoise/src/*.c) $(R2)/rnnoise2_prefix.h
	mkdir -p $(BUILD)/r2
	cd $(BUILD)/r2 && for f in $(abspath $(R2_SRC)); do \
	  $(CC) $(CFLAGS) -c -I$(abspath $(R2)/rnnoise/include) -I$(abspath $(R2)/rnnoise/src) -I$(abspath $(R2)/include) -w $$f || exit 1; done
	ar rcs $@ $(BUILD)/r2/*.o

$(BUILD)/noise_suppressor_test: test/native/noise_suppressor_test.c $(CORE_SRC) $(CORE)/include/noise_suppressor.h $(BUILD)/rnnoise2.a
	$(CC) $(CFLAGS) -I$(CORE)/include -I$(CORE)/rnnoise/include -I$(R2)/include -Dcommon=ns_rnnoise_common \
	  -w test/native/noise_suppressor_test.c $(CORE_SRC) $(BUILD)/rnnoise2.a -lm -o $@

clean:
	rm -rf build
