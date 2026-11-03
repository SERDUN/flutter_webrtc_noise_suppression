/* Host test of the C core: make test (needs only a C compiler). */
#include <math.h>
#include <stdio.h>
#include <stdlib.h>

#include "noise_suppressor.h"

static int failures = 0;

#define CHECK(cond, msg)                         \
  do {                                           \
    if (!(cond)) {                               \
      fprintf(stderr, "FAIL: %s\n", msg);        \
      failures++;                                \
    }                                            \
  } while (0)

static double rms(const float* x, int n) {
  double s = 0;
  for (int i = 0; i < n; i++) s += (double)x[i] * x[i];
  return sqrt(s / n);
}

/* Deterministic white noise on the int16 scale. */
static unsigned int seed = 12345;
static float noise_sample(float amplitude) {
  seed = seed * 1103515245u + 12345u;
  return amplitude * (((float)((seed >> 8) & 0xffff) / 32768.0f) - 1.0f);
}

int main(void) {
  CHECK(ns_sample_rate() == 48000, "sample rate is 48000");
  CHECK(ns_frame_size() == 480, "frame size is 480");

  NsSuppressor* s = ns_create();
  CHECK(s != NULL, "create");

  float frame[480];
  for (int i = 0; i < 480; i++) frame[i] = 1000.0f;
  CHECK(ns_process(s, 16000, 480, frame, NULL) == NS_UNSUPPORTED_RATE, "16 kHz refused");
  CHECK(frame[0] == 1000.0f && frame[479] == 1000.0f, "refused frame unchanged (rate)");
  CHECK(ns_process(s, 48000, 160, frame, NULL) == NS_UNSUPPORTED_FRAME, "160 samples refused");
  CHECK(frame[0] == 1000.0f, "refused frame unchanged (size)");
  CHECK(ns_process(NULL, 48000, 480, frame, NULL) == NS_INVALID, "NULL suppressor");
  CHECK(ns_process(s, 48000, 480, NULL, NULL) == NS_INVALID, "NULL samples");

  /* 3 s of steady white noise: after the model settles the output is far
   * quieter than the input. */
  double in_rms = 0, out_rms = 0;
  float vad = -1;
  for (int f = 0; f < 300; f++) {
    for (int i = 0; i < 480; i++) frame[i] = noise_sample(3000.0f);
    double r_in = rms(frame, 480);
    CHECK(ns_process(s, 48000, 480, frame, &vad) == NS_PROCESSED, "48 kHz / 480 processed");
    if (f >= 100) {
      in_rms += r_in;
      out_rms += rms(frame, 480);
    }
  }
  double attenuation_db = 20.0 * log10(in_rms / (out_rms + 1e-9));
  printf("white noise attenuation: %.1f dB, last vad %.3f\n", attenuation_db, vad);
  CHECK(attenuation_db > 10.0, "white noise attenuated by more than 10 dB");
  CHECK(vad >= 0.0f && vad <= 1.0f, "voice probability in 0..1");

  /* Silence stays silence once the overlap of the last noisy frame is out. */
  for (int f = 0; f < 5; f++) {
    for (int i = 0; i < 480; i++) frame[i] = 0.0f;
    ns_process(s, 48000, 480, frame, NULL);
  }
  printf("silence rms after noise: %g\n", rms(frame, 480));
  CHECK(rms(frame, 480) < 10.0, "silence stays below -70 dBFS");

  CHECK(ns_reset(s) == 1, "reset");
  CHECK(ns_reset(NULL) == 0, "reset NULL");
  for (int i = 0; i < 480; i++) frame[i] = noise_sample(3000.0f);
  CHECK(ns_process(s, 48000, 480, frame, NULL) == NS_PROCESSED, "process after reset");

  ns_destroy(s);
  ns_destroy(NULL);

  if (failures) {
    fprintf(stderr, "%d failure(s)\n", failures);
    return 1;
  }
  printf("ok\n");
  return 0;
}
