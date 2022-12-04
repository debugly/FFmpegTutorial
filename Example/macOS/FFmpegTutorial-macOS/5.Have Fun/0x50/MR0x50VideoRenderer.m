//
//  MR0x50VideoRenderer.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/1/10.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x50VideoRenderer.h"
#import <AVFoundation/AVSampleBufferDisplayLayer.h>

@implementation MR0x50VideoRenderer

- (CALayer *)makeBackingLayer
{
    return [[AVSampleBufferDisplayLayer alloc] init];
}

- (void)setRenderingMode:(MRRenderingMode)renderingMode
{
    AVSampleBufferDisplayLayer *layer = (AVSampleBufferDisplayLayer *)[self layer];
    switch (renderingMode) {
        case MRRenderingModeScaleAspectFill:
        {
            layer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        }
            break;
        case MRRenderingModeScaleAspectFit:
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

- (MRRenderingMode)renderingMode
{
    AVSampleBufferDisplayLayer *layer = (AVSampleBufferDisplayLayer *)[self layer];
    
    if ([AVLayerVideoGravityResizeAspect isEqualToString:layer.videoGravity]) {
        return MRRenderingModeScaleAspectFit;
    } else if ([AVLayerVideoGravityResizeAspectFill isEqualToString:layer.videoGravity]){
        return MRRenderingModeScaleAspectFill;
    } else {
        return MRRenderingModeScaleToFill;
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
