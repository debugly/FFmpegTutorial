//
//  MR0x171VideoRenderer.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/11/22.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MR0x141VideoRendererProtocol.h"
#import <MetalKit/MetalKit.h>

NS_ASSUME_NONNULL_BEGIN

@interface MR0x171VideoRenderer : MTKView <MR0x141VideoRendererProtocol>

- (void)displayPixelBuffer:(CVPixelBufferRef)img;
- (void)displayNV21PixelBuffer:(CVPixelBufferRef)img;
- (NSImage *)snapshot;

@end

NS_ASSUME_NONNULL_END
