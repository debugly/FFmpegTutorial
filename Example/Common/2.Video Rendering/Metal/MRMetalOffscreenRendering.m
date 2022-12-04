//
//  MRMetalOffscreenRendering.m
//  FFmpegTutorial-macOS
//
//  Created by Reach Matt on 2022/12/2.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MRMetalOffscreenRendering.h"
@import Metal;
@import CoreVideo;
@import CoreImage;

@interface MRMetalOffscreenRendering ()
{
    CVPixelBufferRef _pixelBuffer;
    MTLRenderPassDescriptor* _passDescriptor;
}
@end

@implementation MRMetalOffscreenRendering

- (void)dealloc
{
    CVPixelBufferRelease(_pixelBuffer);
}

- (CVPixelBufferRef)createCVPixelBufferWithSize:(CGSize)size
{
    CVPixelBufferRef pixelBuffer;
    NSDictionary* cvBufferProperties = @{
//        (__bridge NSString*)kCVPixelBufferOpenGLCompatibilityKey : @YES,
        (__bridge NSString*)kCVPixelBufferMetalCompatibilityKey : @YES,
    };
    CVReturn cvret = CVPixelBufferCreate(kCFAllocatorDefault,
                                         size.width, size.height,
                                         kCVPixelFormatType_32BGRA,
                                         (__bridge CFDictionaryRef)cvBufferProperties,
                                         &pixelBuffer);
    
    
    if (cvret == kCVReturnSuccess) {
        return pixelBuffer;
    } else {
        NSAssert(NO, @"Failed to create CVPixelBuffer:%d",cvret);
    }
    return NULL;
}

/**
 Create a Metal texture from the CoreVideo pixel buffer using the following steps, and as annotated in the code listings below:
 */
- (id <MTLTexture>)createMetalTextureFromCVPixelBuffer:(CVPixelBufferRef)pixelBuffer
                                                device:(id<MTLDevice>)device
{
    CVMetalTextureCacheRef textureCache;
    // 1. Create a Metal Core Video texture cache from the pixel buffer.
    CVReturn cvret = CVMetalTextureCacheCreate(
                    kCFAllocatorDefault,
                    nil,
                    device,
                    nil,
                    &textureCache);
    
    if (cvret != kCVReturnSuccess) {
        NSLog(@"Failed to create Metal texture cache");
        return nil;
    }
    
    // 2. Create a CoreVideo pixel buffer backed Metal texture image from the texture cache.
    CVMetalTextureRef texture;
    size_t width  = (size_t)CVPixelBufferGetWidth(pixelBuffer);
    size_t height = (size_t)CVPixelBufferGetHeight(pixelBuffer);
    cvret = CVMetalTextureCacheCreateTextureFromImage(
                    kCFAllocatorDefault,
                    textureCache,
                    pixelBuffer, nil,
                    MTLPixelFormatBGRA8Unorm,
                    width, height,
                    0,
                    &texture);
    
    CFRelease(textureCache);
    
    if (cvret != kCVReturnSuccess) {
        NSLog(@"Failed to create CoreVideo Metal texture from image");
        return nil;
    }
    
    // 3. Get a Metal texture using the CoreVideo Metal texture reference.
    id <MTLTexture> metalTexture = CVMetalTextureGetTexture(texture);
    
    CFRelease(texture);
    
    if (!metalTexture) {
        NSLog(@"Failed to create Metal texture CoreVideo Metal Texture");
    }
    
    return metalTexture;
}

- (BOOL)canReuse:(CGSize)size
{
    if (_pixelBuffer) {
        int width  = (int)CVPixelBufferGetWidth(_pixelBuffer);
        int height = (int)CVPixelBufferGetHeight(_pixelBuffer);
        if (width == (int)size.width && height == (int)size.height) {
            return YES;
        }
    }
    return NO;
}

- (MTLRenderPassDescriptor *)offscreenRender:(CGSize)size
                                      device:(id<MTLDevice>)device
{
    if (!_passDescriptor) {
        
        // Texture to render to and then sample from.
        
        if (!_pixelBuffer) {
            _pixelBuffer = [self createCVPixelBufferWithSize:size];
        }
        
        id<MTLTexture> renderTargetTexture = [self createMetalTextureFromCVPixelBuffer:_pixelBuffer device:device];
        
        MTLRenderPassDescriptor *passDescriptor = [MTLRenderPassDescriptor new];
        passDescriptor.colorAttachments[0].texture = renderTargetTexture;
        passDescriptor.colorAttachments[0].loadAction = MTLLoadActionClear;
        passDescriptor.colorAttachments[0].clearColor = MTLClearColorMake(1, 1, 1, 1);
        passDescriptor.colorAttachments[0].storeAction = MTLStoreActionStore;
        
        _passDescriptor = passDescriptor;
    }
    return _passDescriptor;
}

- (CGImageRef)snapshot
{
    CVPixelBufferRef pixelBuffer = CVPixelBufferRetain(_pixelBuffer);
    CIImage *ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    
    static CIContext *context = nil;
    if (!context) {
        context = [CIContext contextWithOptions:NULL];
    }
    CGRect rect = CGRectMake(0,0,
                             CVPixelBufferGetWidth(pixelBuffer),
                             CVPixelBufferGetHeight(pixelBuffer));
    CGImageRef imageRef = [context createCGImage:ciImage fromRect:rect];
    CVPixelBufferRelease(pixelBuffer);
    return imageRef ? (CGImageRef)CFAutorelease(imageRef) : NULL;
}

@end
