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

CGImageRef _CreateCGImageFromBitMap(void *pixels, size_t w, size_t h, size_t bpc, size_t bpp, size_t bpr, int bmi)
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
    
    CGColorSpaceRelease(colorSpace);
    
    if (bitmapContext) {
        CGImageRef cgImage = CGBitmapContextCreateImage(bitmapContext);
        if (cgImage) {
            return (CGImageRef)CFAutorelease(cgImage);
        }
    }
    return NULL;
}

CGImageRef _CreateCGImage(void *pixels,size_t w, size_t h, size_t bpc, size_t bpp, size_t bpr, int bmi)
{
    const UInt8 *rgb = pixels;
    const CFIndex length = bpr * h;
    
    CFDataRef data = CFDataCreate(kCFAllocatorDefault, rgb, length);
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CFRelease(data);
    
    if (provider) {
        CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
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
        if (cgImage) {
            return (CGImageRef)CFAutorelease(cgImage);
        }
    }
    return NULL;
}

+ (CGImageRef _Nullable)cgImageFromRGBFrame:(AVFrame*)frame
{
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
    } else if (frame->format == AV_PIX_FMT_ARGB || frame->format == AV_PIX_FMT_0RGB) {
        //AV_PIX_FMT_0RGB 当做已经预乘好的 AV_PIX_FMT_ARGB 也可以渲染出来，总之不让 GPU 再次计算就行了
        bpc = 8;
        bpp = 32;
        bitMapInfo = kCGBitmapByteOrderDefault |kCGImageAlphaNoneSkipFirst;
    } else if (frame->format == AV_PIX_FMT_RGBA || frame->format == AV_PIX_FMT_RGB0) {
       //AV_PIX_FMT_RGB0 当做已经预乘好的 AV_PIX_FMT_RGBA 也可以渲染出来，总之不让 GPU 再次计算就行了
       bpc = 8;
       bpp = 32;
       bitMapInfo = kCGBitmapByteOrderDefault |kCGImageAlphaNoneSkipLast;
    }
//    没有找到创建 BGR 颜色空间的方法，所以不能转为 CGImage！
//    else if (frame->format == AV_PIX_FMT_ABGR || frame->format == AV_PIX_FMT_0BGR) {
//        bpc = 8;
//        bpp = 32;
//        bitMapInfo = kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedFirst;
//    } else if (frame->format == AV_PIX_FMT_BGRA || frame->format == AV_PIX_FMT_BGR0) {
//        bpc = 8;
//        bpp = 32;
//        ///已经预乘好的，不让GPU再次计算，直接渲染就行了
//        bitMapInfo = kCGBitmapByteOrderDefault | kCGImageAlphaPremultipliedLast;
//    }
    else {
        NSAssert(NO, @"not support [%d] Pixel format,use RGB555BE/RGB555LE/RGBA/ARGB/0RGB/RGB24 please!",frame->format);
        return NULL;
    }
    
    void *pixels = frame->data[0];
    const int w  = frame->width;
    const int h  = frame->height;
    const size_t bpr = frame->linesize[0];
    
    return _CreateCGImage(pixels, w, h, bpc, bpp, bpr, bitMapInfo);
    //not support bpp = 24;
    return _CreateCGImageFromBitMap(pixels, w, h, bpc, bpp, bpr, bitMapInfo);
}

+ (CIImage *)ciImageFromRGB32orBGR32Frame:(AVFrame *)frame
{
    CIFormat ciFmt = 0;
    if (frame->format == AV_PIX_FMT_ARGB || frame->format == AV_PIX_FMT_0RGB) {
        //AV_PIX_FMT_0RGB 当做已经预乘好的 AV_PIX_FMT_ARGB 也可以渲染出来，总之不让 GPU 再次计算就行了
        ciFmt = kCIFormatARGB8;
    } else if (frame->format == AV_PIX_FMT_RGBA || frame->format == AV_PIX_FMT_RGB0) {
       //AV_PIX_FMT_RGB0 当做已经预乘好的 AV_PIX_FMT_RGBA 也可以渲染出来，总之不让 GPU 再次计算就行了
       ciFmt = kCIFormatRGBA8;
    } else if (frame->format == AV_PIX_FMT_ABGR || frame->format == AV_PIX_FMT_0BGR) {
        if (@available(iOS 9.0, *)) {
            ciFmt = kCIFormatABGR8;
        } else {
            // Fallback on earlier versions
            NSAssert(NO, @"ABGR supported from iOS 9.0,use ARGB/0RGB/RGBA/RGB0/BGRA/BGR0 instead!",frame->format);
        }
    } else if (frame->format == AV_PIX_FMT_BGRA || frame->format == AV_PIX_FMT_BGR0) {
        ciFmt = kCIFormatBGRA8;
    } else {
        NSAssert(NO, @"not support [%d] Pixel format,use ARGB/0RGB/RGBA/RGB0/ABGR/0BGR/BGRA/BGR0 please!",frame->format);
        return nil;
    }
    
    void *pixels = frame->data[0];
    const size_t bpr = frame->linesize[0];
    const int w = frame->width;
    const int h = frame->height;
    const UInt8 *rgb = pixels;
    const CFIndex length = bpr * h;
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    NSData *data = [NSData dataWithBytes:rgb length:length];
    
    CIImage *ciImage = [[CIImage alloc] initWithBitmapData:data
                                               bytesPerRow:bpr
                                                      size:CGSizeMake(w, h)
                                                    format:ciFmt
                                                colorSpace:colorSpace];
    return ciImage;
}

+ (NSDictionary* _Nullable)_prepareCVPixelBufferAttibutes:(const int)format fullRange:(const bool)fullRange h:(const int)h w:(const int)w
{
    //CoreVideo does not provide support for all of these formats; this list just defines their names.
    
    int pixelFormatType = 0;
    
    if (format == AV_PIX_FMT_RGB24){
        pixelFormatType = kCVPixelFormatType_24RGB;
    } else if(format == AV_PIX_FMT_ARGB || format == AV_PIX_FMT_0RGB){
        pixelFormatType = kCVPixelFormatType_32ARGB;
    } else if(format == AV_PIX_FMT_NV12 || format == AV_PIX_FMT_NV21){
        pixelFormatType = fullRange ? kCVPixelFormatType_420YpCbCr8BiPlanarFullRange : kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
        //for AV_PIX_FMT_NV21: later will swap VU. we won't modify the avframe data, because the frame can be dispaly again!
    } else if(format == AV_PIX_FMT_BGRA || format == AV_PIX_FMT_BGR0){
        pixelFormatType = kCVPixelFormatType_32BGRA;
    }
//    RGB555 可以创建出 CVPixelBuffer，但是显示时失败了。
//    else if (format == AV_PIX_FMT_RGB555BE) {
//        pixelFormatType = kCVPixelFormatType_16BE555;
//    } else if (format == AV_PIX_FMT_RGB555LE) {
//        pixelFormatType = kCVPixelFormatType_16LE555;
//    }
    else {
        NSAssert(NO,@"unsupported pixel format!");
        return nil;
    }
    
    const int linesize = 32;//FFMpeg 解码数据对齐是32，这里期望CVPixelBuffer也能使用32对齐，但实际来看却是64！
    NSMutableDictionary*attributes = [NSMutableDictionary dictionary];
    [attributes setObject:@(pixelFormatType) forKey:(NSString*)kCVPixelBufferPixelFormatTypeKey];
    [attributes setObject:[NSNumber numberWithInt:w] forKey: (NSString*)kCVPixelBufferWidthKey];
    [attributes setObject:[NSNumber numberWithInt:h] forKey: (NSString*)kCVPixelBufferHeightKey];
    [attributes setObject:@(linesize) forKey:(NSString*)kCVPixelBufferBytesPerRowAlignmentKey];
    [attributes setObject:[NSDictionary dictionary] forKey:(NSString*)kCVPixelBufferIOSurfacePropertiesKey];
    return attributes;
}

+ (CVPixelBufferPoolRef _Nullable)createCVPixelBufferPoolRef:(const int)format w:(const int)w h:(const int)h fullRange:(const bool)fullRange
{
    NSDictionary * attributes = [self _prepareCVPixelBufferAttibutes:format fullRange:fullRange h:h w:w];
    if (!attributes) {
        return NULL;
    }
    
    CVPixelBufferPoolRef pixelBufferPool = NULL;
    if (kCVReturnSuccess != CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL, (__bridge CFDictionaryRef) attributes, &pixelBufferPool)){
        NSLog(@"CVPixelBufferPoolCreate Failed");
        return NULL;
    } else {
        return (CVPixelBufferPoolRef)CFAutorelease((const void *)pixelBufferPool);
    }
}

//https://stackoverflow.com/questions/25659671/how-to-convert-from-yuv-to-ciimage-for-ios
+ (CVPixelBufferRef _Nullable)pixelBufferFromAVFrame:(AVFrame *)frame
                                                 opt:(CVPixelBufferPoolRef)poolRef
{
    CVPixelBufferRef pixelBuffer = NULL;
    CVReturn result = kCVReturnError;
    
    const int w = frame->width;
    const int h = frame->height;
    const int format = frame->format;
    
    if (poolRef) {
        result = CVPixelBufferPoolCreatePixelBuffer(NULL, poolRef, &pixelBuffer);
    } else {
        //AVCOL_RANGE_MPEG对应tv，AVCOL_RANGE_JPEG对应pc
        //Y′ values are conventionally shifted and scaled to the range [16, 235] (referred to as studio swing or "TV levels") rather than using the full range of [0, 255] (referred to as full swing or "PC levels").
        //https://en.wikipedia.org/wiki/YUV#Numerical_approximations
        
        const bool fullRange = frame->color_range != AVCOL_RANGE_MPEG;
        NSDictionary * attributes = [self _prepareCVPixelBufferAttibutes:format fullRange:fullRange h:h w:w];
        if (!attributes) {
            return NULL;
        }
        const int pixelFormatType = [attributes[(NSString*)kCVPixelBufferBytesPerRowAlignmentKey] intValue];
        
        result = CVPixelBufferCreate(kCFAllocatorDefault,
                                     w,
                                     h,
                                     pixelFormatType,
                                     (__bridge CFDictionaryRef)(attributes),
                                     &pixelBuffer);
    }
    
    if (kCVReturnSuccess == result) {
        CVPixelBufferLockBaseAddress(pixelBuffer,0);
        
        /**
         kCVReturnInvalidPixelFormat
         AV_PIX_FMT_BGR24,
         AV_PIX_FMT_ABGR,
         AV_PIX_FMT_0BGR,
         AV_PIX_FMT_RGBA,
         AV_PIX_FMT_RGB0,
         
         // 可以创建 pixelbuffer，但是构建的 CIImage 是 nil ！
         AV_PIX_FMT_RGB555BE,
         AV_PIX_FMT_RGB555LE,
         */
        if(format == AV_PIX_FMT_BGRA || format == AV_PIX_FMT_BGR0 || format == AV_PIX_FMT_ARGB || format == AV_PIX_FMT_0RGB || format == AV_PIX_FMT_RGB24 || format == AV_PIX_FMT_RGB555BE || format == AV_PIX_FMT_RGB555LE){
           uint8_t *rgb_src  = frame->data[0];
           uint8_t *rgb_dest = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
           size_t src_bytesPerRow  = frame->linesize[0];
           size_t dest_bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
           for (int i = 0; i < h; i ++) {
               bzero(rgb_dest, dest_bytesPerRow);
               memcpy(rgb_dest, rgb_src, dest_bytesPerRow);
               rgb_src  += src_bytesPerRow;
               rgb_dest += dest_bytesPerRow;
           }
        } else if(format == AV_PIX_FMT_NV12 || format == AV_PIX_FMT_NV21){
            
            // Here y_src is Y-Plane of YUV(NV12) data.
            uint8_t *y_src  = frame->data[0];
            uint8_t *y_dest = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
            size_t y_src_bytesPerRow  = frame->linesize[0];
            size_t y_dest_bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0);
            /*
             将FFmpeg解码后的YUV数据塞到CVPixelBuffer中，这里必须注意不能使用以下三种形式，否则将可能导致画面错乱或者绿屏或程序崩溃！
             memcpy(y_dest, y_src, w * h);
             memcpy(y_dest, y_src, aFrame->linesize[0] * h);
             memcpy(y_dest, y_src, CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0) * h);
             
             原因是因为FFmpeg解码后的YUV数据的linesize大小是作了字节对齐的，所以视频的w和linesize[0]很可能不相等，同样的 CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0) 也是作了字节对齐的，并且对齐大小跟FFmpeg的对齐大小可能也不一样，这就导致了最坏情况下这三个值都不等！我的一个测试视频的宽度是852，FFMpeg解码使用了32字节对齐后linesize【0】是 864，而 CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0) 获取到的却是 896，通过计算得出使用的是 64 字节对齐的，所以上面三种 memcpy 的写法都不靠谱！
             【字节对齐】只是为了让CPU拷贝数据速度更快，由于对齐多出来的冗余字节不会用来显示，所以填 0 即可！目前来看FFmpeg使用32个字节做对齐，而CVPixelBuffer即使指定了32却还是使用64个字节做对齐！
             以下代码的意思是：
                按行遍历 CVPixelBuffer 的每一行；
                先把该行全部填 0 ，然后最大限度的将 FFmpeg 解码数据（包括对齐字节）copy 到 CVPixelBuffer 中；
                因为有上面分析的对齐不相等问题，所以只能一行一行的处理，不能直接使用 memcpy 简单处理！
             */
            for (int i = 0; i < h; i ++) {
                bzero(y_dest, y_dest_bytesPerRow);
                memcpy(y_dest, y_src, MIN(y_src_bytesPerRow, y_dest_bytesPerRow));
                y_src  += y_src_bytesPerRow;
                y_dest += y_dest_bytesPerRow;
            }
            
            // Here uv_src is UV-Plane of YUV(NV12) data.
            uint8_t *uv_src = frame->data[1];
            uint8_t *uv_dest = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
            size_t uv_src_bytesPerRow  = frame->linesize[1];
            size_t uv_dest_bytesPerRow = CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 1);
            
            if (frame->format == AV_PIX_FMT_NV21) {
                //need swap VU for NV21
                
                for (int i = 0; i < BYTE_ALIGN_2(h)/2; i ++) {
                    bzero(uv_dest, uv_dest_bytesPerRow);
                    //将VU交换成UV；
                    for (int j = 0; j < MIN(uv_src_bytesPerRow,uv_dest_bytesPerRow); j+=2) {
                        uint8_t v = *uv_src;
                        *uv_dest = *(uv_src + 1);
                        *(uv_dest + 1) = v;
                        uv_dest += 2;
                        uv_src += 2;
                    }
                }
            } else {
                //按行 memcpy 数据！
                for (int i = 0; i < BYTE_ALIGN_2(h)/2; i ++) {
                    bzero(uv_dest, uv_dest_bytesPerRow);
                    memcpy(uv_dest, uv_src, MIN(uv_src_bytesPerRow,uv_dest_bytesPerRow));
                    uv_src  += uv_src_bytesPerRow;
                    uv_dest += uv_dest_bytesPerRow;
                }
            }
        } else {
            CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
            NSAssert(NO,@"unsupported pixel format!");
            return NULL;
        }
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
        return (CVPixelBufferRef)CFAutorelease(pixelBuffer);
    } else {
        return NULL;
    }
}

+ (CMSampleBufferRef)cmSampleBufferRefFromCVPixelBufferRef:(CVPixelBufferRef)pixelBuffer
{
    if (pixelBuffer) {
        //获取视频信息
        CMVideoFormatDescriptionRef videoInfo = NULL;
        OSStatus result = CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBuffer, &videoInfo);
        if (result == noErr) {
            //不设置具体时间信息
            CMSampleTimingInfo timing = {kCMTimeInvalid, kCMTimeInvalid, kCMTimeInvalid};
            
            CMSampleBufferRef sampleBuffer = NULL;
            result = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault,pixelBuffer, true, NULL, NULL, videoInfo, &timing, &sampleBuffer);
            if (result == noErr) {
                CFRelease(videoInfo);
                CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, YES);
                CFMutableDictionaryRef dict = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
                CFDictionarySetValue(dict, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);
                return (CMSampleBufferRef)CFAutorelease(sampleBuffer);
            } else {
                CFRelease(videoInfo);
                NSAssert(NO, @"Can't create CMSampleBuffer from image buffer!");
            }
        } else {
            NSAssert(NO, @"Can't create VideoFormatDescription from image buffer!");
        }
    }
    return NULL;
}

@end
