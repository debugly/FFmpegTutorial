//
//  MR0x33VideoRenderer.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/7/20.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x33VideoRenderer.h"
#import <AVFoundation/AVSampleBufferDisplayLayer.h>

@implementation MR0x33VideoRenderer

- (CALayer *)makeBackingLayer
{
    AVSampleBufferDisplayLayer *layer = [[AVSampleBufferDisplayLayer alloc] init];
    layer.backgroundColor = [[NSColor blackColor] CGColor];
    return layer;
}

- (void)setContentMode:(MR0x33ContentMode)contentMode
{
    AVSampleBufferDisplayLayer *layer = (AVSampleBufferDisplayLayer *)[self layer];
    switch (contentMode) {
        case MR0x33ContentModeScaleAspectFill:
        {
            layer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        }
            break;
        case MR0x33ContentModeScaleAspectFit:
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

- (MR0x33ContentMode)contentMode
{
    AVSampleBufferDisplayLayer *layer = (AVSampleBufferDisplayLayer *)[self layer];
    
    if ([AVLayerVideoGravityResizeAspect isEqualToString:layer.videoGravity]) {
        return MR0x33ContentModeScaleAspectFit;
    } else if ([AVLayerVideoGravityResizeAspectFill isEqualToString:layer.videoGravity]){
        return MR0x33ContentModeScaleAspectFill;
    } else {
        return MR0x33ContentModeScaleToFill;
    }
}

- (void)displaySampleBuffer:(CMSampleBufferRef)buffer
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
