/*
 * Noise suppressor: removes background noise from 10 ms frames of mono voice.
 *
 * This is the whole contract of the package. It knows nothing about WebRTC or
 * any other audio stack: a caller that owns an audio pipeline (a bridge to
 * flutter_webrtc, a recorder) hands frames in and gets them back denoised.
 *
 * Engines (NsEngine), both RNNoise (xiph, BSD-3-Clause): v0.1.1, and the 2025
 * code of xiph/rnnoise main with its "little" model. Both work on 48 kHz mono
 * only, exactly 480 samples (10 ms) per frame, float samples on the int16 scale
 * (-32768..32767). A frame of any other shape is left unchanged and the call
 * says so, so the caller can fall back to its own processing.
 *
 * Threading. Calls on one suppressor must be serialized by the caller.
 * ns_process never allocates and is meant for the audio thread. ns_create,
 * ns_destroy and ns_reset allocate or free: call them off the audio thread, or
 * where the pipeline already reinitializes (a rate change), never per frame.
 * Different suppressors are independent.
 */
#ifndef NOISE_SUPPRESSOR_H
#define NOISE_SUPPRESSOR_H

#ifdef __cplusplus
extern "C" {
#endif

typedef struct NsSuppressor NsSuppressor;

/* The engine a suppressor runs. */
typedef enum NsEngine {
  NS_ENGINE_RNNOISE = 0,        /* RNNoise v0.1.1: ~90 KB of weights, the cheapest */
  NS_ENGINE_RNNOISE_LITTLE = 1  /* RNNoise main (2025), little model: ~5 MB of weights, about 2.3x
                                   the CPU of v0.1.1, much stronger on other voices */
} NsEngine;

/* Result of ns_process. */
typedef enum NsResult {
  NS_PROCESSED = 0,         /* the frame was denoised in place */
  NS_UNSUPPORTED_RATE = 1,  /* sample rate is not 48000 Hz; frame unchanged */
  NS_UNSUPPORTED_FRAME = 2, /* frame is not 480 samples; frame unchanged */
  NS_INVALID = 3            /* NULL suppressor or samples; frame unchanged */
} NsResult;

/* The only sample rate the engine accepts, Hz. */
int ns_sample_rate(void);

/* Samples per frame the engine accepts (10 ms at ns_sample_rate()). */
int ns_frame_size(void);

/* Name and version of the default engine (NS_ENGINE_RNNOISE), a static string, e.g. "rnnoise 0.1.1". */
const char* ns_engine(void);

/* Name and version of an engine, a static string; NULL for an unknown one. */
const char* ns_engine_name(NsEngine engine);

/*
 * Creates a suppressor. Also builds the engine's process-wide tables (RNNoise
 * allocates them lazily on the first frame), so the first ns_process on the
 * audio thread does not allocate. Returns NULL when memory runs out.
 */
NsSuppressor* ns_create(void);

/* ns_create with a chosen engine. Returns NULL for an unknown engine or when memory runs out. */
NsSuppressor* ns_create_engine(NsEngine engine);

/* The engine a suppressor runs; NS_ENGINE_RNNOISE for NULL. */
NsEngine ns_suppressor_engine(const NsSuppressor* suppressor);

/* Frees a suppressor. NULL is ignored. */
void ns_destroy(NsSuppressor* suppressor);

/*
 * Forgets the history of the stream (a new call, a rate change of the source).
 * Allocates a fresh engine state. Returns 1 on success, 0 when memory ran out
 * or suppressor is NULL; on 0 the old state is kept.
 */
int ns_reset(NsSuppressor* suppressor);

/*
 * Denoises one frame in place. sample_rate_hz and num_samples describe the
 * frame; anything but 48000 / 480 leaves it unchanged. On NS_PROCESSED and
 * when voice_probability is not NULL, it receives the engine's estimate that
 * the frame holds voice, 0..1.
 */
NsResult ns_process(NsSuppressor* suppressor, int sample_rate_hz, int num_samples, float* samples,
                    float* voice_probability);

#ifdef __cplusplus
}
#endif

#endif
