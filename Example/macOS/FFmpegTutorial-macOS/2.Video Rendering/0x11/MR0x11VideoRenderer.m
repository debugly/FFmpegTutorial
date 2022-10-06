//
//  MR0x11VideoRenderer.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/7/8.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x11VideoRenderer.h"

@implementation MR0x11VideoRenderer
{
    CGImageRef _img;
    MR0x141ContentMode _contentMode;
}

- (void)dealloc
{
    if (_img) {
        CGImageRelease(_img);
        _img = nil;
    }
}

- (void)dispalyCGImage:(CGImageRef)img
{
    if (img) {
        if (_img) {
            CGImageRelease(_img);
            _img = nil;
        }
        
        _img = CGImageRetain(img);
    }
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(CGRect)rect
{
    [[NSColor blackColor] setFill];
    NSRectFill(rect);
    if (_img) {
        CGContextRef currentContext = [[NSGraphicsContext currentContext] graphicsPort];
        CGContextRef context = currentContext;
//        CGContextTranslateCTM(context, 0.0f, self.bounds.size.height);
//        CGContextScaleCTM(context, 1.0f, -1.0f);
            
        CGFloat viewWidth  = CGRectGetWidth(self.bounds);
        CGFloat viewHeight = CGRectGetHeight(self.bounds);
        
        CGSize aspectRatio = CGSizeMake(CGImageGetWidth(_img), CGImageGetHeight(_img));
        CGFloat aspectWidth = viewHeight / aspectRatio.height * aspectRatio.width;
        CGFloat aspectHeight = viewWidth / aspectRatio.width * aspectRatio.height;
        
        CGFloat targetWidth = viewWidth;
        CGFloat targetHeight = viewHeight;
        
        if (_contentMode == MR0x141ContentModeScaleAspectFit) {
            //按高度最大等比缩放的宽度还没到边，说明视频的高度方向已经充满了屏幕，让高度使用最大值，宽度等比缩放，左右留黑边即可
            if (aspectWidth < viewWidth) {
                targetWidth = aspectWidth;
                targetHeight = viewHeight;
            } else {
                targetWidth = viewWidth;
                targetHeight = aspectHeight;
            }
        } else if (_contentMode == MR0x141ContentModeScaleAspectFill) {
            //按高度最大等比缩放的宽度超过屏幕了，说明视频已经完全充满了屏幕；就让高度使用最大值，宽度等比缩放
            if (aspectWidth > viewWidth) {
                targetWidth = aspectWidth;
                targetHeight = viewHeight;
            } else {
                targetWidth = viewWidth;
                targetHeight = aspectHeight;
            }
        }
        
        CGRect inRect = CGRectMake((viewWidth-targetWidth)/2.0, (viewHeight-targetHeight)/2.0,targetWidth, targetHeight);
        
        CGContextDrawImage(context, inRect, _img);
    }
}

- (void)setContentMode:(MR0x141ContentMode)contentMode
{
    _contentMode = contentMode;
}

- (MR0x141ContentMode)contentMode
{
    return _contentMode;
}

//- (BOOL)isFlipped
//{
//    return true;
//}

@end
