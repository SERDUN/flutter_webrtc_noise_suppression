package com.portaone.flutter_webrtc_noise_suppression;

import java.nio.ByteBuffer;

/** {@link NoiseSuppressor} on RNNoise v0.1.1: 48 kHz mono, 480 samples per frame. */
public final class RnnoiseSuppressor implements NoiseSuppressor {
  static {
    System.loadLibrary("flutter_webrtc_noise_suppression");
  }

  private static final Result[] RESULTS = Result.values();

  private long handle;
  private int sampleRateHz;

  /** @throws OutOfMemoryError when the engine state cannot be allocated. */
  public RnnoiseSuppressor() {
    handle = nativeCreate();
    if (handle == 0) throw new OutOfMemoryError("noise suppressor state");
  }

  @Override
  public String engine() {
    return nativeEngine();
  }

  @Override
  public boolean initialize(int sampleRateHz) {
    if (handle == 0) return false;
    if (this.sampleRateHz != 0) nativeReset(handle);
    this.sampleRateHz = sampleRateHz;
    return sampleRateHz == nativeSampleRate();
  }

  @Override
  public Result process(ByteBuffer frame, int numSamples) {
    if (handle == 0 || frame == null || !frame.isDirect()) return Result.INVALID;
    if (frame.remaining() < numSamples * 4) return Result.INVALID;
    int code = nativeProcess(handle, sampleRateHz, numSamples, frame, frame.position());
    return code >= 0 && code < RESULTS.length ? RESULTS[code] : Result.INVALID;
  }

  @Override
  public void release() {
    if (handle != 0) {
      nativeDestroy(handle);
      handle = 0;
    }
  }

  /** Samples per frame the engine accepts. */
  public static int frameSize() {
    return nativeFrameSize();
  }

  /** The only sample rate the engine accepts, Hz. */
  public static int sampleRate() {
    return nativeSampleRate();
  }

  private static native long nativeCreate();

  private static native void nativeDestroy(long handle);

  private static native void nativeReset(long handle);

  private static native int nativeProcess(
      long handle, int sampleRateHz, int numSamples, ByteBuffer frame, int byteOffset);

  private static native String nativeEngine();

  private static native int nativeFrameSize();

  private static native int nativeSampleRate();
}
