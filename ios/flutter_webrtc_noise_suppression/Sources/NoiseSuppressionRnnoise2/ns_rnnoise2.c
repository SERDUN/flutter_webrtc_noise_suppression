#include "rnnoise2_prefix.h"

#include "include/ns_rnnoise2.h"
#include "rnnoise.h"

/* NULL is the model compiled in: the little one (units/ns2_rnnoise_data_little.c). */
NsRnnoise2* ns_rnnoise2_create(void) { return (NsRnnoise2*)rnnoise_create(NULL); }

void ns_rnnoise2_destroy(NsRnnoise2* state) {
  if (state != NULL) rnnoise_destroy((DenoiseState*)state);
}

float ns_rnnoise2_process_frame(NsRnnoise2* state, float* samples) {
  return rnnoise_process_frame((DenoiseState*)state, samples, samples);
}
