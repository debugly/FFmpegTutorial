//
//  MR0x33VideoRenderer.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/7/20.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//


#import <CoreMedia/CMSampleBuffer.h>
#import "MR0x33VideoRendererProtocol.h"
#import "MRPlatform.h"

NS_ASSUME_NONNULL_BEGIN

@interface MR0x33VideoRenderer : UIView<MR0x33VideoRendererProtocol>

- (void)displaySampleBuffer:(CMSampleBufferRef)buffer;
- (void)cleanScreen;

@end

NS_ASSUME_NONNULL_END
