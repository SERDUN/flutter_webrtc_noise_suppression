package com.portaone.flutter_webrtc_noise_suppression;

import java.nio.ByteBuffer;

/**
 * Removes background noise from 10 ms frames of mono voice.
 *
 * <p>The package's contract on Android. It knows nothing about WebRTC: an audio pipeline (a bridge
 * to flutter_webrtc's capture post-processing, a recorder) adapts its own frames to this interface.
 *
 * <p>Threading: calls on one instance are serialized by the caller. {@link #process} never
 * allocates and is meant for the audio thread; {@link #initialize} and {@link #release} may
 * allocate or free.
 */
public interface NoiseSuppressor {
  /** What {@link #process} did with a frame. */
  enum Result {
    /** The frame was denoised in place. */
    PROCESSED,
    /** The sample rate is not supported; the frame is unchanged. */
    UNSUPPORTED_RATE,
    /** The frame length is not supported; the frame is unchanged. */
    UNSUPPORTED_FRAME,
    /** The buffer or the instance is not usable; the frame is unchanged. */
    INVALID
  }

  /** Engine name and version, for logs. */
  String engine();

  /**
   * Prepares for a stream of the given rate. Called again when the rate changes; the history of
   * the previous stream is dropped.
   *
   * @return false when the engine cannot run at this rate; {@link #process} then leaves frames
   *     unchanged.
   */
  boolean initialize(int sampleRateHz);

  /**
   * Denoises {@code numSamples} float samples on the int16 scale, in place.
   *
   * @param frame a direct buffer in native byte order; samples start at its position.
   */
  Result process(ByteBuffer frame, int numSamples);

  /** Frees the engine. The instance is not usable after this. */
  void release();
}
