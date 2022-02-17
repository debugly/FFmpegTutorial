//
//  MR0x30VideoRenderer.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/9/21.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreVideo/CVPixelBuffer.h>
#import "MRVideoRendererProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface MR0x30VideoRenderer : NSOpenGLView<MRVideoRendererProtocol>
//画面原始尺寸；
@property (assign) CGSize videoSize;

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (void)exchangeUploadTextureMethod;
- (NSImage *)snapshot;

@end

NS_ASSUME_NONNULL_END
