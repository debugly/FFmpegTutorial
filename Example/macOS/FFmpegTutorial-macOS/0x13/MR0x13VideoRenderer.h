//
//  MR0x13VideoRenderer.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/7/11.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreMedia/CMSampleBuffer.h>
#import "MRVideoRendererProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface MR0x13VideoRenderer : NSView<MRVideoRendererProtocol>

- (void)enqueueSampleBuffer:(CMSampleBufferRef)buffer;
- (void)cleanScreen;

@end

NS_ASSUME_NONNULL_END
