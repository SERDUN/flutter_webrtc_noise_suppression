#include "noise_suppressor.h"

#include <stdatomic.h>
#include <stdlib.h>
#include <string.h>

#include "rnnoise.h"

#define NS_RATE 48000
#define NS_FRAME 480

struct NsSuppressor {
  NsEngine engine;
  DenoiseState* state;
  /* RNNoise's output is one frame behind its input, so a mix with the input
   * as it arrives would comb-filter the voice; `dry` holds the frame before. */
  float dry[NS_FRAME];
  _Atomic float level;
  float applied; /* the level the last frame ended on; audio thread only */
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
  atomic_init(&suppressor->level, 1.0f);
  suppressor->applied = 1.0f;
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
  memset(suppressor->dry, 0, sizeof(suppressor->dry));
  return 1;
}

void ns_set_suppression_level(NsSuppressor* suppressor, float level) {
  if (suppressor == NULL) return;
  /* The comparison is written so that NaN also lands on 1. */
  float clamped = level >= 0.0f ? (level < 1.0f ? level : 1.0f) : (level < 0.0f ? 0.0f : 1.0f);
  atomic_store_explicit(&suppressor->level, clamped, memory_order_relaxed);
}

float ns_suppression_level(const NsSuppressor* suppressor) {
  if (suppressor == NULL) return 1.0f;
  return atomic_load_explicit(&((NsSuppressor*)suppressor)->level, memory_order_relaxed);
}

/* Mixes the denoised `wet` with the frame before `input`, ramping from the last
 * frame's level to `target`, and keeps `input` for the next frame. */
static void mix(NsSuppressor* suppressor, float* wet, const float* input, float target) {
  float gain = suppressor->applied;
  const float step = (target - gain) / NS_FRAME;
  for (int i = 0; i < NS_FRAME; i++) {
    gain += step;
    wet[i] = gain * wet[i] + (1.0f - gain) * suppressor->dry[i];
  }
  suppressor->applied = target;
}

NsResult ns_process(NsSuppressor* suppressor, int sample_rate_hz, int num_samples, float* samples,
                    float* voice_probability) {
  if (suppressor == NULL || samples == NULL) return NS_INVALID;
  if (sample_rate_hz != NS_RATE) return NS_UNSUPPORTED_RATE;
  if (num_samples != NS_FRAME) return NS_UNSUPPORTED_FRAME;
  float input[NS_FRAME];
  memcpy(input, samples, sizeof(input));
  float vad = rnnoise_process_frame(suppressor->state, samples, samples);
  const float target = atomic_load_explicit(&suppressor->level, memory_order_relaxed);
  if (target < 1.0f || suppressor->applied < 1.0f) mix(suppressor, samples, input, target);
  memcpy(suppressor->dry, input, sizeof(input));
  if (voice_probability != NULL) *voice_probability = vad;
  return NS_PROCESSED;
}
