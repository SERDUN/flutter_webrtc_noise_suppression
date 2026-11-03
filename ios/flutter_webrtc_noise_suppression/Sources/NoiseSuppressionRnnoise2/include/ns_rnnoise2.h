#ifndef NS_RNNOISE2_H
#define NS_RNNOISE2_H

#ifdef __cplusplus
extern "C" {
#endif

/* RNNoise from xiph/rnnoise main (70f1d25, 2025) with its "little" model: 48 kHz mono, 480-sample
 * frames of float samples on the int16 scale, processed in place. The only way into that build:
 * its own rnnoise.h shares names with the v0.1.1 one the core uses. */
typedef struct NsRnnoise2 NsRnnoise2;

/* Allocates a state; NULL when it cannot be allocated. */
NsRnnoise2* ns_rnnoise2_create(void);

void ns_rnnoise2_destroy(NsRnnoise2* state);

/* Denoises one frame in place; returns the voice probability, 0..1. */
float ns_rnnoise2_process_frame(NsRnnoise2* state, float* samples);

#ifdef __cplusplus
}
#endif

#endif
