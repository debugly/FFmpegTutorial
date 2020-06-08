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

CGImageRef _CreateCGImageFromBitMap(void *pixels,size_t w, size_t h,
size_t bpc, size_t bpp, size_t bpr, int bmi)
{
    assert(bpp != 24);
    /*
     AV_PIX_FMT_RGB24 bpp is 24! not supported!
     Crash:
     2020-06-06 00:08:20.245208+0800 FFmpegTutorial[23649:2335631] [Unknown process name] CGBitmapContextCreate: unsupported parameter combination: set CGBITMAP_CONTEXT_LOG_ERRORS environmental variable to see the details
     2020-06-06 00:08:20.245417+0800 FFmpegTutorial[23649:2335631] [Unknown process name] CGBitmapContextCreateImage: invalid context 0x0. If you want to see the backtrace, please set CG_CONTEXT_SHOW_BACKTRACE environmental variable.
     */
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGContextRef bitmapContext = CGBitmapContextCreate(
        pixels,
        w,
        h,
        bpc,
        bpr,
        colorSpace,
        bmi
    );
    
    CGImageRef cgImage = CGBitmapContextCreateImage(bitmapContext);
    CGColorSpaceRelease(colorSpace);
    return (CGImageRef)CFAutorelease(cgImage);
}

CGImageRef _CreateCGImage(void *pixels,size_t w, size_t h,
size_t bpc, size_t bpp, size_t bpr, int bmi)
{
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    const UInt8 *rgb = pixels;
    const CFIndex length = bpr * h;
    ///需要copy！因为frame是重复利用的；里面的数据会变化！
    CFDataRef data = CFDataCreate(kCFAllocatorDefault, rgb, length);
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CFRelease(data);
    
    CGImageRef cgImage = CGImageCreate(w,
                                       h,
                                       bpc,
                                       bpp,
                                       bpr,
                                       colorSpace,
                                       bmi,
                                       provider,
                                       NULL,
                                       NO,
                                       kCGRenderingIntentDefault);
    CGDataProviderRelease(provider);
    CGColorSpaceRelease(colorSpace);
    
    return (CGImageRef)CFAutorelease(cgImage);
}

+ (CGImageRef)cgImageFromRGBFrame:(AVFrame*)frame
{
    if (frame->format == AV_PIX_FMT_RGB555BE || frame->format == AV_PIX_FMT_RGB555LE || frame->format == AV_PIX_FMT_RGB24 || frame->format == AV_PIX_FMT_RGBA || frame->format == AV_PIX_FMT_0RGB || frame->format == AV_PIX_FMT_RGB0 || frame->format == AV_PIX_FMT_ARGB || frame->format == AV_PIX_FMT_RGBA) {
        //these are supported!
    } else {
        NSAssert(NO, @"not support [%d] Pixel format,use RGB555BE/RGB555LE/RGBA/ARGB/0RGB/RGB24 please!",frame->format);
    }
//    https://stackoverflow.com/questions/1579631/converting-rgb-data-into-a-bitmap-in-objective-c-cocoa
    //https://developer.apple.com/library/archive/documentation/GraphicsImaging/Conceptual/drawingwithquartz2d/dq_context/dq_context.html#//apple_ref/doc/uid/TP30001066-CH203-BCIBHHBB
    
    int bpc = 0;
    int bpp = 0;
    CGBitmapInfo bitMapInfo = 0;
    if (frame->format == AV_PIX_FMT_RGB555BE) {
        bpc = 5;
        bpp = 16;
        bitMapInfo = kCGBitmapByteOrder16Big | kCGImageAlphaNoneSkipFirst;
    } else if (frame->format == AV_PIX_FMT_RGB555LE) {
        bpc = 5;
        bpp = 16;
        bitMapInfo = kCGBitmapByteOrder16Little | kCGImageAlphaNoneSkipFirst;
    } else if (frame->format == AV_PIX_FMT_RGB24) {
        bpc = 8;
        bpp = 24;
        bitMapInfo = kCGImageAlphaNone | kCGBitmapByteOrderDefault;
    } else if (frame->format == AV_PIX_FMT_0RGB) {
        //AV_PIX_FMT_0RGB 当做已经预乘好的 AV_PIX_FMT_ARGB 也可以渲染出来，总之不让 GPU 再次计算就行了
        bpc = 8;
        bpp = 32;
        bitMapInfo = kCGBitmapByteOrderDefault |kCGImageAlphaNoneSkipFirst;
    } else if (frame->format == AV_PIX_FMT_RGB0) {
       //AV_PIX_FMT_RGB0 当做已经预乘好的 AV_PIX_FMT_RGBA 也可以渲染出来，总之不让 GPU 再次计算就行了
       bpc = 8;
       bpp = 32;
       bitMapInfo = kCGBitmapByteOrderDefault |kCGImageAlphaNoneSkipLast;
    } else if (frame->format == AV_PIX_FMT_ARGB) {
        bpc = 8;
        bpp = 32;
        bitMapInfo = kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedFirst;
    } else if (frame->format == AV_PIX_FMT_RGBA) {
        bpc = 8;
        bpp = 32;
        ///已经预乘好的，不让GPU再次计算，直接渲染就行了
        bitMapInfo = kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedLast;
    } else {
        NSAssert(NO, @"WTF!");
    }
    void *pixels = frame->data[0];
    const size_t bpr = frame->linesize[0];
    const int w = frame->width;
    const int h = frame->height;
    
    return _CreateCGImage(pixels, w, h, bpc, bpp, bpr, bitMapInfo);
    //not support bpp = 24;
    return _CreateCGImageFromBitMap(pixels, w, h, bpc, bpp, bpr, bitMapInfo);
}

#pragma mark - YUV(NV12)-->CVPixelBufferRef Conversion

//https://stackoverflow.com/questions/25659671/how-to-convert-from-yuv-to-ciimage-for-ios
+ (CVPixelBufferRef)pixelBufferFromAVFrame:(AVFrame*)frame
{
    return [self pixelBufferFromAVFrame:frame opt:NULL];
}

+ (CVPixelBufferRef)pixelBufferFromAVFrame:(AVFrame *)picture
                                       opt:(CVPixelBufferPoolRef)poolRef
{
    if (picture->format == AV_PIX_FMT_NV21) {
        //later will swap VU. we won't modify the avframe data, because the frame can be dispaly again!
    } else {
        NSParameterAssert(picture->format == AV_PIX_FMT_NV12);
    }
    
    CVPixelBufferRef pixelBuffer = NULL;
    CVReturn result = kCVReturnError;
    if (poolRef) {
        result = CVPixelBufferPoolCreatePixelBuffer(NULL, poolRef, &pixelBuffer);
    } else {
        const int w = picture->width;
        const int h = picture->height;
        const int linesize = 32;//FFMpeg 解码数据对齐是32，这里期望CVPixelBuffer也能使用32对齐，但实际来看却是64！
        
        //AVCOL_RANGE_MPEG对应tv，AVCOL_RANGE_JPEG对应pc
        //Y′ values are conventionally shifted and scaled to the range [16, 235] (referred to as studio swing or "TV levels") rather than using the full range of [0, 255] (referred to as full swing or "PC levels").
        //https://en.wikipedia.org/wiki/YUV#Numerical_approximations
        OSType pixelFormatType = picture->color_range == AVCOL_RANGE_MPEG ? kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange : kCVPixelFormatType_420YpCbCr8BiPlanarFullRange;
        NSMutableDictionary* attributes = [NSMutableDictionary dictionary];
        [attributes setObject:@(linesize) forKey:(NSString*)kCVPixelBufferBytesPerRowAlignmentKey];
        [attributes setObject:[NSDictionary dictionary] forKey:(NSString*)kCVPixelBufferIOSurfacePropertiesKey];
        
        result = CVPixelBufferCreate(kCFAllocatorDefault,
                                     w,
                                     h,
                                     pixelFormatType,
                                     (__bridge CFDictionaryRef)(attributes),
                                     &pixelBuffer);
    }
    
    if (kCVReturnSuccess == result) {
        const int h = picture->height;
        CVPixelBufferLockBaseAddress(pixelBuffer,0);
        
        // Here y_src is Y-Plane of YUV(NV12) data.
        unsigned char *y_src  = picture->data[0];
        unsigned char *y_dest = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
        size_t y_src_bytesPerRow  = picture->linesize[0];
        size_t y_dest_bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
        /*
         将FFmpeg解码后的YUV数据塞到CVPixelBuffer中，这里必须注意不能使用以下三种形式，否则将可能导致画面错乱或者绿屏或程序崩溃！
         memcpy(y_dest, y_src, w * h);
         memcpy(y_dest, y_src, aFrame->linesize[0] * h);
         memcpy(y_dest, y_src, CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0) * h);
         
         原因是因为FFmpeg解码后的YUV数据的linesize大小是作了字节对齐的，所以视频的w和linesize[0]很可能不相等，同样的 CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0) 也是作了字节对齐的，并且对齐大小跟FFmpeg的对齐大小可能也不一样，这就导致了最坏情况下这三个值都不等！我的一个测试视频的宽度是852，FFMpeg解码使用了32字节对齐后linesize【0】是 864，而 CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0) 获取到的却是 896，通过计算得出使用的是 64 字节对齐的，所以上面三种 memcpy 的写法都不靠谱！
         【字节对齐】只是为了让CPU拷贝数据速度更快，由于对齐多出来的冗余字节不会用来显示，所以填 0 即可！目前来看FFmpeg使用32个字节做对齐，而CVPixelBuffer即使指定了32缺还是使用64个字节做对齐！
         以下代码的意思是：
            按行遍历 CVPixelBuffer 的每一行；
            先把该行全部填 0 ，然后把该行的FFmpeg解码数据（包括对齐字节）复制到 CVPixelBuffer 中；
            因为有上面分析的对齐不相等问题，所以只能一行一行的处理，不能直接使用 memcpy 简单处理！
         */
        for (int i = 0; i < h; i ++) {
            bzero(y_dest, y_dest_bytesPerRow);
            memcpy(y_dest, y_src, y_src_bytesPerRow);
            y_src  += y_src_bytesPerRow;
            y_dest += y_dest_bytesPerRow;
        }
        
        // Here uv_src is UV-Plane of YUV(NV12) data.
        unsigned char *uv_src = picture->data[1];
        unsigned char *uv_dest = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
        size_t uv_src_bytesPerRow  = picture->linesize[1];
        size_t uv_dest_bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
        
        /*
         对于 UV 的填充过程跟 Y 是一个道理，需要按行 memcpy 数据！
         */
        for (int i = 0; i < BYTE_ALIGN_2(h)/2; i ++) {
            bzero(uv_dest, uv_dest_bytesPerRow);
            memcpy(uv_dest, uv_src, uv_src_bytesPerRow);
            uv_src  += uv_src_bytesPerRow;
            uv_dest += uv_dest_bytesPerRow;
        }
        //memcpy(uv_dest, uv_src, bytesPerRowUV * BYTE_ALIGN_2(h)/2);
        
        //only swap VU for NV21
        if (picture->format == AV_PIX_FMT_NV21) {
            unsigned char *uv = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
            /*
             将VU交换成UV；
             */
            for (int i = 0; i < BYTE_ALIGN_2(h)/2; i ++) {
                for (int j = 0; j < uv_dest_bytesPerRow - 1; j+=2) {
                    int v = *uv;
                    *uv = *(uv + 1);
                    *(uv + 1) = v;
                    uv += 2;
                }
            }
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    }
    return (CVPixelBufferRef)CFAutorelease(pixelBuffer);
}

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
