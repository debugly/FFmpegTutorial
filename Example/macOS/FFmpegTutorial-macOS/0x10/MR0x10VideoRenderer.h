//
//  MR0x10VideoRenderer.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/7/8.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CGImage.h>

NS_ASSUME_NONNULL_BEGIN

@interface MR0x10VideoRenderer : NSView

- (void)dispalyCGImage:(CGImageRef)img;

@end

NS_ASSUME_NONNULL_END
