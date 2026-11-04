#include "noise_suppressor.h"

#include <stdlib.h>
#include <string.h>

#include "rnnoise.h"

#define NS_RATE 48000
#define NS_FRAME 480

struct NsSuppressor {
  NsEngine engine;
  DenoiseState* state;
};

int ns_sample_rate(void) { return NS_RATE; }

int ns_frame_size(void) { return NS_FRAME; }

const char* ns_engine(void) { return ns_engine_name(NS_ENGINE_RNNOISE); }

const char* ns_engine_name(NsEngine engine) {
  switch (engine) {
    case NS_ENGINE_RNNOISE:
      return "rnnoise 0.1.1";
  }
  return NULL;
}

static void warm_up(void) {
  /* RNNoise v0.1.1 builds its FFT tables in process-wide storage on the first
   * frame it processes, with malloc. One frame of silence here keeps that off
   * the audio thread. */
  DenoiseState* scratch = rnnoise_create(NULL);
  if (scratch == NULL) return;
  float silence[NS_FRAME];
  memset(silence, 0, sizeof(silence));
  rnnoise_process_frame(scratch, silence, silence);
  rnnoise_destroy(scratch);
}

NsSuppressor* ns_create(void) { return ns_create_engine(NS_ENGINE_RNNOISE); }

NsSuppressor* ns_create_engine(NsEngine engine) {
  if (ns_engine_name(engine) == NULL) return NULL;
  NsSuppressor* suppressor = (NsSuppressor*)calloc(1, sizeof(NsSuppressor));
  if (suppressor == NULL) return NULL;
  suppressor->engine = engine;
  warm_up();
  suppressor->state = rnnoise_create(NULL);
  if (suppressor->state == NULL) {
    free(suppressor);
    return NULL;
  }
  return suppressor;
}

NsEngine ns_suppressor_engine(const NsSuppressor* suppressor) {
  return suppressor == NULL ? NS_ENGINE_RNNOISE : suppressor->engine;
}

void ns_destroy(NsSuppressor* suppressor) {
  if (suppressor == NULL) return;
  rnnoise_destroy(suppressor->state);
  free(suppressor);
}

int ns_reset(NsSuppressor* suppressor) {
  if (suppressor == NULL) return 0;
  /* rnnoise_init on a live state re-allocates its GRU buffers and leaks the
   * old ones, so a fresh state replaces the old one. */
  DenoiseState* state = rnnoise_create(NULL);
  if (state == NULL) return 0;
  rnnoise_destroy(suppressor->state);
  suppressor->state = state;
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
