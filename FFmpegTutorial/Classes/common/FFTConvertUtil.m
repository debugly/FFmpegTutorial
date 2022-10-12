//
//  FFTConvertUtil.m
//  FFmpegTutorial
//
//  Created by Matt Reach on 2020/6/3.
//

#import "FFTConvertUtil.h"
#import <libavutil/frame.h>
#import <libavutil/imgutils.h>

#if TARGET_OS_IOS
#import <OpenGLES/ES1/glext.h>
#import <UIKit/UIGraphics.h>
#else
#import <OpenGL/gl.h>
#import <OpenGL/glext.h>
#endif

#define BYTE_ALIGN_2(_s_) (( _s_ + 1)/2 * 2)

typedef struct {
    double r;       // a fraction between 0 and 1
    double g;       // a fraction between 0 and 1
    double b;       // a fraction between 0 and 1
} rgb;

typedef struct {
    double h;       // a fraction between 0 and 1
    double s;       // a fraction between 0 and 1
    double v;       // a fraction between 0 and 1
} hsv;

rgb hsv2rgb(hsv in)
{
    double      hh, p, q, t, ff;
    long        i;
    rgb         out;

    if(in.s <= 0.0) {       // < is bogus, just shuts up warnings
        out.r = in.v;
        out.g = in.v;
        out.b = in.v;
        return out;
    }
    hh = in.h * 360;
    if(hh >= 360.0) hh = 0.0;
    hh /= 60.0;
    i = (long)hh;
    ff = hh - i;
    p = in.v * (1.0 - in.s);
    q = in.v * (1.0 - (in.s * ff));
    t = in.v * (1.0 - (in.s * (1.0 - ff)));

    switch(i) {
    case 0:
        out.r = in.v;
        out.g = t;
        out.b = p;
        break;
    case 1:
        out.r = q;
        out.g = in.v;
        out.b = p;
        break;
    case 2:
        out.r = p;
        out.g = in.v;
        out.b = t;
        break;

    case 3:
        out.r = p;
        out.g = q;
        out.b = in.v;
        break;
    case 4:
        out.r = t;
        out.g = p;
        out.b = in.v;
        break;
    case 5:
    default:
        out.r = in.v;
        out.g = p;
        out.b = q;
        break;
    }
    return out;
}

@implementation FFTConvertUtil

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
//        //已经预乘好的，不让GPU再次计算，直接渲染就行了
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
    
    if (format == AV_PIX_FMT_RGB24) {
        pixelFormatType = kCVPixelFormatType_24RGB;
    } else if (format == AV_PIX_FMT_ARGB || format == AV_PIX_FMT_0RGB) {
        pixelFormatType = kCVPixelFormatType_32ARGB;
    } else if (format == AV_PIX_FMT_NV12 || format == AV_PIX_FMT_NV21) {
        pixelFormatType = fullRange ? kCVPixelFormatType_420YpCbCr8BiPlanarFullRange : kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange;
        //for AV_PIX_FMT_NV21: later will swap VU. we won't modify the avframe data, because the frame can be dispaly again!
    } else if (format == AV_PIX_FMT_BGRA || format == AV_PIX_FMT_BGR0) {
        pixelFormatType = kCVPixelFormatType_32BGRA;
    } else if (format == AV_PIX_FMT_YUV420P) {
        pixelFormatType = fullRange ? kCVPixelFormatType_420YpCbCr8PlanarFullRange : kCVPixelFormatType_420YpCbCr8Planar;
    } else if (format == AV_PIX_FMT_NV16) {
        pixelFormatType = fullRange ? kCVPixelFormatType_422YpCbCr8BiPlanarFullRange : kCVPixelFormatType_422YpCbCr8BiPlanarVideoRange;
    } else if (format == AV_PIX_FMT_UYVY422) {
        pixelFormatType = fullRange ? kCVPixelFormatType_422YpCbCr8FullRange : kCVPixelFormatType_422YpCbCr8;
    } else if (format == AV_PIX_FMT_YUV444P10) {
        pixelFormatType = kCVPixelFormatType_444YpCbCr10;
    } else if (format == AV_PIX_FMT_YUYV422) {
        pixelFormatType = kCVPixelFormatType_422YpCbCr8_yuvs;
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
    const int linesize = 32;//FFmpeg 解码数据对齐是32，这里期望CVPixelBuffer也能使用32对齐，但实际来看却是64！
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
    if (NULL == frame) {
        return NULL;
    }
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
        const int pixelFormatType = [attributes[(NSString*)kCVPixelBufferPixelFormatTypeKey] intValue];
        
        result = CVPixelBufferCreate(kCFAllocatorDefault,
                                     w,
                                     h,
                                     pixelFormatType,
                                     (__bridge CFDictionaryRef)(attributes),
                                     &pixelBuffer);
    }
    
    if (kCVReturnSuccess == result) {
        
        int planes = 1;
        if (CVPixelBufferIsPlanar(pixelBuffer)) {
            planes = (int)CVPixelBufferGetPlaneCount(pixelBuffer);
        }
        
        for (int p = 0; p < planes; p++) {
            CVPixelBufferLockBaseAddress(pixelBuffer,p);
            uint8_t *src = frame->data[p];
            uint8_t *dst = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, p);
            int src_linesize = (int)frame->linesize[p];
            int dst_linesize = (int)CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, p);
            int height = (int)CVPixelBufferGetHeightOfPlane(pixelBuffer, p);
            int bytewidth = MIN(src_linesize, dst_linesize);
            av_image_copy_plane(dst, dst_linesize, src, src_linesize, bytewidth, height);
            CVPixelBufferUnlockBaseAddress(pixelBuffer, p);
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
             
             将FFmpeg解码后的YUV数据塞到CVPixelBuffer中，这里必须注意不能使用以下三种形式，否则将可能导致画面错乱或者绿屏或程序崩溃！
             memcpy(y_dest, y_src, w * h);
             memcpy(y_dest, y_src, aFrame->linesize[0] * h);
             memcpy(y_dest, y_src, CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0) * h);
             
             原因是因为FFmpeg解码后的YUV数据的linesize大小是作了字节对齐的，所以视频的w和linesize[0]很可能不相等，同样的 CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0) 也是作了字节对齐的，并且对齐大小跟FFmpeg的对齐大小可能也不一样，这就导致了最坏情况下这三个值都不等！我的一个测试视频的宽度是852，FFmpeg解码使用了32字节对齐后linesize【0】是 864，而 CVPixelBufferGetBytesPerRowOfPlane(pixelBuffer, 0) 获取到的却是 896，通过计算得出使用的是 64 字节对齐的，所以上面三种 memcpy 的写法都不靠谱！
             【字节对齐】只是为了让CPU拷贝数据速度更快，由于对齐多出来的冗余字节不会用来显示，所以填 0 即可！目前来看FFmpeg使用32个字节做对齐，而CVPixelBuffer即使指定了32却还是使用64个字节做对齐！
             以下代码的意思是：
                按行遍历 CVPixelBuffer 的每一行；
                先把该行全部填 0 ，然后最大限度的将 FFmpeg 解码数据（包括对齐字节）copy 到 CVPixelBuffer 中；
                因为存在上面分析的对齐不相等问题，所以只能一行一行的处理，不能直接使用 memcpy 简单处理！
             */
            /*
            for (; height > 0; height--) {
                bzero(dest, dst_linesize);
                memcpy(dest, src, MIN(src_linesize, dst_linesize));
                src  += src_linesize;
                dest += dst_linesize;
            }
            
            后来偶然间找到了 av_image_copy_plane 这个方法，其内部实现就是上面的按行 copy。
            */
        }
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

#if TARGET_OS_IOS
//https://developer.apple.com/library/archive/qa/qa1704/_index.html
+ (UIImage *)snapshot:(GLint)renderbuffer scale:(CGFloat)scale
{
    if (renderbuffer <= 0) {
        return nil;
    }
    GLint backingWidth, backingHeight;
     
    // Bind the color renderbuffer used to render the OpenGL ES view
    // If your application only creates a single color renderbuffer which is already bound at this point,
    // this call is redundant, but it is needed if you're dealing with multiple renderbuffers.
    // Note, replace "renderbuffer" with the actual name of the renderbuffer object defined in your class.
    glBindRenderbufferOES(GL_RENDERBUFFER_OES, renderbuffer);
 
    // Get the size of the backing CAEAGLLayer
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_WIDTH_OES, &backingWidth);
    glGetRenderbufferParameterivOES(GL_RENDERBUFFER_OES, GL_RENDERBUFFER_HEIGHT_OES, &backingHeight);
 
    GLint x = 0, y = 0, width = backingWidth, height = backingHeight;
    NSInteger dataLength = width * height * 4;
    GLubyte *data = (GLubyte*)malloc(dataLength * sizeof(GLubyte));
 
    // Read pixel data from the framebuffer
    glPixelStorei(GL_PACK_ALIGNMENT, 4);
    glReadPixels(x, y, width, height, GL_RGBA, GL_UNSIGNED_BYTE, data);
 
    // Create a CGImage with the pixel data
    // If your OpenGL ES content is opaque, use kCGImageAlphaNoneSkipLast to ignore the alpha channel
    // otherwise, use kCGImageAlphaPremultipliedLast
    CGDataProviderRef ref = CGDataProviderCreateWithData(NULL, data, dataLength, NULL);
    CGColorSpaceRef colorspace = CGColorSpaceCreateDeviceRGB();
    CGImageRef iref = CGImageCreate(width, height, 8, 32, width * 4, colorspace, kCGBitmapByteOrder32Big | kCGImageAlphaPremultipliedLast,
                                    ref, NULL, true, kCGRenderingIntentDefault);
 
    // OpenGL ES measures data in PIXELS
    // Create a graphics context with the target size measured in POINTS
    NSInteger widthInPoints, heightInPoints;
    // On iOS 4 and later, use UIGraphicsBeginImageContextWithOptions to take the scale into consideration
    // Set the scale parameter to your OpenGL ES view's contentScaleFactor
    // so that you get a high-resolution snapshot when its value is greater than 1.0
    widthInPoints = width / scale;
    heightInPoints = height / scale;
    UIGraphicsBeginImageContextWithOptions(CGSizeMake(widthInPoints, heightInPoints), NO, scale);
 
    CGContextRef cgcontext = UIGraphicsGetCurrentContext();
 
    // UIKit coordinate system is upside down to GL/Quartz coordinate system
    // Flip the CGImage by rendering it to the flipped bitmap context
    // The size of the destination area is measured in POINTS
    CGContextSetBlendMode(cgcontext, kCGBlendModeCopy);
    CGContextDrawImage(cgcontext, CGRectMake(0.0, 0.0, widthInPoints, heightInPoints), iref);
 
    // Retrieve the UIImage from the current context
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
 
    UIGraphicsEndImageContext();
 
    // Clean up
    free(data);
    CFRelease(ref);
    CFRelease(colorspace);
    CGImageRelease(iref);
 
    return image;
}
#else
//https://github.com/tubrokAlien/CocoaGLPaint/blob/master/AKCocoaGLPaint/Categories/NSOpenGLView%2BAKAdditions.m
static void memxor(unsigned char *dst, unsigned char *src, unsigned int bytes)
{
    while (bytes--) *dst++ ^= *src++;
}

static void memswap(unsigned char *a, unsigned char *b, unsigned int bytes)
{
    memxor(a, b, bytes);
    memxor(b, a, bytes);
    memxor(a, b, bytes);
}

+ (NSImage *)snapshot:(NSOpenGLContext *)openGLContext size:(CGSize)size
{
    if (!openGLContext) {
        return nil;
    }
    
    if (CGSizeEqualToSize(CGSizeZero, size)) {
        return nil;
    }
    
    int height = size.height;
    int width = size.width;
    
    NSBitmapImageRep *imageRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL
                                                       pixelsWide: width
                                                       pixelsHigh: height
                                                    bitsPerSample: 8
                                                  samplesPerPixel: 4
                                                         hasAlpha: YES
                                                         isPlanar: NO
                                                   colorSpaceName: NSCalibratedRGBColorSpace
                                                      bytesPerRow: 0                // indicates no empty bytes at row end
                                                     bitsPerPixel: 0];
    
    [openGLContext makeCurrentContext];
    
    unsigned char *bitmapData = [imageRep bitmapData];
    
    //make xcode happy
    int bytesPerRow = (int)[imageRep bytesPerRow];
    
    glPixelStorei(GL_PACK_ROW_LENGTH, 8 * bytesPerRow / [imageRep bitsPerPixel]);
    
    glReadPixels(0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, bitmapData);
    
    // Flip the bitmap vertically to account for OpenGL coordinate system difference
    // from NSImage coordinate system.
    
    for (int row = 0; row < height/2; row++)
    {
        unsigned char *a, *b;
        
        a = bitmapData + row * bytesPerRow;
        b = bitmapData + (height - 1 - row) * bytesPerRow;
        
        memswap(a, b, bytesPerRow);
    }
    
    // Create the NSImage from the bitmap
    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(width, height)];
    [image addRepresentation:imageRep];
    
    // Previously we did not flip the bitmap, and instead did [image setFlipped:YES];
    // This does not work properly (i.e., the image remained inverted) when pasting
    // the image to AppleWorks or GraphicConvertor.
    
    return image;
}

static inline const char * GetGLErrorString(GLenum error)
{
    const char *str;
    switch( error )
    {
        case GL_NO_ERROR:
            str = "GL_NO_ERROR";
            break;
        case GL_INVALID_ENUM:
            str = "GL_INVALID_ENUM";
            break;
        case GL_INVALID_VALUE:
            str = "GL_INVALID_VALUE";
            break;
        case GL_INVALID_OPERATION:
            str = "GL_INVALID_OPERATION";
            break;
        case GL_OUT_OF_MEMORY:
            str = "GL_OUT_OF_MEMORY";
            break;
        case GL_INVALID_FRAMEBUFFER_OPERATION:
            str = "GL_INVALID_FRAMEBUFFER_OPERATION";
            break;
#if defined __gl_h_
        case GL_STACK_OVERFLOW:
            str = "GL_STACK_OVERFLOW";
            break;
        case GL_STACK_UNDERFLOW:
            str = "GL_STACK_UNDERFLOW";
            break;
        case GL_TABLE_TOO_LARGE:
            str = "GL_TABLE_TOO_LARGE";
            break;
#endif
        default:
            str = "(ERROR: Unknown Error Enum)";
            break;
    }
    return str;
}


#define GetGLError()                                  \
{                                                     \
    GLenum err = glGetError();                        \
    while (err != GL_NO_ERROR)                        \
    {                                                 \
        NSLog(@"GLError %s set in File:%s Line:%d\n", \
        GetGLErrorString(err), __FILE__, __LINE__);   \
        err = glGetError();                           \
    }                                                 \
}


+ (NSImage *)snapshotFBO:(GLint)renderbuffer size:(CGSize)size
{
    if (renderbuffer <= 0) {
        return nil;
    }
    // Bind the color renderbuffer used to render the OpenGL ES view
    // If your application only creates a single color renderbuffer which is already bound at this point,
    // this call is redundant, but it is needed if you're dealing with multiple renderbuffers.
    // Note, replace "renderbuffer" with the actual name of the renderbuffer object defined in your class.
    GetGLError();
//    glBindRenderbuffer(GL_RENDERBUFFER, renderbuffer);
    GLint width = 0, height = 0;
//    GetGLError();
//    // Get the size
//    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_WIDTH, &width);
//    glGetRenderbufferParameteriv(GL_RENDERBUFFER, GL_RENDERBUFFER_HEIGHT, &height);
//    GetGLError();
    
    width  = size.width;
    height = size.height;
    NSBitmapImageRep *imageRep = [[NSBitmapImageRep alloc] initWithBitmapDataPlanes: NULL
                                                       pixelsWide: width
                                                       pixelsHigh: height
                                                    bitsPerSample: 8
                                                  samplesPerPixel: 4
                                                         hasAlpha: YES
                                                         isPlanar: NO
                                                   colorSpaceName: NSCalibratedRGBColorSpace
                                                      bytesPerRow: 0                // indicates no empty bytes at row end
                                                     bitsPerPixel: 0];
    
    unsigned char *bitmapData = [imageRep bitmapData];
    
    //make xcode happy
    int bytesPerRow = (int)[imageRep bytesPerRow];
    // Read pixel data from the framebuffer
    glPixelStorei(GL_PACK_ALIGNMENT, 4);
    glPixelStorei(GL_PACK_ROW_LENGTH, 8 * bytesPerRow / [imageRep bitsPerPixel]);
    
    glReadPixels(0, 0, width, height, GL_RGBA, GL_UNSIGNED_BYTE, bitmapData);
    
    // Flip the bitmap vertically to account for OpenGL coordinate system difference
    // from NSImage coordinate system.
    
    for (int row = 0; row < height/2; row++)
    {
        unsigned char *a, *b;
        
        a = bitmapData + row * bytesPerRow;
        b = bitmapData + (height - 1 - row) * bytesPerRow;
        
        memswap(a, b, bytesPerRow);
    }
    
    // Create the NSImage from the bitmap
    NSImage *image = [[NSImage alloc] initWithSize:NSMakeSize(width, height)];
    [image addRepresentation:imageRep];
    
    // Previously we did not flip the bitmap, and instead did [image setFlipped:YES];
    // This does not work properly (i.e., the image remained inverted) when pasting
    // the image to AppleWorks or GraphicConvertor.
    
    return image;
}

#endif


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
static void fillGrayBar(int barnum,size_t bytesPerRow,unsigned char *y,unsigned char *uv,int w,int h)
{
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

+ (CVPixelBufferRef)grayColorBarPixelBuffer:(int)w h:(int)h barNum:(int)barNum opt:(CVPixelBufferPoolRef)poolRef
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
        
        fillGrayBar(barNum,y_bytesPerRow,yDestPlane,uvDestPlane,w,h);
        
        CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    }
    
    return (CVPixelBufferRef)CFAutorelease(pixelBuffer);
}

+ (void)fill3Ball:(CVPixelBufferRef)pxbuffer
{
    int width  = (int)CVPixelBufferGetWidth(pxbuffer);;
    int height = (int)CVPixelBufferGetHeight(pxbuffer);

    CVPixelBufferLockBaseAddress(pxbuffer, 0);
    void *pxdata = CVPixelBufferGetBaseAddress(pxbuffer);
    NSParameterAssert(pxdata != NULL);

    CGColorSpaceRef rgbColorSpace = CGColorSpaceCreateDeviceRGB();
    CGContextRef context = CGBitmapContextCreate(pxdata, width, height, 8, CVPixelBufferGetBytesPerRow(pxbuffer), rgbColorSpace, kCGImageAlphaPremultipliedFirst);
    NSParameterAssert(context);

    const CGFloat components[4] = {1, 1, 1, 1};
    CGColorRef backgroundColor = CGColorCreate(rgbColorSpace, components);
    CGColorSpaceRelease(rgbColorSpace);
    
    CGContextSetFillColorWithColor(context, backgroundColor);
    CGContextFillRect(context, CGRectMake(0, 0, width, height));
    CGColorRelease(backgroundColor);
    /*
     mach_absolute_time() / NSEC_PER_SEC 的单位是：秒
     delta 越大旋转的越慢；
     假如上层每隔1s调用一次，delta为 1时，旋转角度大约是 360 度，会保持不动；
     当上层两次调用间隔 小于 两次调用 time 差值时，每次移动的角度就是: (time2 - time1) * 360 / delta
     假如 delta 为 50 时, 上层 40ms 调用一次，那么每次改变的角度就是 0.4 * 360 / 50 = 2.88度
     */
    
    int delta = 25;
    
    double time = 1.0 * CFAbsoluteTimeGetCurrent() / delta;
    
    double period = 4.0;
    double fraction = sin(2 * M_PI * time / period) / 2 + 0.5;
    hsv rawBoxColorHSV;
    rawBoxColorHSV.h = fraction;
    rawBoxColorHSV.s = 0.5;
    rawBoxColorHSV.v = 1.0;
    rgb rawBoxColorRGB = hsv2rgb(rawBoxColorHSV);
    
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    const CGFloat components2[4] = {rawBoxColorRGB.r, rawBoxColorRGB.g, rawBoxColorRGB.b, 1};
    CGColorRef boxColor = CGColorCreate(colorSpace, components2);
    CGColorSpaceRelease(colorSpace);
    CGContextSetFillColorWithColor(context, boxColor);
    for (int i = 0; i < 3; i++) {
        CGContextSaveGState(context);
        double rotation_fraction = (time + i) / 3.0;
        CGContextTranslateCTM(context, width / 2, height / 2);
        CGContextRotateCTM(context, 2 * M_PI * rotation_fraction);
        double x_center = width * 0.1;
        double y_center = 0.0;
        CGContextFillEllipseInRect(context, CGRectMake(x_center - 50, y_center - 50, 100, 100));
        CGContextRestoreGState(context);
    }

    CGColorRelease(boxColor);

    CVPixelBufferUnlockBaseAddress(pxbuffer, 0);
}

+ (CVPixelBufferRef)ball3PixelBuffer:(int)w h:(int)h opt:(CVPixelBufferPoolRef)poolRef
{
    CVPixelBufferRef pixelBuffer = NULL;
    CVReturn result = kCVReturnError;
    
    if (poolRef) {
        result = CVPixelBufferPoolCreatePixelBuffer(NULL, poolRef, &pixelBuffer);
    } else {
        NSDictionary *pixelAttributes = [NSDictionary dictionaryWithObjectsAndKeys:
                                     [NSNumber numberWithBool:YES], kCVPixelBufferCGImageCompatibilityKey,
                                     [NSNumber numberWithBool:YES], kCVPixelBufferCGBitmapContextCompatibilityKey,
                                         @{},kCVPixelBufferIOSurfacePropertiesKey,
                                         nil];

        result = CVPixelBufferCreate(kCFAllocatorDefault,
                                     w,
                                     h,
                                     kCVPixelFormatType_32ARGB,//kCVPixelFormatType_420YpCbCr8BiPlanarFullRange
                                     (__bridge CFDictionaryRef)(pixelAttributes),
                                     &pixelBuffer);
    }
    
    if (kCVReturnSuccess == result) {
        [self fill3Ball:pixelBuffer];
    }
    
    return (CVPixelBufferRef)CFAutorelease(pixelBuffer);
}

@end
