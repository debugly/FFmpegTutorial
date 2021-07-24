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

#ifndef IJKSDL__renderer_pixfmt__INTERNAL__H
#define IJKSDL__renderer_pixfmt__INTERNAL__H

#if TARGET_OS_OSX
    #define OpenGLTextureCacheRef   CVOpenGLTextureCacheRef
    #define OpenGLTextureRef        CVOpenGLTextureRef
    #define OpenGLTextureCacheFlush CVOpenGLTextureCacheFlush
    #define OpenGLTextureGetTarget  CVOpenGLTextureGetTarget
    #define OpenGLTextureGetName    CVOpenGLTextureGetName
    #define OpenGL_RED_EXT          GL_RED
    #define OpenGL_RG_EXT           GL_RG
#else
    #define OpenGLTextureCacheRef   CVOpenGLESTextureCacheRef
    #define OpenGLTextureRef        CVOpenGLESTextureRef
    #define OpenGLTextureCacheFlush CVOpenGLESTextureCacheFlush
    #define OpenGLTextureGetTarget  CVOpenGLESTextureGetTarget
    #define OpenGLTextureGetName    CVOpenGLESTextureGetName
    #define OpenGL_RED_EXT          GL_RED_EXT
    #define OpenGL_RG_EXT           GL_RG_EXT
#endif

enum mp_imgfmt {
    IMGFMT_NONE = 0,

    // Offset to make confusing with ffmpeg formats harder
    IMGFMT_START = 1000,

    // Planar YUV formats
    IMGFMT_444P,                // 1x1
    IMGFMT_420P,                // 2x2

    // Gray
    IMGFMT_Y8,
    IMGFMT_Y16,

    // Packed YUV formats (components are byte-accessed)
    IMGFMT_UYVY,                // U  Y0 V  Y1

    // Y plane + packed plane for chroma
    IMGFMT_NV12,

    // Like IMGFMT_NV12, but with 10 bits per component (and 6 bits of padding)
    IMGFMT_P010,

    // Like IMGFMT_NV12, but for 4:4:4
    IMGFMT_NV24,

    // RGB/BGR Formats

    // Byte accessed (low address to high address)
    IMGFMT_ARGB,
    IMGFMT_BGRA,
    IMGFMT_ABGR,
    IMGFMT_RGBA,
    IMGFMT_BGR24,               // 3 bytes per pixel
    IMGFMT_RGB24,

    // Like e.g. IMGFMT_ARGB, but has a padding byte instead of alpha
    IMGFMT_0RGB,
    IMGFMT_BGR0,
    IMGFMT_0BGR,
    IMGFMT_RGB0,

    IMGFMT_RGB0_START = IMGFMT_0RGB,
    IMGFMT_RGB0_END = IMGFMT_RGB0,

    // Like IMGFMT_RGBA, but 2 bytes per component.
    IMGFMT_RGBA64,

    // Accessed with bit-shifts after endian-swapping the uint16_t pixel
    IMGFMT_RGB565,              // 5r 6g 5b (MSB to LSB)

    // Hardware accelerated formats. Plane data points to special data
    // structures, instead of pixel data.
    IMGFMT_VDPAU,           // VdpVideoSurface
    IMGFMT_VDPAU_OUTPUT,    // VdpOutputSurface
    IMGFMT_VAAPI,
    // plane 0: ID3D11Texture2D
    // plane 1: slice index casted to pointer
    IMGFMT_D3D11,
    IMGFMT_DXVA2,           // IDirect3DSurface9 (NV12/P010/P016)
    IMGFMT_MMAL,            // MMAL_BUFFER_HEADER_T
    IMGFMT_VIDEOTOOLBOX,    // CVPixelBufferRef
    IMGFMT_MEDIACODEC,      // AVMediaCodecBuffer
    IMGFMT_DRMPRIME,        // AVDRMFrameDescriptor
    IMGFMT_CUDA,            // CUDA Buffer

    // Generic pass-through of AV_PIX_FMT_*. Used for formats which don't have
    // a corresponding IMGFMT_ value.
    IMGFMT_AVPIXFMT_START,
    IMGFMT_AVPIXFMT_END = IMGFMT_AVPIXFMT_START + 500,

    IMGFMT_END
};

#define MP_MAX_PLANES 4
#define MP_ARRAY_SIZE(s) (sizeof(s) / sizeof((s)[0]))

struct vt_gl_plane_format {
    GLenum gl_format;
    GLenum gl_type;
    GLenum gl_internal_format;
};

struct vt_format {
    uint32_t cvpixfmt;
    int imgfmt;
    int planes;
    struct vt_gl_plane_format gl[MP_MAX_PLANES];
};

static struct vt_format vt_formats[] = {
    {
        .cvpixfmt = kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange,
        .imgfmt = IMGFMT_NV12,
        .planes = 2,
        .gl = {
//           when use RED/RG,the fsh must use r and rg!
//            { GL_RED, GL_UNSIGNED_BYTE, GL_R8 },
//            { GL_RG,  GL_UNSIGNED_BYTE, GL_RG8 } ,
//            { GL_RED, GL_UNSIGNED_BYTE, GL_RED },
//            { GL_RG,  GL_UNSIGNED_BYTE, GL_RG } ,
//           when use LUMINANCE/LUMINANCE_ALPHA,the fsh must use r and ra!
            { GL_LUMINANCE, GL_UNSIGNED_BYTE, GL_LUMINANCE },
            { GL_LUMINANCE_ALPHA,  GL_UNSIGNED_BYTE, GL_LUMINANCE_ALPHA }
        }
    },
    {
        .cvpixfmt = kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
        .imgfmt = IMGFMT_NV12,
        .planes = 2,
        .gl = {
            { GL_LUMINANCE, GL_UNSIGNED_BYTE, GL_LUMINANCE },
            { GL_LUMINANCE_ALPHA,  GL_UNSIGNED_BYTE, GL_LUMINANCE_ALPHA }
        }
    },
#if TARGET_OS_OSX
    {
        .cvpixfmt = kCVPixelFormatType_422YpCbCr8,
        .imgfmt = IMGFMT_UYVY,
        .planes = 1,
        .gl = {
            { GL_YCBCR_422_APPLE, GL_UNSIGNED_SHORT_8_8_APPLE, GL_RGB }
        }
    },
#endif
    {
        .cvpixfmt = kCVPixelFormatType_420YpCbCr8Planar,
        .imgfmt = IMGFMT_420P,
        .planes = 3,
        .gl = {
#if TARGET_OS_OSX
            { GL_RED, GL_UNSIGNED_BYTE, GL_RED },
            { GL_RED, GL_UNSIGNED_BYTE, GL_RED },
            { GL_RED, GL_UNSIGNED_BYTE, GL_RED }
#else
            { GL_RED_EXT, GL_UNSIGNED_BYTE, GL_RED_EXT },
            { GL_RED_EXT, GL_UNSIGNED_BYTE, GL_RED_EXT },
            { GL_RED_EXT, GL_UNSIGNED_BYTE, GL_RED_EXT }
#endif
        }
    },
    {
        .cvpixfmt = kCVPixelFormatType_32BGRA,
        .imgfmt = IMGFMT_BGR0,
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

#endif
