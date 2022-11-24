//
//  MRMetalYUV420PPipeline.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/11/24.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MRMetalYUV420PPipeline.h"

@interface MRMetalYUV420PPipeline ()

@property (nonatomic, strong) id<MTLBuffer> convertMatrix;

@end

@implementation MRMetalYUV420PPipeline

+ (NSString *)fragmentFuctionName
{
    return @"yuv420pFragmentShader";
}

- (void)uploadTextureWithEncoder:(id<MTLRenderCommandEncoder>)encoder
                          buffer:(CVPixelBufferRef)pixelBuffer
                    textureCache:(CVMetalTextureCacheRef)textureCache
                          device:(id<MTLDevice>)device
                colorPixelFormat:(MTLPixelFormat)colorPixelFormat
{
    OSType type = CVPixelBufferGetPixelFormatType(pixelBuffer);
    NSAssert((type == kCVPixelFormatType_420YpCbCr8PlanarFullRange || type ==  kCVPixelFormatType_420YpCbCr8Planar), @"wrong pixel format type, must be yuv420p.");
    
    CVPixelBufferLockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    for (int i = 0; i < CVPixelBufferGetPlaneCount(pixelBuffer); i++) {
        size_t width  = CVPixelBufferGetWidthOfPlane(pixelBuffer, i);
        size_t height = CVPixelBufferGetHeightOfPlane(pixelBuffer, i);
        
        CVMetalTextureRef textureRef = NULL; // CoreVideo的Metal纹理
        CVReturn status = CVMetalTextureCacheCreateTextureFromImage(NULL, textureCache, pixelBuffer, NULL, MTLPixelFormatR8Unorm, width, height, i, &textureRef);
        if (status == kCVReturnSuccess) {
            id<MTLTexture> texture = CVMetalTextureGetTexture(textureRef); // 转成Metal用的纹理
            CFRelease(textureRef);
            if (texture != nil) {
                [encoder setFragmentTexture:texture
                                    atIndex:MRFragmentTextureIndexTextureY + i]; // 设置纹理
            }
        }
    }

    CVPixelBufferUnlockBaseAddress(pixelBuffer, kCVPixelBufferLock_ReadOnly);
    
    if (!self.convertMatrix) {
        OSType type = CVPixelBufferGetPixelFormatType(pixelBuffer);
        CFTypeRef color_attachments = CVBufferGetAttachment(pixelBuffer, kCVImageBufferYCbCrMatrixKey, NULL);
        if (color_attachments && CFStringCompare(color_attachments, kCVImageBufferYCbCrMatrix_ITU_R_601_4, 0) == kCFCompareEqualTo) {
            self.convertMatrix = [[self class] createMatrix:device matrixType:MRYUVToRGBBT601Matrix videoRange:type ==  kCVPixelFormatType_420YpCbCr8Planar];
        } else {
            //type ==  kCVPixelFormatType_420YpCbCr8Planar
            self.convertMatrix = [[self class] createMatrix:device matrixType:MRYUVToRGBBT709Matrix videoRange:NO];
        }
    }
    
    [encoder setFragmentBuffer:self.convertMatrix
                        offset:0
                       atIndex:MRFragmentInputIndexMatrix];
    
    //必须最后调用 super，因为内部调用了 draw triangle
    [super uploadTextureWithEncoder:encoder buffer:pixelBuffer textureCache:textureCache device:device colorPixelFormat:colorPixelFormat];
}

@end
