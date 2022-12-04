//
//  MRMetalNV12Pipeline.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/11/23.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MRMetalNV12Pipeline.h"

@interface MRMetalNV12Pipeline ()

@property (nonatomic, strong) id<MTLBuffer> convertMatrix;

@end

@implementation MRMetalNV12Pipeline

+ (NSString *)fragmentFuctionName
{
    return @"nv12FragmentShader";
}

- (void)uploadTextureWithEncoder:(id<MTLRenderCommandEncoder>)encoder
                          buffer:(CVPixelBufferRef)pixelBuffer
                    textureCache:(CVMetalTextureCacheRef)textureCache
                          device:(id<MTLDevice>)device
                colorPixelFormat:(MTLPixelFormat)colorPixelFormat
{
    id<MTLTexture> textureY = nil;
    id<MTLTexture> textureUV = nil;
    
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    // textureY 设置
    {
        size_t width  = CVPixelBufferGetWidthOfPlane(pixelBuffer, 0);
        size_t height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 0);
        MTLPixelFormat pixelFormat = MTLPixelFormatR8Unorm; // 这里的颜色格式不是RGBA

        CVMetalTextureRef texture = NULL; // CoreVideo的Metal纹理
        CVReturn status = CVMetalTextureCacheCreateTextureFromImage(NULL, textureCache, pixelBuffer, NULL, pixelFormat, width, height, 0, &texture);
        if (status == kCVReturnSuccess) {
            textureY = CVMetalTextureGetTexture(texture); // 转成Metal用的纹理
            CFRelease(texture);
        }
    }
    
    // textureUV 设置
    {
        size_t width  = CVPixelBufferGetWidthOfPlane(pixelBuffer, 1);
        size_t height = CVPixelBufferGetHeightOfPlane(pixelBuffer, 1);
        MTLPixelFormat pixelFormat = MTLPixelFormatRG8Unorm; // 2-8bit的格式
        
        CVMetalTextureRef texture = NULL; // CoreVideo的Metal纹理
        CVReturn status = CVMetalTextureCacheCreateTextureFromImage(NULL, textureCache, pixelBuffer, NULL, pixelFormat, width, height, 1, &texture);
        if (status == kCVReturnSuccess) {
            textureUV = CVMetalTextureGetTexture(texture); // 转成Metal用的纹理
            CFRelease(texture);
        }
    }
    
    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    if (textureY != nil && textureUV != nil) {
        [encoder setFragmentTexture:textureY
                            atIndex:MRFragmentTextureIndexTextureY]; // 设置纹理
        [encoder setFragmentTexture:textureUV
                            atIndex:MRFragmentTextureIndexTextureU]; // 设置纹理
    }
    
    if (!self.convertMatrix) {
        OSType type = CVPixelBufferGetPixelFormatType(pixelBuffer);
        CFTypeRef color_attachments = CVBufferGetAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, NULL);
        if (color_attachments && CFStringCompare(color_attachments, kCVImageBufferYCbCrMatrix_ITU_R_601_4, 0) == kCFCompareEqualTo) {
            self.convertMatrix = [[self class] createMatrix:device matrixType:MRYUVToRGBBT601Matrix videoRange:type ==  kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange];
        } else {
            self.convertMatrix = [[self class] createMatrix:device matrixType:MRYUVToRGBBT709Matrix videoRange:type ==  kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange];
        }
    }
    
    [encoder setFragmentBuffer:self.convertMatrix
                        offset:0
                       atIndex:MRFragmentInputIndexMatrix];
    
    //必须最后调用 super，因为内部调用了 draw triangle
    [super uploadTextureWithEncoder:encoder buffer:pixelBuffer textureCache:textureCache device:device colorPixelFormat:colorPixelFormat];
}

@end
