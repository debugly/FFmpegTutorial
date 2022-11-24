//
//  MR0x174VideoRenderer.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/11/24.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreVideo/CVPixelBuffer.h>
#import "MR0x141VideoRendererProtocol.h"

NS_ASSUME_NONNULL_BEGIN
typedef struct AVFrame AVFrame;
@interface MR0x174VideoRenderer : NSOpenGLView<MR0x141VideoRendererProtocol>

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (void)displayAVFrame:(AVFrame *)frame;
- (NSImage *)snapshot;

@end

NS_ASSUME_NONNULL_END
