//
//  MR0x151VideoRenderer.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/1/19.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreVideo/CVPixelBuffer.h>
#import "MRVideoRendererProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface MR0x151VideoRenderer : NSOpenGLView<MRVideoRendererProtocol>

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (void)exchangeUploadTextureMethod;

@end

NS_ASSUME_NONNULL_END