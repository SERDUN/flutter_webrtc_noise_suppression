#import <Foundation/Foundation.h>

#import "NSPNoiseSuppressor.h"

NS_ASSUME_NONNULL_BEGIN

/// The RNNoise build and model a suppressor runs; the values are the C core's NsEngine.
typedef NS_ENUM(NSInteger, NSPRnnoiseModel) {
  /// RNNoise v0.1.1: the cheapest.
  NSPRnnoiseModelV01 = 0,
  /// RNNoise main (2025) with its little model: about 2.3x the CPU of v0.1.1, much stronger on
  /// other voices.
  NSPRnnoiseModelLittle = 1,
};

/// NSPNoiseSuppressor on RNNoise: 48 kHz mono, 480 samples per frame.
@interface NSPRnnoiseSuppressor : NSObject <NSPNoiseSuppressor>

/// RNNoise v0.1.1. Returns nil when the engine state cannot be allocated.
- (nullable instancetype)init;

/// Returns nil when the engine state cannot be allocated.
- (nullable instancetype)initWithModel:(NSPRnnoiseModel)model NS_DESIGNATED_INITIALIZER;

/// The model this suppressor runs.
@property(nonatomic, readonly) NSPRnnoiseModel model;

/// The only sample rate the engine accepts, Hz.
@property(class, nonatomic, readonly) NSInteger sampleRate;

/// Samples per frame the engine accepts.
@property(class, nonatomic, readonly) NSInteger frameSize;

@end

NS_ASSUME_NONNULL_END
