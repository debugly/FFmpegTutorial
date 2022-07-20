//
//  MR0x33VideoRenderer.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/7/20.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreMedia/CMSampleBuffer.h>
#import "MR0x33VideoRendererProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface MR0x33VideoRenderer : NSView
- (void)displaySampleBuffer:(CMSampleBufferRef)buffer;
- (void)cleanScreen;

@end

NS_ASSUME_NONNULL_END
