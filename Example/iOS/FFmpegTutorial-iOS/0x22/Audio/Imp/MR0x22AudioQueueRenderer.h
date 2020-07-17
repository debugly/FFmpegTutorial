//
//  MR0x22AudioQueueRenderer.h
//  FFmpegTutorial-iOS
//
//  Created by Matt Reach on 2020/7/16.
//  Copyright © 2020 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//
//Audio Queue Support packet fmt only!

#import <Foundation/Foundation.h>
#import "MR0x22AudioRendererImpProtocol.h"

NS_ASSUME_NONNULL_BEGIN



@interface MR0x22AudioQueueRenderer : NSObject <MR0x22AudioRendererImpProtocol>

- (void)onFetchPacketSample:(MRFetchPacketSample)block;
- (void)setup:(int)sampleRate isFloatFmt:(BOOL)isFloat;
- (void)play;

@end

NS_ASSUME_NONNULL_END
