//
//  FFPlayerHeader.h
//  FFmpegTutorial
//
//  Created by Matt Reach on 2020/4/27.
//

#ifndef FFPlayerHeader_h
#define FFPlayerHeader_h

typedef enum : NSUInteger {
    FFPlayerErrorCode_AllocFmtCtxFailed,///创建 avformat context 失败
    FFPlayerErrorCode_OpenFileFailed,///文件打开失败
    FFPlayerErrorCode_StreamNotFound,///找不到音视频流
    FFPlayerErrorCode_StreamOpenFailed,///音视频流打开失败
} FFPlayerErrorCode;

typedef enum : NSUInteger {
    MR_PIX_FMT_NONE = 0,
    MR_PIX_FMT_YUV420P,     ///< planar YUV 4:2:0, 12bpp, (1 Cr & Cb sample per 2x2 Y samples)
    MR_PIX_FMT_NV12,        ///< planar YUV 4:2:0, 12bpp, 1 plane for Y and 1 plane for the UV components, which are in leaved (first byte U and the following byte V)
    MR_PIX_FMT_NV21,        ///< like NV12, but U and V bytes are swapped
    MR_PIX_FMT_RGB24,       ///< packed RGB 8:8:8, 24bpp, RGBRGB...
    MR_PIX_FMT_0RGB,        ///< packed RGB 8:8:8, 32bpp, XRGBXRGB...   X=unused/undefined
    MR_PIX_FMT_RGB0,        ///< packed RGB 8:8:8, 32bpp, RGBXRGBX...   X=unused/undefined
    MR_PIX_FMT_RGBA,        ///< packed RGBA 8:8:8:8, 32bpp, RGBARGBA...
    MR_PIX_FMT_ARGB,        ///< packed ARGB 8:8:8:8, 32bpp, ARGBARGB...
    MR_PIX_FMT_RGB555BE,    ///< packed RGB 5:5:5, 16bpp, (msb)1X 5R 5G 5B(lsb), big-endian   , X=unused/undefined
    MR_PIX_FMT_RGB555LE     ///< packed RGB 5:5:5, 16bpp, (msb)1X 5R 5G 5B(lsb), little-endian, X=unused/undefined
    MR_PIX_FMT_EOF
} MRPixelFormat;

static int MR_PIX_FMT_BEGIN = MR_PIX_FMT_NONE + 1;
static int MR_PIX_FMT_END = MR_PIX_FMT_EOF - 1;

typedef NS_OPTIONS(NSUInteger, MRPixelFormatMask) {
    MR_PIX_FMT_MASK_NONE    = MR_PIX_FMT_NONE,
    MR_PIX_FMT_MASK_YUV420P = 1 << MR_PIX_FMT_YUV420P,    ///< planar YUV 4:2:0, 12bpp, (1 Cr & Cb sample per 2x2 Y samples)
    MR_PIX_FMT_MASK_NV12    = 1 << MR_PIX_FMT_NV12,    ///< planar YUV 4:2:0, 12bpp, 1 plane for Y and 1 plane for the UV components, which are in leaved (first byte U and the following byte V)
    MR_PIX_FMT_MASK_NV21    = 1 << MR_PIX_FMT_NV21,    ///< like NV12, but U and V bytes are swapped
    MR_PIX_FMT_MASK_RGB24   = 1 << MR_PIX_FMT_RGB24,   ///< packed RGB 8:8:8, 24bpp, RGBRGB...
    MR_PIX_FMT_MASK_0RGB    = 1 << MR_PIX_FMT_0RGB,        ///< packed RGB 8:8:8, 32bpp, XRGBXRGB...   X=unused/undefined
    MR_PIX_FMT_MASK_RGB0    = 1 << MR_PIX_FMT_RGB0,        ///< packed RGB 8:8:8, 32bpp, RGBXRGBX...   X=unused/undefined
    MR_PIX_FMT_MASK_RGBA    = 1 << MR_PIX_FMT_RGBA,     ///< packed RGBA 8:8:8:8, 32bpp, RGBARGBA...
    MR_PIX_FMT_MASK_ARGB    = 1 << MR_PIX_FMT_ARGB,        ///< packed ARGB 8:8:8:8, 32bpp, ARGBARGB...
    MR_PIX_FMT_MASK_RGB555BE= 1 << MR_PIX_FMT_RGB555BE,    ///< packed RGB 5:5:5, 16bpp, (msb)1X 5R 5G 5B(lsb), big-endian   , X=unused/undefined
    MR_PIX_FMT_MASK_RGB555LE= 1 << MR_PIX_FMT_RGB555LE     ///< packed RGB 5:5:5, 16bpp, (msb)1X 5R 5G 5B(lsb), little-endian, X=unused/undefined
};

/// safe usleep
static inline void mr_usleep(long s) {
    //mr_usleep is uint32 type!
    if (s >= 0) {
        usleep((useconds_t)s);
    }
}

/// safe sleep
static inline void mr_sleep(long s) {
    //sleep is unsigned int type!
    if (s >= 0) {
        sleep((unsigned int)s);
    }
}

#endif /* FFPlayerHeader_h */
