//
//  MRConvertUtil.m
//  FFmpeg006-1
//
//  Created by Matt Reach on 2019/1/25.
//  Copyright © 2019 Awesome FFmpeg Study Demo. All rights reserved.
//

#import "MRConvertUtil.h"
#import <CoreGraphics/CoreGraphics.h>

#define BYTE_ALIGN_2(_s_) (( _s_ + 1)/2 * 2)

@implementation MRConvertUtil

+ (CVPixelBufferRef)snowPixelBuffer:(int)w h:(int)h opt:(CVPixelBufferPoolRef)poolRef
{
    CVPixelBufferRef pixelBuffer = NULL;
    CVReturn result = kCVReturnError;
    
    if (poolRef) {
        result = CVPixelBufferPoolCreatePixelBuffer(NULL, poolRef, &pixelBuffer);
    } else {
        NSDictionary *pixelAttributes = @{(NSString*)kCVPixelBufferIOSurfacePropertiesKey:@{}};
        
        result = CVPixelBufferCreate(kCFAllocatorDefault,
                                     w,
                                     h,
                                     kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                                     (__bridge CFDictionaryRef)(pixelAttributes),
                                     &pixelBuffer);
    }
    
    if (kCVReturnSuccess == result) {
        CVPixelBufferLockBaseAddress(pixelBuffer,0);
        unsigned char *yDestPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
        size_t y_bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
        
        for (int i = 0; i < y_bytesPerRow * h; i ++) {
            unsigned char *dest = yDestPlane + i;
            memset(dest, random()%256, 1);
        }
        
        unsigned char *uvDestPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
        
        size_t uv_bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
        //奇数高度时(比如667)，那么UV应该是 334 行；如果按照 333.5计算会导致最后一行的右侧一半绿屏!
        memset(uvDestPlane, 128, BYTE_ALIGN_2(h)/2 * uv_bytesPerRow);
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    }
    
    return (CVPixelBufferRef)CFAutorelease(pixelBuffer);
}

+ (UIImage *)imageFromCVPixelBuffer:(CVPixelBufferRef)pixelBuffer w:(int)w h:(int)h
{
    // CIImage Conversion
    CIImage *coreImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    CIContext *context = [CIContext contextWithOptions:nil];
    ///引发内存泄露? https://stackoverflow.com/questions/32520082/why-is-cicontext-createcgimage-causing-a-memory-leak
    NSTimeInterval begin = CFAbsoluteTimeGetCurrent();
    CGImageRef cgImage = [context createCGImage:coreImage
                                       fromRect:CGRectMake(0, 0, w, h)];
    NSTimeInterval end = CFAbsoluteTimeGetCurrent();
    // UIImage Conversion
    UIImage *uiImage = [[UIImage alloc] initWithCGImage:cgImage
                                                  scale:1.0
                                            orientation:UIImageOrientationUp];
    
    NSLog(@"decode an image cost :%g",end-begin);
    CGImageRelease(cgImage);
    return uiImage;
}

#pragma mark - CVPixelBufferRef-->CMSampleBufferRef

+ (CMSampleBufferRef)cmSampleBufferRefFromCVPixelBufferRef:(CVPixelBufferRef)pixelBuffer
{
    if (pixelBuffer) {
        //不设置具体时间信息
        CMSampleTimingInfo timing = {kCMTimeInvalid, kCMTimeInvalid, kCMTimeInvalid};
        //获取视频信息
        CMVideoFormatDescriptionRef videoInfo = NULL;
        OSStatus result = CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBuffer, &videoInfo);
        NSParameterAssert(result == 0 && videoInfo != NULL);
        
        CMSampleBufferRef sampleBuffer = NULL;
        result = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault,pixelBuffer, true, NULL, NULL, videoInfo, &timing, &sampleBuffer);
        NSParameterAssert(result == 0 && sampleBuffer != NULL);
        CFRelease(videoInfo);
        
        CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, YES);
        CFMutableDictionaryRef dict = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
        CFDictionarySetValue(dict, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);
        return (CMSampleBufferRef)CFAutorelease(sampleBuffer);
    }
    return NULL;
}

@end
