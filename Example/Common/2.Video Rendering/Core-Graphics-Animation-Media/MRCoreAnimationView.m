//
//  MRCoreAnimationView.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/7/9.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MRCoreAnimationView.h"
#import <FFmpegTutorial/FFTConvertUtil.h>
#import <FFmpegTutorial/FFTDispatch.h>
#import <MRFFmpegPod/libavutil/frame.h>

@interface MRCoreAnimationView ()
{
    MRRenderingMode _renderingMode;
}
@end

@implementation MRCoreAnimationView

- (void)awakeFromNib
{
    [super awakeFromNib];
    [self setWantsLayer:YES];
    self.layer.backgroundColor = [[NSColor blackColor] CGColor];
}

- (void)displayAVFrame:(AVFrame *)frame
{
    CGImageRef cgImage = [FFTConvertUtil createImageFromRGBFrame:frame];
    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    NSImage *img = [[NSImage alloc] initWithCGImage:cgImage size:CGSizeMake(width, height)];
    CGImageRelease(cgImage);
    mr_sync_main_queue(^{
        self.image = img;
    });
}

- (MRRenderingMode)renderingMode
{
    return _renderingMode;
}


- (void)setRenderingMode:(MRRenderingMode)renderingMode
{
    _renderingMode = renderingMode;
}

@end
