//
//  MR0x22VideoRenderer.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/7/10.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreVideo/CVPixelBuffer.h>
#import "MRVideoRendererProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface MR0x22VideoRenderer : NSOpenGLView<MRVideoRendererProtocol>
//画面原始尺寸；
@property (assign) CGSize videoSize;

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (BOOL)exchangeUploadTextureMethod;
- (NSImage *)snapshot;

@end

NS_ASSUME_NONNULL_END
