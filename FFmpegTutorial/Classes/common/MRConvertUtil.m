//
//  MRConvertUtil.m
//  FFmpegTutorial
//
//  Created by Matt Reach on 2020/6/3.
//

#import "MRConvertUtil.h"
#import <libavutil/frame.h>

#define BYTE_ALIGN_2(_s_) (( _s_ + 1)/2 * 2)

@implementation MRConvertUtil

+ (UIImage *)imageFromRGB24Frame:(AVFrame*)frame
{
    NSAssert(frame->format == AV_PIX_FMT_RGB24, @"not support [%d] Pixel format,use RGB24 please!",frame->format);
    
    const UInt8 *rgb = frame->data[0];
    const size_t bytesPerRow = frame->linesize[0];
    const int w = frame->width;
    const int h = frame->height;
    const CFIndex length = bytesPerRow * h;
    
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    ///需要copy！因为frame是重复利用的；里面的数据会变化！
    CFDataRef data = CFDataCreate(kCFAllocatorDefault, rgb, length);
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CFRelease(data);
    ///颜色空间与 AV_PIX_FMT_RGB24 对应
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGImageRef cgImage = CGImageCreate(w,
                                       h,
                                       8,
                                       24,
                                       bytesPerRow,
                                       colorSpace,
                                       bitmapInfo,
                                       provider,
                                       NULL,
                                       NO,
                                       kCGRenderingIntentDefault);
    CGColorSpaceRelease(colorSpace);
    CGDataProviderRelease(provider);
    
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    return image;
}

#pragma mark - YUV(NV12)-->CVPixelBufferRef Conversion

//https://stackoverflow.com/questions/25659671/how-to-convert-from-yuv-to-ciimage-for-ios
+ (CVPixelBufferRef)pixelBufferFromAVFrame:(AVFrame*)frame
{
    return [self pixelBufferFromAVFrame:frame opt:NULL];
}

+ (CVPixelBufferRef)pixelBufferFromAVFrame:(AVFrame*)frame opt:(CVPixelBufferPoolRef _Nullable)poolRef
{
    NSAssert(frame->format == AV_PIX_FMT_NV12, @"not support [%d] Pixel format,use NV12 please!",frame->format);
    
    CVPixelBufferRef pixelBuffer = NULL;
    CVReturn result = kCVReturnError;
    const int w = frame->width;
    const int h = frame->height;
    
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
        
        // Here y_ch0 is Y-Plane of YUV(NV12) data.
        
        unsigned char *y_ch0 = frame->data[0];
        unsigned char *y_ch1 = frame->data[1];
        // important !! 这里不能使用 w ，因为ffmpeg对数据做了字节对齐！！会导致绿屏！如果视频宽度刚好就是一个对齐的大小时，w就和linesize[0]相等，所以没问题；
        memcpy(yDestPlane, y_ch0, frame->linesize[0] * h);
        unsigned char *uvDestPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
        
        // Here y_ch1 is UV-Plane of YUV(NV12) data.
        memcpy(uvDestPlane, y_ch1, frame->linesize[1] * BYTE_ALIGN_2(h) / 2);
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    }
    
    return (CVPixelBufferRef)CFAutorelease(pixelBuffer);
}

@end
