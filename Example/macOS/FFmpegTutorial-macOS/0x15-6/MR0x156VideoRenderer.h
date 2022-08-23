//
//  MR0x156VideoRenderer.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/8/23.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreVideo/CVPixelBuffer.h>
#import "MRVideoRendererProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface MR0x156VideoRenderer : NSOpenGLView<MRVideoRendererProtocol>

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;
- (BOOL)exchangeUploadTextureMethod;

@end

NS_ASSUME_NONNULL_END
