#include "noise_suppressor.h"

#include <stdlib.h>
#include <string.h>

#include "ns_rnnoise2.h"
#include "rnnoise.h"

#define NS_RATE 48000
#define NS_FRAME 480

/* One engine state; which member is set follows the engine. */
struct NsSuppressor {
  NsEngine engine;
  DenoiseState* v01;
  NsRnnoise2* v2;
};

int ns_sample_rate(void) { return NS_RATE; }

int ns_frame_size(void) { return NS_FRAME; }

const char* ns_engine(void) { return ns_engine_name(NS_ENGINE_RNNOISE); }

const char* ns_engine_name(NsEngine engine) {
  switch (engine) {
    case NS_ENGINE_RNNOISE:
      return "rnnoise 0.1.1";
    case NS_ENGINE_RNNOISE_LITTLE:
      return "rnnoise main-70f1d25 little";
  }
  return NULL;
}

/* A fresh state of the engine into *suppressor; 0 when it cannot be allocated. */
static int new_state(NsEngine engine, DenoiseState** v01, NsRnnoise2** v2) {
  if (engine == NS_ENGINE_RNNOISE) {
    *v01 = rnnoise_create(NULL);
    return *v01 != NULL;
  }
  *v2 = ns_rnnoise2_create();
  return *v2 != NULL;
}

static void free_state(DenoiseState* v01, NsRnnoise2* v2) {
  if (v01 != NULL) rnnoise_destroy(v01);
  ns_rnnoise2_destroy(v2);
}

static void process(NsSuppressor* suppressor, float* samples, float* vad) {
  if (suppressor->engine == NS_ENGINE_RNNOISE) {
    *vad = rnnoise_process_frame(suppressor->v01, samples, samples);
  } else {
    *vad = ns_rnnoise2_process_frame(suppressor->v2, samples);
  }
}

static void warm_up(NsEngine engine) {
  /* RNNoise v0.1.1 builds its FFT tables in process-wide storage on the first
   * frame it processes, with malloc. One frame of silence here keeps that off
   * the audio thread; the other engine gets the same, in case it does too. */
  NsSuppressor scratch = {engine, NULL, NULL};
  if (!new_state(engine, &scratch.v01, &scratch.v2)) return;
  float silence[NS_FRAME];
  float vad;
  memset(silence, 0, sizeof(silence));
  process(&scratch, silence, &vad);
  free_state(scratch.v01, scratch.v2);
}

NsSuppressor* ns_create(void) { return ns_create_engine(NS_ENGINE_RNNOISE); }

NsSuppressor* ns_create_engine(NsEngine engine) {
  if (ns_engine_name(engine) == NULL) return NULL;
  NsSuppressor* suppressor = (NsSuppressor*)calloc(1, sizeof(NsSuppressor));
  if (suppressor == NULL) return NULL;
  suppressor->engine = engine;
  warm_up(engine);
  if (!new_state(engine, &suppressor->v01, &suppressor->v2)) {
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
  free_state(suppressor->v01, suppressor->v2);
  free(suppressor);
}

int ns_reset(NsSuppressor* suppressor) {
  if (suppressor == NULL) return 0;
  /* rnnoise_init on a live state re-allocates its GRU buffers and leaks the
   * old ones, so a fresh state replaces the old one. */
  DenoiseState* v01 = NULL;
  NsRnnoise2* v2 = NULL;
  if (!new_state(suppressor->engine, &v01, &v2)) return 0;
  free_state(suppressor->v01, suppressor->v2);
  suppressor->v01 = v01;
  suppressor->v2 = v2;
  return 1;
}

NsResult ns_process(NsSuppressor* suppressor, int sample_rate_hz, int num_samples, float* samples,
                    float* voice_probability) {
  if (suppressor == NULL || samples == NULL) return NS_INVALID;
  if (sample_rate_hz != NS_RATE) return NS_UNSUPPORTED_RATE;
  if (num_samples != NS_FRAME) return NS_UNSUPPORTED_FRAME;
  float vad;
  process(suppressor, samples, &vad);
  if (voice_probability != NULL) *voice_probability = vad;
  return NS_PROCESSED;
}
