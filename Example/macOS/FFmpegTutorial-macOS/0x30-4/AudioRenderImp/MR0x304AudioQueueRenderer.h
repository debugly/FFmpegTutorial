//
//  MR0x304AudioQueueRenderer.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/2/17.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

//Audio Queue Support packet fmt only!

#import <Foundation/Foundation.h>
#import "MR0x304AudioRendererImpProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface MR0x304AudioQueueRenderer : NSObject <MR0x304AudioRendererImpProtocol>

- (void)onFetchPacketSample:(MRFetchPacketSample)block;
- (void)setup:(int)sampleRate isFloatFmt:(BOOL)isFloat;
- (void)play;

@end

NS_ASSUME_NONNULL_END
