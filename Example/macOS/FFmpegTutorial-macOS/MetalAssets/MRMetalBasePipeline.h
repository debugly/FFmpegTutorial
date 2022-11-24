//
//  MRMetalBasePipeline.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/11/23.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

// MRMetalBasePipeline is an abstract class, subclass must be override many methods.

@import MetalKit;
#import "MRMetalShaderTypes.h"

NS_ASSUME_NONNULL_BEGIN

@interface MRMetalBasePipeline : NSObject

+ (nullable id <MTLBuffer>)createMatrix:(id<MTLDevice>)device
                             matrixType:(MRYUVToRGBMatrixType)matrixType
                             videoRange:(BOOL)videoRange;

//subclass override!
+ (NSString *)fragmentFuctionName;

- (void)updateVertexRatio:(CGPoint)ratio
                   device:(id<MTLDevice>)device;

//subclass override!
- (void)uploadTextureWithEncoder:(id<MTLRenderCommandEncoder>)encoder
                          buffer:(CVPixelBufferRef)pixelBuffer
                    textureCache:(CVMetalTextureCacheRef)textureCache
                          device:(id<MTLDevice>)device
                colorPixelFormat:(MTLPixelFormat)colorPixelFormat;

@end

NS_ASSUME_NONNULL_END
