//
//  MR0x22AudioQueueRenderer.h
//  FFmpegTutorial-iOS
//
//  Created by Matt Reach on 2020/7/16.
//  Copyright © 2020 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//
//Audio Queue Support packet fmt only!

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef UInt32(^MRFetchPacketSample)(uint8_t*buffer,UInt32 bufferSize);

@interface MR0x22AudioQueueRenderer : NSObject

- (void)setup:(int)sampleRate isFloatFmt:(BOOL)isFloat;
- (void)onFetchPacketSample:(MRFetchPacketSample)block;
- (void)play;

@end

NS_ASSUME_NONNULL_END
