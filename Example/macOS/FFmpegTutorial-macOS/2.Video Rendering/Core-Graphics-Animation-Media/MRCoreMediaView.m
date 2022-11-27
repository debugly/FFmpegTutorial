//
//  MRCoreMediaView.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/7/11.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MRCoreMediaView.h"
#import <FFmpegTutorial/FFTConvertUtil.h>
#import <FFmpegTutorial/FFTDispatch.h>
#import <MRFFmpegPod/libavutil/frame.h>
#import <AVFoundation/AVSampleBufferDisplayLayer.h>

@interface MRCoreMediaView ()
{
    CVPixelBufferPoolRef _pixelBufferPoolRef;
    MRGAMContentMode _contentMode;
}
@end

@implementation MRCoreMediaView

- (void)dealloc
{
    CVPixelBufferPoolRelease(_pixelBufferPoolRef);
    _pixelBufferPoolRef = NULL;
}

- (CALayer *)makeBackingLayer
{
    AVSampleBufferDisplayLayer *layer = [[AVSampleBufferDisplayLayer alloc] init];
    layer.backgroundColor = [[NSColor blackColor] CGColor];
    return layer;
}

- (void)setContentMode:(MRGAMContentMode)contentMode
{
    AVSampleBufferDisplayLayer *layer = (AVSampleBufferDisplayLayer *)[self layer];
    switch (contentMode) {
        case MRGAMContentModeScaleAspectFill:
        {
            layer.videoGravity = AVLayerVideoGravityResizeAspectFill;
        }
            break;
        case MRGAMContentModeScaleAspectFit:
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

- (MRGAMContentMode)contentMode
{
    AVSampleBufferDisplayLayer *layer = (AVSampleBufferDisplayLayer *)[self layer];
    
    if ([AVLayerVideoGravityResizeAspect isEqualToString:layer.videoGravity]) {
        return MRGAMContentModeScaleAspectFit;
    } else if ([AVLayerVideoGravityResizeAspectFill isEqualToString:layer.videoGravity]){
        return MRGAMContentModeScaleAspectFill;
    } else {
        return MRGAMContentModeScaleToFill;
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

- (CVPixelBufferRef)createCVPixelBufferFromAVFrame:(AVFrame *)frame
{
    if (_pixelBufferPoolRef) {
        NSDictionary *attributes = (__bridge NSDictionary *)CVPixelBufferPoolGetPixelBufferAttributes(_pixelBufferPoolRef);
        int _width = [[attributes objectForKey:(NSString*)kCVPixelBufferWidthKey] intValue];
        int _height = [[attributes objectForKey:(NSString*)kCVPixelBufferHeightKey] intValue];
        int _format = [[attributes objectForKey:(NSString*)kCVPixelBufferPixelFormatTypeKey] intValue];
        
        if (frame->width != _width || frame->height != _height || [FFTConvertUtil cvpixelFormatTypeWithAVFrame:frame] != _format) {
            CVPixelBufferPoolRelease(_pixelBufferPoolRef);
            _pixelBufferPoolRef = NULL;
        }
    }
    
    if (!_pixelBufferPoolRef) {
        _pixelBufferPoolRef = [FFTConvertUtil createPixelBufferPoolWithAVFrame:frame];
    }
    return [FFTConvertUtil pixelBufferFromAVFrame:frame opt:_pixelBufferPoolRef];
}

- (void)displayAVFrame:(AVFrame *)frame
{
    CVPixelBufferRef pixelBuff = [self createCVPixelBufferFromAVFrame:frame];
    CMSampleBufferRef sampleBuffer = [FFTConvertUtil createSampleBufferRefFromCVPixelBufferRef:pixelBuff];
    CVPixelBufferRelease(pixelBuff);
    
    mr_sync_main_queue(^{
        [self enqueueSampleBuffer:sampleBuffer];
        CFRelease(sampleBuffer);
    });
}

@end
