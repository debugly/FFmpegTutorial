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
    AVSampleBufferDisplayLayer *layer = (AVSampleBufferDisplayLayer *)[self layer];
    switch (contentMode) {
        case MRViewContentModeScaleAspectFill:
        {
            layer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        }
            break;
        case MRViewContentModeScaleAspectFit:
        {
            layer.videoGravity = AVLayerVideoGravityResizeAspect;
        }
            break;
        default:
        {
            layer.videoGravity = AVLayerVideoGravityResize;
            
        }
            break;
    }
    
    //上面的修改在frame发生变化时生效
    CGRect oldFrame = layer.frame;
    oldFrame.size.height += 0.01;
    [layer setFrame:oldFrame];
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
