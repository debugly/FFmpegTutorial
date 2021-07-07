//
//  MR0x10VideoRenderer.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/7/8.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x10VideoRenderer.h"

@implementation MR0x10VideoRenderer
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
    [self setNeedsDisplay:YES];
}

- (void)drawRect:(CGRect)rect
{
    if (_img) {
        CGContextRef currentContext = [[NSGraphicsContext currentContext] graphicsPort];
        [[NSColor blackColor] setFill];
        NSRectFill(rect);
        CGContextRef context = currentContext;
//        CGContextTranslateCTM(context, 0.0f, self.bounds.size.height);
//        CGContextScaleCTM(context, 1.0f, -1.0f);
        
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
    }
}

//- (BOOL)isFlipped
//{
//    return true;
//}

@end
