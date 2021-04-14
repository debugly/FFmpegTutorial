//
//  FFPlayerHeader.h
//  FFmpegTutorial
//
//  Created by Matt Reach on 2020/4/27.
//

#ifndef FFPlayerHeader_h
#define FFPlayerHeader_h

typedef enum : NSUInteger {
    FFPlayerErrorCode_AllocFmtCtxFailed,    //创建 avformat context 失败
    FFPlayerErrorCode_OpenFileFailed,       //文件打开失败
    FFPlayerErrorCode_StreamNotFound,       //找不到音视频流
    FFPlayerErrorCode_StreamOpenFailed,     //音视频流打开失败
    FFPlayerErrorCode_RescaleFrameFailed,   //视频帧重转失败
    FFPlayerErrorCode_ResampleFrameFailed,  //音频帧格式重采样失败
} FFPlayerErrorCode;

typedef enum : NSUInteger {
    MR_PIX_FMT_NONE = 0,
    MR_PIX_FMT_YUV420P,     // planar YUV 4:2:0, 12bpp, (1 Cr & Cb sample per 2x2 Y samples)
    MR_PIX_FMT_NV12,        // planar YUV 4:2:0, 12bpp, 1 plane for Y and 1 plane for the UV components, which are in leaved (first byte U and the following byte V)
    MR_PIX_FMT_NV21,        // like NV12, but U and V bytes are swapped
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

typedef NS_OPTIONS(NSUInteger, MRPixelFormatMask) {
    MR_PIX_FMT_MASK_NONE    = MR_PIX_FMT_NONE,
    MR_PIX_FMT_MASK_YUV420P = 1 << MR_PIX_FMT_YUV420P,    // planar YUV 4:2:0, 12bpp, (1 Cr & Cb sample per 2x2 Y samples)
    MR_PIX_FMT_MASK_NV12    = 1 << MR_PIX_FMT_NV12,       // planar YUV 4:2:0, 12bpp, 1 plane for Y and 1 plane for the UV components, which are in leaved (first byte U and the following byte V)
    MR_PIX_FMT_MASK_NV21    = 1 << MR_PIX_FMT_NV21,       // like NV12, but U and V bytes are swapped
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
};

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

typedef NS_OPTIONS(NSUInteger, MRSampleFormatMask) {
    MR_SAMPLE_FMT_MASK_NONE = 1 << MR_SAMPLE_FMT_NONE,
    MR_SAMPLE_FMT_MASK_S16  = 1 << MR_SAMPLE_FMT_S16,    // signed 16 bits
    MR_SAMPLE_FMT_MASK_FLT  = 1 << MR_SAMPLE_FMT_FLT,    // float
    MR_SAMPLE_FMT_MASK_S16P = 1 << MR_SAMPLE_FMT_S16P,   // signed 16 bits, planar
    MR_SAMPLE_FMT_MASK_FLTP = 1 << MR_SAMPLE_FMT_FLTP,   // float, planar
    MR_SAMPLE_FMT_MASK_AUTO = MR_SAMPLE_FMT_MASK_S16 + MR_SAMPLE_FMT_MASK_FLT + MR_SAMPLE_FMT_MASK_S16P + MR_SAMPLE_FMT_MASK_FLTP// auto select best match fmt
};


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

static inline void MR_sync_main_queue(dispatch_block_t block){
    assert(block);
    if (strcmp(dispatch_queue_get_label(DISPATCH_CURRENT_QUEUE_LABEL), dispatch_queue_get_label(dispatch_get_main_queue())) == 0) {
        // already in main thread.
        block();
    } else {
        // sync to main queue.
        dispatch_sync(dispatch_get_main_queue(), block);
    }
}

static inline void MR_async_main_queue(dispatch_block_t block){
    assert(block);
    // async to main queue.
    dispatch_async(dispatch_get_main_queue(), block);
}


typedef enum MRColorRange {
    MRCOL_RANGE_UNSPECIFIED = 0,
    MRCOL_RANGE_MPEG        = 1, // the normal 219*2^(n-8) "MPEG" YUV ranges
    MRCOL_RANGE_JPEG        = 2, // the normal     2^n-1   "JPEG" YUV ranges
    MRCOL_RANGE_NB               // Not part of ABI
}MRColorRange;

typedef struct MRPicture{
    /**
     * pointer to the picture/channel planes.
     * This might be different from the first allocated byte
     *
     * Some decoders access areas outside 0,0 - width,height, please
     * see avcodec_align_dimensions2(). Some filters and swscale can read
     * up to 16 bytes beyond the planes, if these filters are to be used,
     * then 16 extra bytes must be allocated.
     *
     * NOTE: Except for hwaccel formats, pointers not needed by the format
     * MUST be set to NULL.
     */
    uint8_t *data[8];

    /**
     * For video, size in bytes of each picture line.
     * For audio, size in bytes of each plane.
     *
     * For audio, only linesize[0] may be set. For planar audio, each channel
     * plane must be the same size.
     *
     * For video the linesizes should be multiples of the CPUs alignment
     * preference, this is 16 or 32 for modern desktop CPUs.
     * Some code requires such alignment other code can be slower without
     * correct alignment, for yet other it makes no difference.
     *
     * @note The linesize may be larger than the size of usable data -- there
     * may be extra padding present for performance reasons.
     */
    int linesize[8];
    int width, height;
    enum MRColorRange color_range;
    MRPixelFormat format;
}MRPicture;

// safe usleep
static inline void mr_usleep(long s) {
    //mr_usleep is uint32 type!
    if (s >= 0) {
        usleep((useconds_t)s);
    }
}

// safe sleep
static inline void mr_sleep(long s) {
    //sleep is unsigned int type!
    if (s >= 0) {
        sleep((unsigned int)s);
    }
}

#endif /* FFPlayerHeader_h */
