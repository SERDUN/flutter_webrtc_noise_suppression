#import <Foundation/Foundation.h>

#import "NSPNoiseSuppressor.h"

NS_ASSUME_NONNULL_BEGIN

/// NSPNoiseSuppressor on RNNoise v0.1.1: 48 kHz mono, 480 samples per frame.
@interface NSPRnnoiseSuppressor : NSObject <NSPNoiseSuppressor>

/// Returns nil when the engine state cannot be allocated.
- (nullable instancetype)init NS_DESIGNATED_INITIALIZER;

/// The only sample rate the engine accepts, Hz.
@property(class, nonatomic, readonly) NSInteger sampleRate;

/// Samples per frame the engine accepts.
@property(class, nonatomic, readonly) NSInteger frameSize;

@end

NS_ASSUME_NONNULL_END
