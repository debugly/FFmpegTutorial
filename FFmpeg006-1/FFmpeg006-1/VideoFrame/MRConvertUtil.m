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
        
        //luma=[0,255] chroma=[1,255]
        
        for (int i = 0; i < y_bytesPerRow * h; i ++) {
            unsigned char *dest = yDestPlane + i;
            size_t luma = arc4random()%256;
            memset(dest, luma, 1);
        }
        
        unsigned char *uvDestPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
        
        size_t uv_bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
//        YUV420P -> RGB24
//        R = Y + ( 1.4075 * (V - 128) );
//        G = Y - ( 0.3455 * (U - 128) - 0.7169 * (V - 128) );
//        B = Y + ( 1.7790 * (U - 128) );
        
        static int chroma = 128;
//        测试UV使用其他值得效果
//        static int counter = 0;
//        counter++;
//        if (counter % 3 == 0) {
//            counter = 0;
//            chroma++;
//            printf("\t%d",chroma);
//        }
//
//        if (chroma > 255) {
//            chroma = 1;
//        }
        
        //奇数高度时(比如667)，那么UV应该是 334 行；如果按照 333.5计算会导致最后一行的右侧一半绿屏!
        memset(uvDestPlane, chroma, BYTE_ALIGN_2(h)/2 * uv_bytesPerRow);
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    }
    
    return (CVPixelBufferRef)CFAutorelease(pixelBuffer);
}


/// 填充灰色色阶
/// @param bytesPerRow 每行多少个字节/像素
/// @param y luma 分量内存指针
/// @param uv chroma 分量内存指针
/// @param w 渲染视图宽度
/// @param h 渲染视图高度
static void fillGrayBar(size_t bytesPerRow,unsigned char *y,unsigned char *uv,int w,int h)
{
    int barnum = 6;
    int color_b = 0;
    int color_w = 255;
    int deltaC = (color_w - color_b)/barnum;
    
    int bytePerBar = w/barnum;
    
    unsigned char *y_dest = y;
    //按行遍历
    for (int i = 0; i < h; i ++) {
        //每行分为barnum各块
        for (int j = 0; j < barnum; j++) {
            int luma = color_b + deltaC * j;
            size_t size = bytePerBar;
            if(j == barnum-1){
                size = bytesPerRow - (barnum-1)*bytePerBar;
            }
            memset(y_dest, luma, size);
            y_dest += size;
        }
    }
    
    memset(uv, 128, BYTE_ALIGN_2(h)/2 * bytesPerRow);
}

+ (CVPixelBufferRef)grayColorBarPixelBuffer:(int)w h:(int)h opt:(CVPixelBufferPoolRef)poolRef
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
        unsigned char *uvDestPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
        size_t y_bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
        
        fillGrayBar(y_bytesPerRow,yDestPlane,uvDestPlane,w,h);
        
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
