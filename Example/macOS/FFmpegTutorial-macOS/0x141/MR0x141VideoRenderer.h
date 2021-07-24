//
//  MR0x141VideoRenderer.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/7/11.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreVideo/CVPixelBuffer.h>

NS_ASSUME_NONNULL_BEGIN

@interface MR0x141VideoRenderer : NSOpenGLView

@property (nonatomic, assign) BOOL isFullYUVRange;

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;

@end

NS_ASSUME_NONNULL_END
