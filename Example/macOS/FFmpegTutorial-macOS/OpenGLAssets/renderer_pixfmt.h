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
#import <OpenGL/gl.h>
#import <OpenGL/gl3ext.h>

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
            { GL_RED, GL_UNSIGNED_BYTE, GL_RED },
            { GL_RG,  GL_UNSIGNED_BYTE, GL_RG } ,
//           330 后使用这个绿屏，when use LUMINANCE/LUMINANCE_ALPHA,the fsh must use r and ra!
//            { GL_LUMINANCE, GL_UNSIGNED_BYTE, GL_LUMINANCE },
//            { GL_LUMINANCE_ALPHA, GL_UNSIGNED_BYTE, GL_LUMINANCE_ALPHA }
        }
    },
    {
        .cvpixfmt = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
        .planes = 2,
        .gl = {
            { GL_RED, GL_UNSIGNED_BYTE, GL_RED },
            { GL_RG,  GL_UNSIGNED_BYTE, GL_RG } ,
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
        //https://people.freedesktop.org/~marcheu/extensions/APPLE/ycbcr_422.html
        .cvpixfmt = kCVPixelFormatType_422YpCbCr8_yuvs,
        .planes = 1,
        .gl = {
            { GL_YCBCR_422_APPLE, GL_UNSIGNED_SHORT_8_8_REV_APPLE, GL_RGB },
            //330
            { GL_RGB_422_APPLE, GL_UNSIGNED_SHORT_8_8_REV_APPLE, GL_RGB },
        }
    },
#if TARGET_OS_OSX
    {
        //UYVY422
        //https://people.freedesktop.org/~marcheu/extensions/APPLE/ycbcr_422.html
        //https://www.khronos.org/registry/OpenGL/extensions/APPLE/APPLE_rgb_422.txt
        .cvpixfmt = kCVPixelFormatType_422YpCbCr8,
        .planes = 1,
        .gl = {
            { GL_YCBCR_422_APPLE, GL_UNSIGNED_SHORT_8_8_APPLE, GL_RGB },
            //330
            { GL_RGB_422_APPLE, GL_UNSIGNED_SHORT_8_8_APPLE, GL_RGB },
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

static inline struct vt_format *vt_get_gl_format(uint32_t cvpixfmt)
{
    for (int i = 0; i < MP_ARRAY_SIZE(vt_formats); i++) {
        if (vt_formats[i].cvpixfmt == cvpixfmt)
            return &vt_formats[i];
    }
    return NULL;
}

static inline void printSupportedPixelFormats(bool showPrivate)
{
    // As of the 10.13 SDK
    NSDictionary * knownFormats = @{
      @(kCVPixelFormatType_1Monochrome):                   @"kCVPixelFormatType_1Monochrome",
      @(kCVPixelFormatType_2Indexed):                      @"kCVPixelFormatType_2Indexed",
      @(kCVPixelFormatType_4Indexed):                      @"kCVPixelFormatType_4Indexed",
      @(kCVPixelFormatType_8Indexed):                      @"kCVPixelFormatType_8Indexed",
      @(kCVPixelFormatType_1IndexedGray_WhiteIsZero):      @"kCVPixelFormatType_1IndexedGray_WhiteIsZero",
      @(kCVPixelFormatType_2IndexedGray_WhiteIsZero):      @"kCVPixelFormatType_2IndexedGray_WhiteIsZero",
      @(kCVPixelFormatType_4IndexedGray_WhiteIsZero):      @"kCVPixelFormatType_4IndexedGray_WhiteIsZero",
      @(kCVPixelFormatType_8IndexedGray_WhiteIsZero):      @"kCVPixelFormatType_8IndexedGray_WhiteIsZero",
      @(kCVPixelFormatType_16BE555):                       @"kCVPixelFormatType_16BE555",
      @(kCVPixelFormatType_16LE555):                       @"kCVPixelFormatType_16LE555",
      @(kCVPixelFormatType_16LE5551):                      @"kCVPixelFormatType_16LE5551",
      @(kCVPixelFormatType_16BE565):                       @"kCVPixelFormatType_16BE565",
      @(kCVPixelFormatType_16LE565):                       @"kCVPixelFormatType_16LE565",
      @(kCVPixelFormatType_24RGB):                         @"kCVPixelFormatType_24RGB",
      @(kCVPixelFormatType_24BGR):                         @"kCVPixelFormatType_24BGR",
      @(kCVPixelFormatType_32ARGB):                        @"kCVPixelFormatType_32ARGB",
      @(kCVPixelFormatType_32BGRA):                        @"kCVPixelFormatType_32BGRA",
      @(kCVPixelFormatType_32ABGR):                        @"kCVPixelFormatType_32ABGR",
      @(kCVPixelFormatType_32RGBA):                        @"kCVPixelFormatType_32RGBA",
      @(kCVPixelFormatType_64ARGB):                        @"kCVPixelFormatType_64ARGB",
      @(kCVPixelFormatType_48RGB):                         @"kCVPixelFormatType_48RGB",
      @(kCVPixelFormatType_32AlphaGray):                   @"kCVPixelFormatType_32AlphaGray",
      @(kCVPixelFormatType_16Gray):                        @"kCVPixelFormatType_16Gray",
      @(kCVPixelFormatType_30RGB):                         @"kCVPixelFormatType_30RGB",
      @(kCVPixelFormatType_422YpCbCr8):                    @"kCVPixelFormatType_422YpCbCr8",
      @(kCVPixelFormatType_4444YpCbCrA8):                  @"kCVPixelFormatType_4444YpCbCrA8",
      @(kCVPixelFormatType_4444YpCbCrA8R):                 @"kCVPixelFormatType_4444YpCbCrA8R",
      @(kCVPixelFormatType_4444AYpCbCr8):                  @"kCVPixelFormatType_4444AYpCbCr8",
      @(kCVPixelFormatType_4444AYpCbCr16):                 @"kCVPixelFormatType_4444AYpCbCr16",
      @(kCVPixelFormatType_444YpCbCr8):                    @"kCVPixelFormatType_444YpCbCr8",
      @(kCVPixelFormatType_422YpCbCr16):                   @"kCVPixelFormatType_422YpCbCr16",
      @(kCVPixelFormatType_422YpCbCr10):                   @"kCVPixelFormatType_422YpCbCr10",
      @(kCVPixelFormatType_444YpCbCr10):                   @"kCVPixelFormatType_444YpCbCr10",
      @(kCVPixelFormatType_420YpCbCr8Planar):              @"kCVPixelFormatType_420YpCbCr8Planar",
      @(kCVPixelFormatType_420YpCbCr8PlanarFullRange):     @"kCVPixelFormatType_420YpCbCr8PlanarFullRange",
      @(kCVPixelFormatType_422YpCbCr_4A_8BiPlanar):        @"kCVPixelFormatType_422YpCbCr_4A_8BiPlanar",
      @(kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange):  @"kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange",
      @(kCVPixelFormatType_420YpCbCr8BiPlanarFullRange):   @"kCVPixelFormatType_420YpCbCr8BiPlanarFullRange",
      @(kCVPixelFormatType_422YpCbCr8_yuvs):               @"kCVPixelFormatType_422YpCbCr8_yuvs",
      @(kCVPixelFormatType_422YpCbCr8FullRange):           @"kCVPixelFormatType_422YpCbCr8FullRange",
      @(kCVPixelFormatType_OneComponent8):                 @"kCVPixelFormatType_OneComponent8",
      @(kCVPixelFormatType_TwoComponent8):                 @"kCVPixelFormatType_TwoComponent8",
      @(kCVPixelFormatType_30RGBLEPackedWideGamut):        @"kCVPixelFormatType_30RGBLEPackedWideGamut",
      @(kCVPixelFormatType_ARGB2101010LEPacked):           @"kCVPixelFormatType_ARGB2101010LEPacked",
      @(kCVPixelFormatType_OneComponent16Half):            @"kCVPixelFormatType_OneComponent16Half",
      @(kCVPixelFormatType_OneComponent32Float):           @"kCVPixelFormatType_OneComponent32Float",
      @(kCVPixelFormatType_TwoComponent16Half):            @"kCVPixelFormatType_TwoComponent16Half",
      @(kCVPixelFormatType_TwoComponent32Float):           @"kCVPixelFormatType_TwoComponent32Float",
      @(kCVPixelFormatType_64RGBAHalf):                    @"kCVPixelFormatType_64RGBAHalf",
      @(kCVPixelFormatType_128RGBAFloat):                  @"kCVPixelFormatType_128RGBAFloat",
      @(kCVPixelFormatType_14Bayer_GRBG):                  @"kCVPixelFormatType_14Bayer_GRBG",
      @(kCVPixelFormatType_14Bayer_RGGB):                  @"kCVPixelFormatType_14Bayer_RGGB",
      @(kCVPixelFormatType_14Bayer_BGGR):                  @"kCVPixelFormatType_14Bayer_BGGR",
      @(kCVPixelFormatType_14Bayer_GBRG):                  @"kCVPixelFormatType_14Bayer_GBRG",
      @(kCVPixelFormatType_DisparityFloat16):              @"kCVPixelFormatType_DisparityFloat16",
      @(kCVPixelFormatType_DisparityFloat32):              @"kCVPixelFormatType_DisparityFloat32",
      @(kCVPixelFormatType_DepthFloat16):                  @"kCVPixelFormatType_DepthFloat16",
      @(kCVPixelFormatType_DepthFloat32):                  @"kCVPixelFormatType_DepthFloat32",
      @(kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange): @"kCVPixelFormatType_420YpCbCr10BiPlanarVideoRange",
      @(kCVPixelFormatType_422YpCbCr10BiPlanarVideoRange): @"kCVPixelFormatType_422YpCbCr10BiPlanarVideoRange",
      @(kCVPixelFormatType_444YpCbCr10BiPlanarVideoRange): @"kCVPixelFormatType_444YpCbCr10BiPlanarVideoRange",
      @(kCVPixelFormatType_420YpCbCr10BiPlanarFullRange):  @"kCVPixelFormatType_420YpCbCr10BiPlanarFullRange",
      @(kCVPixelFormatType_422YpCbCr10BiPlanarFullRange):  @"kCVPixelFormatType_422YpCbCr10BiPlanarFullRange",
      @(kCVPixelFormatType_444YpCbCr10BiPlanarFullRange):  @"kCVPixelFormatType_444YpCbCr10BiPlanarFullRange",
    };
    
    //https://developer.apple.com/library/archive/qa/qa1501/_index.html
    //    打印出来的格式，有的没有包含在 CVPixelBuffer.h 头文件里
    // https://stackoverflow.com/questions/27129698/creating-an-rgb-cvopenglestexture-in-ios
       
    CFArrayRef pixelFormatDescriptionsArray = NULL;
    CFIndex i;

    pixelFormatDescriptionsArray = CVPixelFormatDescriptionArrayCreateWithAllPixelFormatTypes(kCFAllocatorDefault);

    printf("Core Video Supported IOSurfaceOpenGLTextureCompatibility Pixel Format Types:\n\n");

    for (i = 0; i < CFArrayGetCount(pixelFormatDescriptionsArray); i++) {
        CFNumberRef pixelFormatFourCC = (CFNumberRef)CFArrayGetValueAtIndex(pixelFormatDescriptionsArray, i);

        if (pixelFormatFourCC != NULL) {
            UInt32 value;
            CFNumberGetValue(pixelFormatFourCC, kCFNumberSInt32Type, &value);
            
            NSString * name = [knownFormats objectForKey:@(value)];
            CFStringRef pixelFormat = NULL;
            if (name) {
                pixelFormat = CFStringCreateWithFormat(kCFAllocatorDefault, NULL,
                                                       CFSTR("%s\n"), name.UTF8String);
            } else if (showPrivate) {
                if (value <= 0x28) {
                    pixelFormat = CFStringCreateWithFormat(kCFAllocatorDefault, NULL,
                                                           CFSTR("Unnamed Format: %d\n"), value);
                } else {
                    pixelFormat = CFStringCreateWithFormat(kCFAllocatorDefault, NULL,
                                                           CFSTR("Unnamed Format: '%c%c%c%c'\n"), (char)(value >> 24), (char)(value >> 16),
                                                           (char)(value >> 8), (char)value);
                }
            } else {
                continue;
            }
            CFDictionaryRef dicRef = CVPixelFormatDescriptionCreateWithPixelFormatType(NULL, value);
            if (dicRef) {
                if (CFDictionaryContainsKey(dicRef, CFSTR("IOSurfaceOpenGLTextureCompatibility"))) {
                    CFBooleanRef supportIOSurface = CFDictionaryGetValue(dicRef, CFSTR("IOSurfaceOpenGLTextureCompatibility"));
                    if (CFBooleanGetValue(supportIOSurface)) {
                        CFShow(pixelFormat);
                        CFShow(dicRef);
                        printf("\n");
                    }
                }
                CFRelease(dicRef);
            }
            CFRelease(pixelFormat);
        }
    }
    
    printf("========================================\n");
    
    AVCaptureVideoDataOutput *videoOutput = [[AVCaptureVideoDataOutput alloc] init];

    printf("AVCapture VideoOutput Supported Pixel Format Types:\n\n");
    for (NSNumber *fmt in [videoOutput availableVideoCVPixelFormatTypes]) {
        assert([knownFormats objectForKey:fmt]);
        printf("%s\n", [[knownFormats objectForKey:fmt] UTF8String]);
    }
    
    printf("========================================\n");
}
#endif
