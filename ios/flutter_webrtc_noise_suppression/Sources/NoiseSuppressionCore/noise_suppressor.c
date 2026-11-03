#include "noise_suppressor.h"

#include <stdlib.h>
#include <string.h>

#include "rnnoise.h"

#define NS_RATE 48000
#define NS_FRAME 480

struct NsSuppressor {
  DenoiseState* state;
};

int ns_sample_rate(void) { return NS_RATE; }

int ns_frame_size(void) { return NS_FRAME; }

const char* ns_engine(void) { return "rnnoise 0.1.1"; }

static void warm_up(void) {
  /* RNNoise builds its FFT tables in process-wide storage on the first frame
   * it processes, with malloc. One frame of silence here keeps that off the
   * audio thread. */
  DenoiseState* scratch = rnnoise_create(NULL);
  if (scratch == NULL) return;
  float silence[NS_FRAME];
  memset(silence, 0, sizeof(silence));
  rnnoise_process_frame(scratch, silence, silence);
  rnnoise_destroy(scratch);
}

NsSuppressor* ns_create(void) {
  NsSuppressor* suppressor = (NsSuppressor*)calloc(1, sizeof(NsSuppressor));
  if (suppressor == NULL) return NULL;
  warm_up();
  suppressor->state = rnnoise_create(NULL);
  if (suppressor->state == NULL) {
    free(suppressor);
    return NULL;
  }
  return suppressor;
}

void ns_destroy(NsSuppressor* suppressor) {
  if (suppressor == NULL) return;
  if (suppressor->state != NULL) rnnoise_destroy(suppressor->state);
  free(suppressor);
}

int ns_reset(NsSuppressor* suppressor) {
  if (suppressor == NULL) return 0;
  /* rnnoise_init on a live state re-allocates its GRU buffers and leaks the
   * old ones, so a fresh state replaces the old one. */
  DenoiseState* fresh = rnnoise_create(NULL);
  if (fresh == NULL) return 0;
  rnnoise_destroy(suppressor->state);
  suppressor->state = fresh;
  return 1;
}

NsResult ns_process(NsSuppressor* suppressor, int sample_rate_hz, int num_samples, float* samples,
                    float* voice_probability) {
  if (suppressor == NULL || samples == NULL) return NS_INVALID;
  if (sample_rate_hz != NS_RATE) return NS_UNSUPPORTED_RATE;
  if (num_samples != NS_FRAME) return NS_UNSUPPORTED_FRAME;
  float vad = rnnoise_process_frame(suppressor->state, samples, samples);
  if (voice_probability != NULL) *voice_probability = vad;
  return NS_PROCESSED;
}
