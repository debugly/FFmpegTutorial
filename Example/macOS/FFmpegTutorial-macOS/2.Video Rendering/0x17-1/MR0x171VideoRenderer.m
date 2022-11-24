//
//  MR0x171VideoRenderer.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/11/22.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x171VideoRenderer.h"
#import <QuartzCore/QuartzCore.h>
#import <AVFoundation/AVUtilities.h>
#import <mach/mach_time.h>
#import <MRFFmpegPod/libavutil/frame.h>
#import <FFmpegTutorial/FFTConvertUtil.h>
#import "MRMetalShaderTypes.h"
#import "MRMetalRenderer.h"

@interface MR0x171VideoRenderer ()
{
    CGRect _layerBounds;
    MR0x141ContentMode _contentMode;
    CVPixelBufferPoolRef _pixelBufferPoolRef;
    MRMetalRenderer * _renderer;
    CGSize _normalizedSize;
}

@end

@implementation MR0x171VideoRenderer

- (void)dealloc
{
    CVPixelBufferPoolRelease(_pixelBufferPoolRef);
}

- (void)_setup
{
    self.device = MTLCreateSystemDefaultDevice();
    _renderer = [[MRMetalRenderer alloc] initWithMetalKitView:self];
    // Initialize our renderer with the view size
    [_renderer mtkView:self drawableSizeWillChange:self.drawableSize];
    self.delegate = _renderer;
    self.autoResizeDrawable = NO;
}

- (instancetype)initWithCoder:(NSCoder *)coder
{
    self = [super initWithCoder:coder];
    if (self) {
        [self _setup];
    }
    return self;
}

- (instancetype)initWithFrame:(NSRect)frameRect
{
    self = [super initWithFrame:frameRect];
    if (self) {
        [self _setup];
    }
    return self;
}

- (void)layout
{
    [super layout];
    _layerBounds = [self bounds];
}

- (void)setContentMode:(MR0x141ContentMode)contentMode
{
    _contentMode = contentMode;
}

- (MR0x141ContentMode)contentMode
{
    return _contentMode;
}

- (CGSize)computeNormalizedSize:(AVFrame * _Nonnull)frame
{
    int frameWidth = frame->width;
    int frameHeight = frame->height;
    // Compute normalized quad coordinates to draw the frame into.
    CGSize normalizedSamplingSize = CGSizeMake(1.0, 1.0);
    
    if (_contentMode == MR0x141ContentModeScaleAspectFit || _contentMode == MR0x141ContentModeScaleAspectFill) {
        // Set up the quad vertices with respect to the orientation and aspect ratio of the video.
        CGRect vertexSamplingRect = AVMakeRectWithAspectRatioInsideRect(CGSizeMake(frameWidth, frameHeight), _layerBounds);
        
        CGSize cropScaleAmount = CGSizeMake(vertexSamplingRect.size.width/_layerBounds.size.width, vertexSamplingRect.size.height/_layerBounds.size.height);
        
        // hold max
        if (_contentMode == MR0x141ContentModeScaleAspectFit) {
            if (cropScaleAmount.width > cropScaleAmount.height) {
                normalizedSamplingSize.width = 1.0;
                normalizedSamplingSize.height = cropScaleAmount.height/cropScaleAmount.width;
            }
            else {
                normalizedSamplingSize.height = 1.0;
                normalizedSamplingSize.width = cropScaleAmount.width/cropScaleAmount.height;
            }
        } else if (_contentMode == MR0x141ContentModeScaleAspectFill) {
            // hold min
            if (cropScaleAmount.width > cropScaleAmount.height) {
                normalizedSamplingSize.height = 1.0;
                normalizedSamplingSize.width = cropScaleAmount.width/cropScaleAmount.height;
            }
            else {
                normalizedSamplingSize.width = 1.0;
                normalizedSamplingSize.height = cropScaleAmount.height/cropScaleAmount.width;
            }
        }
    }
    return normalizedSamplingSize;
}

- (CVPixelBufferRef)createCVPixelBufferFromAVFrame:(AVFrame *)frame
{
    if(!_pixelBufferPoolRef) {
        _pixelBufferPoolRef = [FFTConvertUtil createPixelBufferPoolWithAVFrame:frame];
    }
    return [FFTConvertUtil pixelBufferFromAVFrame:frame opt:_pixelBufferPoolRef];
}

- (void)displayAVFrame:(AVFrame *)frame
{
    CGSize normalizedSize = [self computeNormalizedSize:frame];
    if ((int)(_normalizedSize.width * 1000) != (int)(normalizedSize.width * 1000) || (int)(_normalizedSize.height * 1000) != (int)(normalizedSize.height * 1000)) {
        _normalizedSize = normalizedSize;
        [_renderer updateVertexWithxRatio:_normalizedSize.width yRatio:_normalizedSize.height];
    }

    CVPixelBufferRef img = [self createCVPixelBufferFromAVFrame:frame];
    if (img) {
        if (frame->format == AV_PIX_FMT_NV21) {
            [_renderer displayNV21:img];
        } else {
            [_renderer display:img];
        }
        
        CVPixelBufferRelease(img);
    }
}

- (NSImage *)snapshot
{
    //todo
    return nil;
}

@end
