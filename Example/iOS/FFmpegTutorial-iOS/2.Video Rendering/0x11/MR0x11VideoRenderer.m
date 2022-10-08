//
//  MR0x11VideoRenderer.m
//  FFmpegTutorial-iOS
//
//  Created by Matt Reach on 2020/6/5.
//  Copyright © 2020 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//
// Core Graphics 的绘制过程是完全由CPU完成的，因此会更加消耗 CPU
// Color Misaligned images : 黄色的
// Color Copied Images : 

#import "MR0x11VideoRenderer.h"

@implementation MR0x11VideoRenderer
{
    CGImageRef _img;
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
    [self setNeedsDisplay];
}

- (void)drawRect:(CGRect)rect
{
    if (_img) {
        CGContextRef currentContext = UIGraphicsGetCurrentContext();
//        CGLayerRef   cgLayer = CGLayerCreateWithContext(currentContext, self.bounds.size, NULL);
//        CGContextRef context =  CGLayerGetContext(cgLayer);
        CGContextRef context = currentContext;
        CGContextTranslateCTM(context, 0.0f, self.bounds.size.height);
        CGContextScaleCTM(context, 1.0f, -1.0f);
        
        CGSize aspectRatio = CGSizeMake(CGImageGetWidth(_img), CGImageGetHeight(_img));;
            
        CGFloat maxWidth  = CGRectGetWidth(self.bounds);
        CGFloat maxHeight = CGRectGetHeight(self.bounds);
            
        CGFloat aspectWidth = maxHeight / aspectRatio.height * aspectRatio.width;
        CGFloat aspectHeight = maxWidth / aspectRatio.width * aspectRatio.height;
        
        CGFloat width,height = 0;
        
        if (aspectWidth < maxWidth) {
            width = aspectWidth;
            height = maxHeight;
        } else {
            width = maxWidth;
            height = aspectHeight;
        }
        
        CGRect inRect = CGRectMake((maxWidth-width)/2.0, (maxHeight-height)/2.0,width, height);
        
        CGContextDrawImage(context, inRect, _img);
        
//        CGContextDrawLayerInRect(currentContext, rect, cgLayer);
//        CGLayerRelease(cgLayer);
    }
}

@end
