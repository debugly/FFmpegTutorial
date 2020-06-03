//
//  MRConvertUtil.m
//  FFmpegTutorial
//
//  Created by Matt Reach on 2020/6/3.
//

#import "MRConvertUtil.h"
#import <libavutil/frame.h>

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

@end
