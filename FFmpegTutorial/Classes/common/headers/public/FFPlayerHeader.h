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
    MR_PIX_FMT_NONE    = 0,
    MR_PIX_FMT_YUV420P = 1,    ///< planar YUV 4:2:0, 12bpp, (1 Cr & Cb sample per 2x2 Y samples)
    MR_PIX_FMT_NV12    = 2,    ///< planar YUV 4:2:0, 12bpp, 1 plane for Y and 1 plane for the UV components, which are in leaved (first byte U and the following byte V)
    MR_PIX_FMT_NV21    = 3,    ///< like NV12, but U and V bytes are swapped
    MR_PIX_FMT_RGB24   = 4,    ///< packed RGB 8:8:8, 24bpp, RGBRGB...
    MR_PIX_FMT_RGBA    = 5     ///< packed RGBA 8:8:8:8, 32bpp, RGBARGBA...
} MRPixelFormat;

typedef NS_OPTIONS(NSUInteger, MRPixelFormatMask) {
    MR_PIX_FMT_MASK_NONE    = MR_PIX_FMT_NONE,
    MR_PIX_FMT_MASK_YUV420P = 1 << MR_PIX_FMT_YUV420P,    ///< planar YUV 4:2:0, 12bpp, (1 Cr & Cb sample per 2x2 Y samples)
    MR_PIX_FMT_MASK_NV12    = 1 << MR_PIX_FMT_NV12,    ///< planar YUV 4:2:0, 12bpp, 1 plane for Y and 1 plane for the UV components, which are in leaved (first byte U and the following byte V)
    MR_PIX_FMT_MASK_NV21    = 1 << MR_PIX_FMT_NV21,    ///< like NV12, but U and V bytes are swapped
    MR_PIX_FMT_MASK_RGB24   = 1 << MR_PIX_FMT_RGB24,   ///< packed RGB 8:8:8, 24bpp, RGBRGB...
    MR_PIX_FMT_MASK_RGBA    = 1 << MR_PIX_FMT_RGBA     ///< packed RGBA 8:8:8:8, 32bpp, RGBARGBA...
};

#endif /* FFPlayerHeader_h */
