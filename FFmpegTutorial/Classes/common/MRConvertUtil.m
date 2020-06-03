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
    const UInt8 *rgb = frame->data[0];
    size_t bytesPerRow = frame->linesize[0];
    int w = frame->width;
    int h = frame->height;
    CFIndex length = bytesPerRow * h;
    
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    ///需要copy！因为frame是重复利用的；里面的数据会变化！
    CFDataRef data = CFDataCreate(kCFAllocatorDefault, rgb, length);
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CFRelease(data);
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
