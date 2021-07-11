//
//  MR0x13VideoRenderer.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/7/11.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x13VideoRenderer.h"
#import <AVFoundation/AVSampleBufferDisplayLayer.h>

@implementation MR0x13VideoRenderer

- (CALayer *)makeBackingLayer
{
    return [[AVSampleBufferDisplayLayer alloc] init];
}

- (void)setContentMode:(MRViewContentMode)contentMode
{
    switch (contentMode) {
        case MRViewContentModeScaleAspectFill:
        {
            AVSampleBufferDisplayLayer *layer = (AVSampleBufferDisplayLayer *)[self layer];
            layer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        }
            break;
        case MRViewContentModeScaleAspectFit:
        {
            AVSampleBufferDisplayLayer *layer = (AVSampleBufferDisplayLayer *)[self layer];
            layer.videoGravity = AVLayerVideoGravityResizeAspect;
        }
            break;
        default:
        {
            AVSampleBufferDisplayLayer *layer = (AVSampleBufferDisplayLayer *)[self layer];
            layer.videoGravity = AVLayerVideoGravityResize;
        }
            break;
    }
}

- (MRViewContentMode)contentMode
{
    AVSampleBufferDisplayLayer *layer = (AVSampleBufferDisplayLayer *)[self layer];
    
    if ([AVLayerVideoGravityResizeAspect isEqualToString:layer.videoGravity]) {
        return MRViewContentModeScaleAspectFit;
    } else if ([AVLayerVideoGravityResizeAspectFill isEqualToString:layer.videoGravity]){
        return MRViewContentModeScaleAspectFill;
    } else {
        return MRViewContentModeScaleToFill;
    }
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
