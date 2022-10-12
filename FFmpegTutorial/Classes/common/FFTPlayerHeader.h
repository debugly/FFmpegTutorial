//
//  FFTPlayerHeader.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/7/27.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#ifndef FFTPlayerHeader_h
#define FFTPlayerHeader_h

#import <Foundation/Foundation.h>
#import <stdbool.h>
#import <unistd.h>

#define PRINT_DEALLOC_ON 1
#if PRINT_DEALLOC_ON
    #define PRINT_DEALLOC \
        do{ \
            NSLog(@"%@ dealloc",NSStringFromClass([self class])); \
        }while(0)
#else
    #define PRINT_DEALLOC \
        do{ \
        }while(0)
#endif

#ifndef __MRWS__
#define __MRWS__

#ifndef __weakSelf__
#define __weakSelf__  __weak    typeof(self)weakSelf = self;
#endif

#ifndef __strongSelf__
#define __strongSelf__ __strong typeof(weakSelf)self = weakSelf;
#endif

#define __weakObj(obj)   __weak   typeof(obj)weak##obj = obj;
#define __strongObj(obj) __strong typeof(weak##obj)obj = weak##obj;

#endif

/* no AV sync correction is done if below the minimum AV sync threshold */
#define AV_SYNC_THRESHOLD_MIN 0.04
/* AV sync correction is done if above the maximum AV sync threshold */
#define AV_SYNC_THRESHOLD_MAX 0.1
/* If a frame duration is longer than this, it will not be duplicated to compensate AV sync */
#define AV_SYNC_FRAMEDUP_THRESHOLD 0.1
/* no AV correction is done if too big error */
#define AV_NOSYNC_THRESHOLD 10.0
/* polls for possible required screen refresh at least this often, should be less than 1/fps */
#define REFRESH_RATE 0.01

typedef enum FFPlayerErrorCode{
    FFPlayerErrorCode_AllocFmtCtxFailed,        //创建 avformat context 失败
    FFPlayerErrorCode_OpenFileFailed,           //文件打开失败
    FFPlayerErrorCode_StreamNotFound,           //找不到音视频流
    FFPlayerErrorCode_StreamOpenFailed,         //音视频流打开失败
    FFPlayerErrorCode_AudioDecoderOpenFailed,   //音频解码器打开失败
    FFPlayerErrorCode_VideoDecoderOpenFailed,   //视频解码器打开失败
    FFPlayerErrorCode_RescaleFrameFailed,       //视频帧重转失败
    FFPlayerErrorCode_ResampleFrameFailed,      //音频帧格式重采样失败
} FFPlayerErrorCode;

typedef enum MRPixelFormat{
    MR_PIX_FMT_NONE = 0,
    MR_PIX_FMT_YUV420P,     // planar YUV 4:2:0, 12bpp, (1 Cr & Cb sample per 2x2 Y samples)
    MR_PIX_FMT_NV12,        // semi-planar YUV 4:2:0, 12bpp, 1 plane for Y and 1 plane for the UV components, which are in leaved (first byte U and the following byte V)
    MR_PIX_FMT_NV21,        // like NV12, but U and V bytes are swapped
    MR_PIX_FMT_NV16,        // semi-planar YUV 4:2:2, 16bpp, (1 Cr & Cb sample per 2x1 Y samples interleaved chroma)
    MR_PIX_FMT_UYVY422,     // packed YUV 4:2:2, 16bpp, Cb Y0 Cr Y1
    MR_PIX_FMT_YUV444P10,   // planar YUV 4:4:4, 30bpp, (1 Cr & Cb sample per 1x1 Y samples)
    MR_PIX_FMT_YUYV422,     // packed YUV 4:2:2, 16bpp, Y0 Cb Y1 Cr
    MR_PIX_FMT_RGB24,       // packed RGB 8:8:8, 24bpp, RGBRGB...
    MR_PIX_FMT_0RGB,        // packed RGB 8:8:8, 32bpp, XRGBXRGB...   X=unused/undefined
    MR_PIX_FMT_RGB0,        // packed RGB 8:8:8, 32bpp, RGBXRGBX...   X=unused/undefined
    MR_PIX_FMT_RGBA,        // packed RGBA 8:8:8:8, 32bpp, RGBARGBA...
    MR_PIX_FMT_ARGB,        // packed ARGB 8:8:8:8, 32bpp, ARGBARGB...
    MR_PIX_FMT_RGB555BE,    // packed RGB 5:5:5, 16bpp, (msb)1X 5R 5G 5B(lsb), big-endian   , X=unused/undefined
    MR_PIX_FMT_RGB555LE,    // packed RGB 5:5:5, 16bpp, (msb)1X 5R 5G 5B(lsb), little-endian, X=unused/undefined
    MR_PIX_FMT_BGR0,        // packed BGR 8:8:8, 32bpp, BGRXBGRX...   X=unused/undefined
    MR_PIX_FMT_BGRA,        // packed BGRA 8:8:8:8, 32bpp, BGRABGRA...
    MR_PIX_FMT_ABGR,        // packed ABGR 8:8:8:8, 32bpp, ABGRABGR...
    MR_PIX_FMT_0BGR,        // packed BGR 8:8:8, 32bpp, XBGRXBGR...   X=unused/undefined
    MR_PIX_FMT_BGR24,       // packed RGB 8:8:8, 24bpp, BGRBGR...
    MR_PIX_FMT_EOF
} MRPixelFormat;

static int MR_PIX_FMT_BEGIN = MR_PIX_FMT_NONE + 1;
static int MR_PIX_FMT_END   = MR_PIX_FMT_EOF  - 1;

typedef enum MRPixelFormatMask{
    MR_PIX_FMT_MASK_NONE    = MR_PIX_FMT_NONE,
    MR_PIX_FMT_MASK_YUV420P = 1 << MR_PIX_FMT_YUV420P,    // planar YUV 4:2:0, 12bpp, (1 Cr & Cb sample per 2x2 Y samples)
    MR_PIX_FMT_MASK_NV12    = 1 << MR_PIX_FMT_NV12,       // planar YUV 4:2:0, 12bpp, 1 plane for Y and 1 plane for the UV components, which are in leaved (first byte U and the following byte V)
    MR_PIX_FMT_MASK_NV21    = 1 << MR_PIX_FMT_NV21,       // like NV12, but U and V bytes are swapped
    MR_PIX_FMT_MASK_NV16    = 1 << MR_PIX_FMT_NV16,       // semi-planar YUV 4:2:2, 16bpp, (1 Cr & Cb sample per 2x1 Y samples interleaved chroma)
    MR_PIX_FMT_MASK_UYVY422 = 1 << MR_PIX_FMT_UYVY422,    // packed YUV 4:2:2, 16bpp, Cb Y0 Cr Y1
    MR_PIX_FMT_MASK_YUV444P10 = 1 << MR_PIX_FMT_YUV444P10,// planar YUV 4:4:4, 30bpp, (1 Cr & Cb sample per 1x1 Y samples)
    MR_PIX_FMT_MASK_YUYV422 = 1 << MR_PIX_FMT_YUYV422,     // packed YUV 4:2:2, 16bpp, Y0 Cb Y1 Cr
    MR_PIX_FMT_MASK_RGB24   = 1 << MR_PIX_FMT_RGB24,      // packed RGB 8:8:8, 24bpp, RGBRGB...
    MR_PIX_FMT_MASK_0RGB    = 1 << MR_PIX_FMT_0RGB,       // packed RGB 8:8:8, 32bpp, XRGBXRGB...   X=unused/undefined
    MR_PIX_FMT_MASK_RGB0    = 1 << MR_PIX_FMT_RGB0,       // packed RGB 8:8:8, 32bpp, RGBXRGBX...   X=unused/undefined
    MR_PIX_FMT_MASK_RGBA    = 1 << MR_PIX_FMT_RGBA,       // packed RGBA 8:8:8:8, 32bpp, RGBARGBA...
    MR_PIX_FMT_MASK_ARGB    = 1 << MR_PIX_FMT_ARGB,       // packed ARGB 8:8:8:8, 32bpp, ARGBARGB...
    MR_PIX_FMT_MASK_RGB555BE= 1 << MR_PIX_FMT_RGB555BE,   // packed RGB 5:5:5, 16bpp, (msb)1X 5R 5G 5B(lsb), big-endian   , X=unused/undefined
    MR_PIX_FMT_MASK_RGB555LE= 1 << MR_PIX_FMT_RGB555LE,   // packed RGB 5:5:5, 16bpp, (msb)1X 5R 5G 5B(lsb), little-endian, X=unused/undefined
    MR_PIX_FMT_MASK_BGR0    = 1 << MR_PIX_FMT_BGR0,       // packed BGR 8:8:8, 32bpp, BGRXBGRX...   X=unused/undefined
    MR_PIX_FMT_MASK_BGRA    = 1 << MR_PIX_FMT_BGRA,       // packed BGRA 8:8:8:8, 32bpp, BGRABGRA...
    MR_PIX_FMT_MASK_ABGR    = 1 << MR_PIX_FMT_ABGR,       // packed ABGR 8:8:8:8, 32bpp, ABGRABGR...
    MR_PIX_FMT_MASK_0BGR    = 1 << MR_PIX_FMT_0BGR,       // packed BGR 8:8:8, 32bpp, XBGRXBGR...   X=unused/undefined
    MR_PIX_FMT_MASK_BGR24   = 1 << MR_PIX_FMT_BGR24,      // packed RGB 8:8:8, 24bpp, BGRBGR...
}MRPixelFormatMask;

typedef enum MRSampleFormat{
    MR_SAMPLE_FMT_NONE ,
    MR_SAMPLE_FMT_S16  ,    // signed 16 bits
    MR_SAMPLE_FMT_FLT  ,    // float
    MR_SAMPLE_FMT_S16P ,    // signed 16 bits, planar
    MR_SAMPLE_FMT_FLTP ,    // float, planar
    MR_SAMPLE_FMT_EOF
}MRSampleFormat;

static int MR_SAMPLE_FMT_BEGIN = MR_SAMPLE_FMT_NONE + 1;
static int MR_SAMPLE_FMT_END   = MR_SAMPLE_FMT_EOF  - 1;

typedef enum MRSampleFormatMask{
    MR_SAMPLE_FMT_MASK_NONE = 1 << MR_SAMPLE_FMT_NONE,
    MR_SAMPLE_FMT_MASK_S16  = 1 << MR_SAMPLE_FMT_S16,    // signed 16 bits
    MR_SAMPLE_FMT_MASK_FLT  = 1 << MR_SAMPLE_FMT_FLT,    // float
    MR_SAMPLE_FMT_MASK_S16P = 1 << MR_SAMPLE_FMT_S16P,   // signed 16 bits, planar
    MR_SAMPLE_FMT_MASK_FLTP = 1 << MR_SAMPLE_FMT_FLTP,   // float, planar
    MR_SAMPLE_FMT_MASK_AUTO = MR_SAMPLE_FMT_MASK_S16 + MR_SAMPLE_FMT_MASK_FLT + MR_SAMPLE_FMT_MASK_S16P + MR_SAMPLE_FMT_MASK_FLTP// auto select best match fmt
}MRSampleFormatMask;

enum AVSampleFormat MRSampleFormat2AV (MRSampleFormat mrsf);
MRSampleFormat AVSampleFormat2MR (enum AVSampleFormat avsf);

enum AVPixelFormat MRPixelFormat2AV (MRPixelFormat mrpf);
MRPixelFormat AVPixelFormat2MR (enum AVPixelFormat avpf);

static inline bool MR_Sample_Fmt_Is_Packet(MRSampleFormat fmt){
    if (fmt == MR_SAMPLE_FMT_S16 || fmt == MR_SAMPLE_FMT_FLT) {
        return true;
    } else {
        return false;
    }
}

static inline bool MR_Sample_Fmt_Is_Planar(MRSampleFormat fmt){
    if (fmt == MR_SAMPLE_FMT_S16P || fmt == MR_SAMPLE_FMT_FLTP) {
        return true;
    } else {
        return false;
    }
}

static inline bool MR_Sample_Fmt_Is_FloatX(MRSampleFormat fmt){
    if (fmt == MR_SAMPLE_FMT_FLT || fmt == MR_SAMPLE_FMT_FLTP) {
        return true;
    } else {
        return false;
    }
}

static inline bool MR_Sample_Fmt_Is_S16X(MRSampleFormat fmt){
    if (fmt == MR_SAMPLE_FMT_S16 || fmt == MR_SAMPLE_FMT_S16P) {
        return true;
    } else {
        return false;
    }
}

typedef enum MRColorRange {
    MRCOL_RANGE_UNSPECIFIED = 0,
    MRCOL_RANGE_MPEG        = 1, // the normal 219*2^(n-8) "MPEG" YUV ranges
    MRCOL_RANGE_JPEG        = 2, // the normal     2^n-1   "JPEG" YUV ranges
    MRCOL_RANGE_NB               // Not part of ABI
}MRColorRange;

// safe sleep us
static inline void mr_usleep(long s) {
    //mr_usleep is uint32 type!
    if (s >= 0) {
        usleep((useconds_t)s);
    }
}

// safe sleep ms
static inline void mr_msleep(long s) {
    //mr_usleep is uint32 type!
    mr_usleep(s * 1000);
}

// safe sleep s
static inline void mr_sleep(long s) {
    //sleep is unsigned int type!
    if (s > 0) {
        sleep((unsigned int)s);
    } else {
#if DEBUG
        assert(s != 0);
#endif
    }
}

typedef struct _MR_PACKET_SIZE
{
    int video_pkt_size;
    int audio_pkt_size;
    int other_pkt_size;
}MR_PACKET_SIZE;

static inline int mr_packet_size_equal(MR_PACKET_SIZE s1,MR_PACKET_SIZE s2) {
    return s1.video_pkt_size - s2.video_pkt_size
    + s1.audio_pkt_size - s2.audio_pkt_size
    + s1.other_pkt_size - s2.other_pkt_size;
}

static inline int mr_packet_size_equal_zero(MR_PACKET_SIZE s1) {
    return s1.video_pkt_size == 0
    && s1.audio_pkt_size == 0
    && s1.other_pkt_size == 0;
}

static __inline__ NSError * _make_nserror(int code)
{
    return [NSError errorWithDomain:@"com.debugly.fftutorial" code:(NSInteger)code userInfo:nil];
}

static __inline__ NSError * _make_nserror_desc(int code,NSString *desc)
{
    if (!desc || desc.length == 0) {
        desc = @"";
    }
    
    return [NSError errorWithDomain:@"com.debugly.fftutorial" code:(NSInteger)code userInfo:@{
        NSLocalizedDescriptionKey:desc
    }];
}


const char * av_pixel_fmt_to_string(int fmt);
const char * av_sample_fmt_to_string(int format);

typedef struct AVFrame AVFrame;
int audio_buffer_size(AVFrame *frame);

#endif /* FFTPlayerHeader_h */
