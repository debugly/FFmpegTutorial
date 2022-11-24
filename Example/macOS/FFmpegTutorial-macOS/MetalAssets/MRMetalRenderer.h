//
//  MRMetalRenderer.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/11/23.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

@import MetalKit;
@import CoreVideo;

@interface MRMetalRenderer : NSObject<MTKViewDelegate>

- (nonnull instancetype)initWithMetalKitView:(nonnull MTKView *)mtkView;
- (void)updateVertexWithxRatio:(float)xRatio yRatio:(float)yRatio;
- (void)display:(CVPixelBufferRef _Nonnull)pixelBuffer;
- (void)displayNV21:(CVPixelBufferRef _Nonnull)pixelBuffer;

@end
