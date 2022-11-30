//
//  MRMetalBGRAPipeline.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/11/23.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MRMetalBGRAPipeline.h"

@implementation MRMetalBGRAPipeline

+ (NSString *)fragmentFuctionName
{
    return @"bgraFragmentShader";
}

- (void)uploadTextureWithEncoder:(id<MTLRenderCommandEncoder>)encoder
                          buffer:(CVPixelBufferRef)pixelBuffer
                    textureCache:(CVMetalTextureCacheRef)textureCache
                          device:(id<MTLDevice>)device
                colorPixelFormat:(MTLPixelFormat)colorPixelFormat
{
    id<MTLTexture> textureY = nil;
    
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    // textureY 设置
    {
        size_t width  = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
        size_t height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
        MTLPixelFormat pixelFormat = MTLPixelFormatBGRA8Unorm;

        CVMetalTextureRef texture = NULL; // CoreVideo的Metal纹理
        CVReturn status = CVMetalTextureCacheCreateTextureFromImage(NULL, textureCache, pixelBuffer, NULL, pixelFormat, width, height, 0, &texture);
        if (status == kCVReturnSuccess) {
            textureY = CVMetalTextureGetTexture(texture); // 转成Metal用的纹理
            CFRelease(texture);
        }
    }
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    if (textureY != nil) {
        [encoder setFragmentTexture:textureY
                            atIndex:MRFragmentTextureIndexTextureY]; // 设置纹理
    }
    
    //必须最后调用 super，因为内部调用了 draw triangle
    [super uploadTextureWithEncoder:encoder buffer:pixelBuffer textureCache:textureCache device:device colorPixelFormat:colorPixelFormat];
}

@end
