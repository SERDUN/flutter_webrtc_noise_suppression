#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/// What -processSamples:count: did with a frame.
typedef NS_ENUM(NSInteger, NSPNoiseSuppressorResult) {
  /// The frame was denoised in place.
  NSPNoiseSuppressorResultProcessed = 0,
  /// The sample rate is not supported; the frame is unchanged.
  NSPNoiseSuppressorResultUnsupportedRate = 1,
  /// The frame length is not supported; the frame is unchanged.
  NSPNoiseSuppressorResultUnsupportedFrame = 2,
  /// The samples or the instance are not usable; the frame is unchanged.
  NSPNoiseSuppressorResultInvalid = 3,
};

/// Removes background noise from 10 ms frames of mono voice.
///
/// The package's contract on iOS. It knows nothing about WebRTC: an audio pipeline (a bridge to
/// flutter_webrtc's capture post-processing, a recorder) adapts its own frames to this protocol.
///
/// Threading: calls on one instance are serialized by the caller. -processSamples:count: never
/// allocates and is meant for the audio thread; -initializeWithSampleRate: and -releaseEngine may
/// allocate or free.
@protocol NSPNoiseSuppressor <NSObject>

/// Engine name and version, for logs.
@property(nonatomic, readonly) NSString* engine;

/// Prepares for a stream of the given rate. Called again when the stream restarts or its rate
/// changes; the history of the previous stream is dropped. Returns NO when the engine cannot run
/// at this rate; frames are then left unchanged.
- (BOOL)initializeWithSampleRate:(NSInteger)sampleRateHz;

/// Denoises `count` float samples on the int16 scale, in place.
- (NSPNoiseSuppressorResult)processSamples:(float*)samples count:(NSInteger)count;

/// Frees the engine. The instance is not usable after this.
- (void)releaseEngine;

@end

NS_ASSUME_NONNULL_END
