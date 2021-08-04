//https://github.com/mpv-player/mpv

//vda: add support for nv12 image formats
//
//The hardware always decodes to nv12 so using this image format causes less cpu
//usage than uyvy (which we are currently using, since Apple examples and other
//free software use that). The reduction in cpu usage can add up to quite a bit,
//especially for 4k or high fps video.
//
//This needs an accompaning commit in libavcodec.
//提交：
//5258c012febdfba0ef56ad8ce6f7cb003611c47b

#ifndef __renderer_pixfmt__INTERNAL__H
#define __renderer_pixfmt__INTERNAL__H

#import <CoreVideo/CVPixelBuffer.h>
#import <AVFoundation/AVCaptureVideoDataOutput.h>
#include <OpenGL/gl.h>

#if TARGET_OS_OSX
    #define OpenGLTextureCacheRef   CVOpenGLTextureCacheRef
    #define OpenGLTextureRef        CVOpenGLTextureRef
    #define OpenGLTextureCacheFlush CVOpenGLTextureCacheFlush
    #define OpenGLTextureGetTarget  CVOpenGLTextureGetTarget
    #define OpenGLTextureGetName    CVOpenGLTextureGetName
    #define OpenGL_RED              GL_RED
    #define OpenGL_RG               GL_RG
#else
    #define OpenGLTextureCacheRef   CVOpenGLESTextureCacheRef
    #define OpenGLTextureRef        CVOpenGLESTextureRef
    #define OpenGLTextureCacheFlush CVOpenGLESTextureCacheFlush
    #define OpenGLTextureGetTarget  CVOpenGLESTextureGetTarget
    #define OpenGLTextureGetName    CVOpenGLESTextureGetName
    #define OpenGL_RED_EXT          GL_RED_EXT
    #define OpenGL_RG_EXT           GL_RG_EXT
#endif

#define MP_MAX_PLANES 4
#define MP_ARRAY_SIZE(s) (sizeof(s) / sizeof((s)[0]))

struct vt_gl_plane_format {
    GLenum gl_format;
    GLenum gl_type;
    GLenum gl_internal_format;
};

struct vt_format {
    uint32_t cvpixfmt;
    int planes;
    struct vt_gl_plane_format gl[MP_MAX_PLANES];
};

static struct vt_format vt_formats[] = {
    {
        .cvpixfmt = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
        .planes = 2,
        .gl = {
//           when use RED/RG,the fsh must use r and rg!
//            { GL_RED, GL_UNSIGNED_BYTE, GL_R8 },
//            { GL_RG,  GL_UNSIGNED_BYTE, GL_RG8 } ,
//            { GL_RED, GL_UNSIGNED_BYTE, GL_RED },
//            { GL_RG,  GL_UNSIGNED_BYTE, GL_RG } ,
//           when use LUMINANCE/LUMINANCE_ALPHA,the fsh must use r and ra!
            { GL_LUMINANCE, GL_UNSIGNED_BYTE, GL_LUMINANCE },
            { GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, GL_LUMINANCE_ALPHA }
        }
    },
    {
        .cvpixfmt = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
        .planes = 2,
        .gl = {
            { GL_LUMINANCE, GL_UNSIGNED_BYTE, GL_LUMINANCE },
            { GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, GL_LUMINANCE_ALPHA }
        }
    },
    {
        .cvpixfmt = kCVPixelFormatType_422YpCbCr8FullRange,
        .planes = 2,
        .gl = {
            { GL_LUMINANCE, GL_UNSIGNED_BYTE, GL_LUMINANCE },
            { GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, GL_LUMINANCE_ALPHA }
        }
    },
    {
        .cvpixfmt = kCVPixelFormatType_422YpCbCr8_yuvs,
        .planes = 2,
        .gl = {
            { GL_LUMINANCE, GL_UNSIGNED_BYTE, GL_LUMINANCE },
            { GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, GL_LUMINANCE_ALPHA }
        }
    },
#if TARGET_OS_OSX
    {
        .cvpixfmt = kCVPixelFormatType_422YpCbCr8,
        .planes = 1,
        .gl = {
            { GL_YCBCR_422_APPLE, GL_UNSIGNED_SHORT_8_8_APPLE, GL_RGB }
        }
    },
#endif
    {
        .cvpixfmt = kCVPixelFormatType_420YpCbCr8Planar,
        .planes = 3,
        .gl = {
            { OpenGL_RED, GL_UNSIGNED_BYTE, OpenGL_RED },
            { OpenGL_RED, GL_UNSIGNED_BYTE, OpenGL_RED },
            { OpenGL_RED, GL_UNSIGNED_BYTE, OpenGL_RED },
        }
    },
    {
        .cvpixfmt = kCVPixelFormatType_420YpCbCr8PlanarFullRange,
        .planes = 3,
        .gl = {
            { OpenGL_RED, GL_UNSIGNED_BYTE, OpenGL_RED },
            { OpenGL_RED, GL_UNSIGNED_BYTE, OpenGL_RED },
            { OpenGL_RED, GL_UNSIGNED_BYTE, OpenGL_RED },
        }
    },
    {
        .cvpixfmt = kCVPixelFormatType_32BGRA,
        .planes = 1,
        .gl = {
#if TARGET_OS_OSX
            { GL_BGRA, GL_UNSIGNED_INT_8_8_8_8_REV, GL_RGBA }
#else
            { GL_BGRA, GL_UNSIGNED_INT, GL_RGBA }
#endif
        }
    },
};

static struct vt_format *vt_get_gl_format(uint32_t cvpixfmt)
{
    for (int i = 0; i < MP_ARRAY_SIZE(vt_formats); i++) {
        if (vt_formats[i].cvpixfmt == cvpixfmt)
            return &vt_formats[i];
    }
    return NULL;
}

#if DEBUG
__unused static void printf_opengl_string(const char *name, GLenum s) {
    const char *v = (const char *) glGetString(s);
    NSLog(@"[OpenGL] %s = %s\n", name, v);
}
#define debug_opengl_string(name,s) printf_opengl_string(name,s)
#else
#define debug_opengl_string(name,s)
#endif


//https://developer.apple.com/library/archive/qa/qa1501/_index.html

static void PrintPixelFormatTypes()
{
    CFArrayRef pixelFormatDescriptionsArray =
    CVPixelFormatDescriptionArrayCreateWithAllPixelFormatTypes(kCFAllocatorDefault);

    printf("Core Video Supported Pixel Format Types:\n\n");

    for (CFIndex i = 0; i < CFArrayGetCount(pixelFormatDescriptionsArray); i++) {
        CFStringRef pixelFormat = NULL;
        CFNumberRef pixelFormatFourCC = (CFNumberRef)CFArrayGetValueAtIndex(pixelFormatDescriptionsArray, i);

        if (pixelFormatFourCC != NULL) {
            UInt32 value;

            CFNumberGetValue(pixelFormatFourCC, kCFNumberSInt32Type, &value);

            if (value <= 0x28) {
                pixelFormat = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("Core Video Pixel Format Type: %d"), value);
            } else {
                pixelFormat = CFStringCreateWithFormat(kCFAllocatorDefault, NULL, CFSTR("Core Video Pixel Format Type (FourCC):%c%c%c%c"), (char)(value >> 24), (char)(value >> 16), (char)(value >> 8), (char)value);
            }
            CFShow(pixelFormat);
            CFRelease(pixelFormat);
            
            CFDictionaryRef dicRef = CVPixelFormatDescriptionCreateWithPixelFormatType(NULL, value);
            if (dicRef) {
                CFShow(dicRef);
                CFRelease(dicRef);
            }
            printf("\n");
        }
    }
    
    printf("========================================\n");
    
    AVCaptureVideoDataOutput *videoOutput = [[AVCaptureVideoDataOutput alloc] init];

    NSDictionary *formats = [NSDictionary dictionaryWithObjectsAndKeys:
           @"kCVPixelFormatType_1Monochrome", [NSNumber numberWithInt:kCVPixelFormatType_1Monochrome],
           @"kCVPixelFormatType_2Indexed", [NSNumber numberWithInt:kCVPixelFormatType_2Indexed],
           @"kCVPixelFormatType_4Indexed", [NSNumber numberWithInt:kCVPixelFormatType_4Indexed],
           @"kCVPixelFormatType_8Indexed", [NSNumber numberWithInt:kCVPixelFormatType_8Indexed],
           @"kCVPixelFormatType_1IndexedGray_WhiteIsZero", [NSNumber numberWithInt:kCVPixelFormatType_1IndexedGray_WhiteIsZero],
           @"kCVPixelFormatType_2IndexedGray_WhiteIsZero", [NSNumber numberWithInt:kCVPixelFormatType_2IndexedGray_WhiteIsZero],
           @"kCVPixelFormatType_4IndexedGray_WhiteIsZero", [NSNumber numberWithInt:kCVPixelFormatType_4IndexedGray_WhiteIsZero],
           @"kCVPixelFormatType_8IndexedGray_WhiteIsZero", [NSNumber numberWithInt:kCVPixelFormatType_8IndexedGray_WhiteIsZero],
           @"kCVPixelFormatType_16BE555", [NSNumber numberWithInt:kCVPixelFormatType_16BE555],
           @"kCVPixelFormatType_16LE555", [NSNumber numberWithInt:kCVPixelFormatType_16LE555],
           @"kCVPixelFormatType_16LE5551", [NSNumber numberWithInt:kCVPixelFormatType_16LE5551],
           @"kCVPixelFormatType_16BE565", [NSNumber numberWithInt:kCVPixelFormatType_16BE565],
           @"kCVPixelFormatType_16LE565", [NSNumber numberWithInt:kCVPixelFormatType_16LE565],
           @"kCVPixelFormatType_24RGB", [NSNumber numberWithInt:kCVPixelFormatType_24RGB],
           @"kCVPixelFormatType_24BGR", [NSNumber numberWithInt:kCVPixelFormatType_24BGR],
           @"kCVPixelFormatType_32ARGB", [NSNumber numberWithInt:kCVPixelFormatType_32ARGB],
           @"kCVPixelFormatType_32BGRA", [NSNumber numberWithInt:kCVPixelFormatType_32BGRA],
           @"kCVPixelFormatType_32ABGR", [NSNumber numberWithInt:kCVPixelFormatType_32ABGR],
           @"kCVPixelFormatType_32RGBA", [NSNumber numberWithInt:kCVPixelFormatType_32RGBA],
           @"kCVPixelFormatType_64ARGB", [NSNumber numberWithInt:kCVPixelFormatType_64ARGB],
           @"kCVPixelFormatType_48RGB", [NSNumber numberWithInt:kCVPixelFormatType_48RGB],
           @"kCVPixelFormatType_32AlphaGray", [NSNumber numberWithInt:kCVPixelFormatType_32AlphaGray],
           @"kCVPixelFormatType_16Gray", [NSNumber numberWithInt:kCVPixelFormatType_16Gray],
           @"kCVPixelFormatType_422YpCbCr8", [NSNumber numberWithInt:kCVPixelFormatType_422YpCbCr8],
           @"kCVPixelFormatType_4444YpCbCrA8", [NSNumber numberWithInt:kCVPixelFormatType_4444YpCbCrA8],
           @"kCVPixelFormatType_4444YpCbCrA8R", [NSNumber numberWithInt:kCVPixelFormatType_4444YpCbCrA8R],
           @"kCVPixelFormatType_444YpCbCr8", [NSNumber numberWithInt:kCVPixelFormatType_444YpCbCr8],
           @"kCVPixelFormatType_422YpCbCr16", [NSNumber numberWithInt:kCVPixelFormatType_422YpCbCr16],
           @"kCVPixelFormatType_422YpCbCr10", [NSNumber numberWithInt:kCVPixelFormatType_422YpCbCr10],
           @"kCVPixelFormatType_444YpCbCr10", [NSNumber numberWithInt:kCVPixelFormatType_444YpCbCr10],
           @"kCVPixelFormatType_420YpCbCr8Planar", [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8Planar],
           @"kCVPixelFormatType_420YpCbCr8PlanarFullRange", [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8PlanarFullRange],
           @"kCVPixelFormatType_422YpCbCr_4A_8BiPlanar", [NSNumber numberWithInt:kCVPixelFormatType_422YpCbCr_4A_8BiPlanar],
           @"kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange", [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange],
           @"kCVPixelFormatType_420YpCbCr8BiPlanarFullRange", [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange],
           @"kCVPixelFormatType_422YpCbCr8_yuvs", [NSNumber numberWithInt:kCVPixelFormatType_422YpCbCr8_yuvs],
           @"kCVPixelFormatType_422YpCbCr8FullRange", [NSNumber numberWithInt:kCVPixelFormatType_422YpCbCr8FullRange],
        nil];

    printf("AVCapture VideoOutput Supported Pixel Format Types:\n\n");
    for (NSNumber *fmt in [videoOutput availableVideoCVPixelFormatTypes]) {
        assert([formats objectForKey:fmt]);
        printf("%s\n", [[formats objectForKey:fmt] UTF8String]);
    }
    
    printf("========================================\n");
}
#endif
