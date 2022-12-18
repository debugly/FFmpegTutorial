//
//  MRHaveFunVideoRenderer.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/1/10.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreMedia/CMSampleBuffer.h>

NS_ASSUME_NONNULL_BEGIN

@interface MRHaveFunVideoRenderer : NSView

- (void)enqueueSampleBuffer:(CMSampleBufferRef)buffer;
- (void)cleanScreen;

@end

NS_ASSUME_NONNULL_END
