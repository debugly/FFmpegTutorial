//
//  MRHaveFunVideoRenderer.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/1/10.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MRHaveFunVideoRenderer.h"
#import <AVFoundation/AVSampleBufferDisplayLayer.h>

@implementation MRHaveFunVideoRenderer

- (CALayer *)makeBackingLayer
{
    return [[AVSampleBufferDisplayLayer alloc] init];
}

- (void)enqueueSampleBuffer:(CMSampleBufferRef)buffer
{
    AVSampleBufferDisplayLayer *layer = (AVSampleBufferDisplayLayer *)[self layer];
    [layer enqueueSampleBuffer:buffer];
}

- (void)cleanScreen
{
    AVSampleBufferDisplayLayer *layer = (AVSampleBufferDisplayLayer *)[self layer];
    [layer flushAndRemoveImage];
}

@end
