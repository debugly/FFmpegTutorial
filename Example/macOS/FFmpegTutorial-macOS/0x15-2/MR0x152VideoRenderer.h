//
//  MR0x152VideoRenderer.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/1/18.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreVideo/CVPixelBuffer.h>
#import "MRVideoRendererProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface MR0x152VideoRenderer : NSOpenGLView<MRVideoRendererProtocol>

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;

@end

NS_ASSUME_NONNULL_END
