//
//  MR0x202AudioQueueRenderer.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/9/26.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

//Audio Queue Support packet fmt only!

#import <Foundation/Foundation.h>
#import "MR0x202AudioRendererImpProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface MR0x202AudioQueueRenderer : NSObject <MR0x202AudioRendererImpProtocol>

- (void)onFetchPacketSample:(MRFetchPacketSample)block;
- (void)setup:(int)sampleRate isFloatFmt:(BOOL)isFloat;
- (void)play;

@end

NS_ASSUME_NONNULL_END
