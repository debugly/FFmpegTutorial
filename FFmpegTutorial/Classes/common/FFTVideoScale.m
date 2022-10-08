//
//  FFTVideoScale.m
//  FFmpegTutorial
//
//  Created by Matt Reach on 2020/7/10.
//

#import "FFTVideoScale.h"
#import <libswscale/swscale.h>
#import <libavutil/imgutils.h>
#import <libavutil/frame.h>

@interface FFTVideoScale()

@property (nonatomic, assign) enum AVPixelFormat dstPixFmt;
@property (nonatomic, assign) struct SwsContext *sws_ctx;
@property (nonatomic, assign) int picWidth;
@property (nonatomic, assign) int picHeight;
//复用一个，效率更高些
@property (nonatomic, assign) AVFrame *frame;

@end

@implementation FFTVideoScale

/*
 typedef struct FormatEntry {
     uint8_t is_supported_in         :1;
     uint8_t is_supported_out        :1;
     uint8_t is_supported_endianness :1;
 } FormatEntry;

 static const FormatEntry format_entries[AV_PIX_FMT_NB] = {
     [AV_PIX_FMT_YUV420P]     = { 1, 1 },
     [AV_PIX_FMT_YUYV422]     = { 1, 1 },
     [AV_PIX_FMT_RGB24]       = { 1, 1 },
     [AV_PIX_FMT_BGR24]       = { 1, 1 },
     [AV_PIX_FMT_YUV422P]     = { 1, 1 },
     [AV_PIX_FMT_YUV444P]     = { 1, 1 },
     [AV_PIX_FMT_YUV410P]     = { 1, 1 },
     [AV_PIX_FMT_YUV411P]     = { 1, 1 },
     [AV_PIX_FMT_GRAY8]       = { 1, 1 },
     [AV_PIX_FMT_MONOWHITE]   = { 1, 1 },
     [AV_PIX_FMT_MONOBLACK]   = { 1, 1 },
     [AV_PIX_FMT_PAL8]        = { 1, 0 },
     [AV_PIX_FMT_YUVJ420P]    = { 1, 1 },
     [AV_PIX_FMT_YUVJ411P]    = { 1, 1 },
     [AV_PIX_FMT_YUVJ422P]    = { 1, 1 },
     [AV_PIX_FMT_YUVJ444P]    = { 1, 1 },
     [AV_PIX_FMT_YVYU422]     = { 1, 1 },
     [AV_PIX_FMT_UYVY422]     = { 1, 1 },
     [AV_PIX_FMT_UYYVYY411]   = { 0, 0 },
     [AV_PIX_FMT_BGR8]        = { 1, 1 },
     [AV_PIX_FMT_BGR4]        = { 0, 1 },
     [AV_PIX_FMT_BGR4_BYTE]   = { 1, 1 },
     [AV_PIX_FMT_RGB8]        = { 1, 1 },
     [AV_PIX_FMT_RGB4]        = { 0, 1 },
     [AV_PIX_FMT_RGB4_BYTE]   = { 1, 1 },
     [AV_PIX_FMT_NV12]        = { 1, 1 },
     [AV_PIX_FMT_NV21]        = { 1, 1 },
     [AV_PIX_FMT_ARGB]        = { 1, 1 },
     [AV_PIX_FMT_RGBA]        = { 1, 1 },
     [AV_PIX_FMT_ABGR]        = { 1, 1 },
     [AV_PIX_FMT_BGRA]        = { 1, 1 },
     [AV_PIX_FMT_0RGB]        = { 1, 1 },
     [AV_PIX_FMT_RGB0]        = { 1, 1 },
     [AV_PIX_FMT_0BGR]        = { 1, 1 },
     [AV_PIX_FMT_BGR0]        = { 1, 1 },
     [AV_PIX_FMT_GRAY9BE]     = { 1, 1 },
     [AV_PIX_FMT_GRAY9LE]     = { 1, 1 },
     [AV_PIX_FMT_GRAY10BE]    = { 1, 1 },
     [AV_PIX_FMT_GRAY10LE]    = { 1, 1 },
     [AV_PIX_FMT_GRAY12BE]    = { 1, 1 },
     [AV_PIX_FMT_GRAY12LE]    = { 1, 1 },
     [AV_PIX_FMT_GRAY16BE]    = { 1, 1 },
     [AV_PIX_FMT_GRAY16LE]    = { 1, 1 },
     [AV_PIX_FMT_YUV440P]     = { 1, 1 },
     [AV_PIX_FMT_YUVJ440P]    = { 1, 1 },
     [AV_PIX_FMT_YUV440P10LE] = { 1, 1 },
     [AV_PIX_FMT_YUV440P10BE] = { 1, 1 },
     [AV_PIX_FMT_YUV440P12LE] = { 1, 1 },
     [AV_PIX_FMT_YUV440P12BE] = { 1, 1 },
     [AV_PIX_FMT_YUVA420P]    = { 1, 1 },
     [AV_PIX_FMT_YUVA422P]    = { 1, 1 },
     [AV_PIX_FMT_YUVA444P]    = { 1, 1 },
     [AV_PIX_FMT_YUVA420P9BE] = { 1, 1 },
     [AV_PIX_FMT_YUVA420P9LE] = { 1, 1 },
     [AV_PIX_FMT_YUVA422P9BE] = { 1, 1 },
     [AV_PIX_FMT_YUVA422P9LE] = { 1, 1 },
     [AV_PIX_FMT_YUVA444P9BE] = { 1, 1 },
     [AV_PIX_FMT_YUVA444P9LE] = { 1, 1 },
     [AV_PIX_FMT_YUVA420P10BE]= { 1, 1 },
     [AV_PIX_FMT_YUVA420P10LE]= { 1, 1 },
     [AV_PIX_FMT_YUVA422P10BE]= { 1, 1 },
     [AV_PIX_FMT_YUVA422P10LE]= { 1, 1 },
     [AV_PIX_FMT_YUVA444P10BE]= { 1, 1 },
     [AV_PIX_FMT_YUVA444P10LE]= { 1, 1 },
     [AV_PIX_FMT_YUVA420P16BE]= { 1, 1 },
     [AV_PIX_FMT_YUVA420P16LE]= { 1, 1 },
     [AV_PIX_FMT_YUVA422P16BE]= { 1, 1 },
     [AV_PIX_FMT_YUVA422P16LE]= { 1, 1 },
     [AV_PIX_FMT_YUVA444P16BE]= { 1, 1 },
     [AV_PIX_FMT_YUVA444P16LE]= { 1, 1 },
     [AV_PIX_FMT_RGB48BE]     = { 1, 1 },
     [AV_PIX_FMT_RGB48LE]     = { 1, 1 },
     [AV_PIX_FMT_RGBA64BE]    = { 1, 1, 1 },
     [AV_PIX_FMT_RGBA64LE]    = { 1, 1, 1 },
     [AV_PIX_FMT_RGB565BE]    = { 1, 1 },
     [AV_PIX_FMT_RGB565LE]    = { 1, 1 },
     [AV_PIX_FMT_RGB555BE]    = { 1, 1 },
     [AV_PIX_FMT_RGB555LE]    = { 1, 1 },
     [AV_PIX_FMT_BGR565BE]    = { 1, 1 },
     [AV_PIX_FMT_BGR565LE]    = { 1, 1 },
     [AV_PIX_FMT_BGR555BE]    = { 1, 1 },
     [AV_PIX_FMT_BGR555LE]    = { 1, 1 },
     [AV_PIX_FMT_YUV420P16LE] = { 1, 1 },
     [AV_PIX_FMT_YUV420P16BE] = { 1, 1 },
     [AV_PIX_FMT_YUV422P16LE] = { 1, 1 },
     [AV_PIX_FMT_YUV422P16BE] = { 1, 1 },
     [AV_PIX_FMT_YUV444P16LE] = { 1, 1 },
     [AV_PIX_FMT_YUV444P16BE] = { 1, 1 },
     [AV_PIX_FMT_RGB444LE]    = { 1, 1 },
     [AV_PIX_FMT_RGB444BE]    = { 1, 1 },
     [AV_PIX_FMT_BGR444LE]    = { 1, 1 },
     [AV_PIX_FMT_BGR444BE]    = { 1, 1 },
     [AV_PIX_FMT_YA8]         = { 1, 1 },
     [AV_PIX_FMT_YA16BE]      = { 1, 0 },
     [AV_PIX_FMT_YA16LE]      = { 1, 0 },
     [AV_PIX_FMT_BGR48BE]     = { 1, 1 },
     [AV_PIX_FMT_BGR48LE]     = { 1, 1 },
     [AV_PIX_FMT_BGRA64BE]    = { 1, 1, 1 },
     [AV_PIX_FMT_BGRA64LE]    = { 1, 1, 1 },
     [AV_PIX_FMT_YUV420P9BE]  = { 1, 1 },
     [AV_PIX_FMT_YUV420P9LE]  = { 1, 1 },
     [AV_PIX_FMT_YUV420P10BE] = { 1, 1 },
     [AV_PIX_FMT_YUV420P10LE] = { 1, 1 },
     [AV_PIX_FMT_YUV420P12BE] = { 1, 1 },
     [AV_PIX_FMT_YUV420P12LE] = { 1, 1 },
     [AV_PIX_FMT_YUV420P14BE] = { 1, 1 },
     [AV_PIX_FMT_YUV420P14LE] = { 1, 1 },
     [AV_PIX_FMT_YUV422P9BE]  = { 1, 1 },
     [AV_PIX_FMT_YUV422P9LE]  = { 1, 1 },
     [AV_PIX_FMT_YUV422P10BE] = { 1, 1 },
     [AV_PIX_FMT_YUV422P10LE] = { 1, 1 },
     [AV_PIX_FMT_YUV422P12BE] = { 1, 1 },
     [AV_PIX_FMT_YUV422P12LE] = { 1, 1 },
     [AV_PIX_FMT_YUV422P14BE] = { 1, 1 },
     [AV_PIX_FMT_YUV422P14LE] = { 1, 1 },
     [AV_PIX_FMT_YUV444P9BE]  = { 1, 1 },
     [AV_PIX_FMT_YUV444P9LE]  = { 1, 1 },
     [AV_PIX_FMT_YUV444P10BE] = { 1, 1 },
     [AV_PIX_FMT_YUV444P10LE] = { 1, 1 },
     [AV_PIX_FMT_YUV444P12BE] = { 1, 1 },
     [AV_PIX_FMT_YUV444P12LE] = { 1, 1 },
     [AV_PIX_FMT_YUV444P14BE] = { 1, 1 },
     [AV_PIX_FMT_YUV444P14LE] = { 1, 1 },
     [AV_PIX_FMT_GBRP]        = { 1, 1 },
     [AV_PIX_FMT_GBRP9LE]     = { 1, 1 },
     [AV_PIX_FMT_GBRP9BE]     = { 1, 1 },
     [AV_PIX_FMT_GBRP10LE]    = { 1, 1 },
     [AV_PIX_FMT_GBRP10BE]    = { 1, 1 },
     [AV_PIX_FMT_GBRAP10LE]   = { 1, 1 },
     [AV_PIX_FMT_GBRAP10BE]   = { 1, 1 },
     [AV_PIX_FMT_GBRP12LE]    = { 1, 1 },
     [AV_PIX_FMT_GBRP12BE]    = { 1, 1 },
     [AV_PIX_FMT_GBRAP12LE]   = { 1, 1 },
     [AV_PIX_FMT_GBRAP12BE]   = { 1, 1 },
     [AV_PIX_FMT_GBRP14LE]    = { 1, 1 },
     [AV_PIX_FMT_GBRP14BE]    = { 1, 1 },
     [AV_PIX_FMT_GBRP16LE]    = { 1, 1 },
     [AV_PIX_FMT_GBRP16BE]    = { 1, 1 },
     [AV_PIX_FMT_GBRAP]       = { 1, 1 },
     [AV_PIX_FMT_GBRAP16LE]   = { 1, 1 },
     [AV_PIX_FMT_GBRAP16BE]   = { 1, 1 },
     [AV_PIX_FMT_BAYER_BGGR8] = { 1, 0 },
     [AV_PIX_FMT_BAYER_RGGB8] = { 1, 0 },
     [AV_PIX_FMT_BAYER_GBRG8] = { 1, 0 },
     [AV_PIX_FMT_BAYER_GRBG8] = { 1, 0 },
     [AV_PIX_FMT_BAYER_BGGR16LE] = { 1, 0 },
     [AV_PIX_FMT_BAYER_BGGR16BE] = { 1, 0 },
     [AV_PIX_FMT_BAYER_RGGB16LE] = { 1, 0 },
     [AV_PIX_FMT_BAYER_RGGB16BE] = { 1, 0 },
     [AV_PIX_FMT_BAYER_GBRG16LE] = { 1, 0 },
     [AV_PIX_FMT_BAYER_GBRG16BE] = { 1, 0 },
     [AV_PIX_FMT_BAYER_GRBG16LE] = { 1, 0 },
     [AV_PIX_FMT_BAYER_GRBG16BE] = { 1, 0 },
     [AV_PIX_FMT_XYZ12BE]     = { 1, 1, 1 },
     [AV_PIX_FMT_XYZ12LE]     = { 1, 1, 1 },
     [AV_PIX_FMT_AYUV64LE]    = { 1, 1},
     [AV_PIX_FMT_P010LE]      = { 1, 1 },
     [AV_PIX_FMT_P010BE]      = { 1, 1 },
     [AV_PIX_FMT_P016LE]      = { 1, 1 },
     [AV_PIX_FMT_P016BE]      = { 1, 1 },
 };

 int sws_isSupportedInput(enum AVPixelFormat pix_fmt)
 {
     return (unsigned)pix_fmt < AV_PIX_FMT_NB ?
            format_entries[pix_fmt].is_supported_in : 0;
 }

 int sws_isSupportedOutput(enum AVPixelFormat pix_fmt)
 {
     return (unsigned)pix_fmt < AV_PIX_FMT_NB ?
            format_entries[pix_fmt].is_supported_out : 0;
 }
 
 */

+ (BOOL)checkCanConvertFrom:(int)src to:(int)dest
{
    if (sws_isSupportedInput(src) <= 0) {
        NSAssert(NO, @"%d is not supported as input format",src);
        return NO;
    } else if (sws_isSupportedOutput(dest) <= 0) {
        NSAssert(NO, @"%d is not supported as output format",dest);
        return NO;
    }
    return YES;
}

- (void)dealloc
{
    if (self.frame) {
        if(_frame->data[0] != NULL){
            av_freep(_frame->data);
        }
        av_frame_free(&_frame);
    }
}

- (instancetype)initWithSrcPixFmt:(int)srcPixFmt
                        dstPixFmt:(int)dstPixFmt
                         picWidth:(int)picWidth
                        picHeight:(int)picHeight
{
    self = [super init];
    if (self) {
        self.dstPixFmt = dstPixFmt;
        self.picWidth  = picWidth;
        self.picHeight = picHeight;
        
        self.sws_ctx = sws_getContext(picWidth, picHeight, srcPixFmt, picWidth, picHeight, dstPixFmt, SWS_POINT, NULL, NULL, NULL);
        
        if (NULL == self.sws_ctx) {
            NSAssert(NO, @"create sws ctx failed");
            return nil;
        }
        self.frame = av_frame_alloc();
    }
    return self;
}

- (BOOL)rescaleFrame:(AVFrame *)inF out:(AVFrame **)outP
{
    AVFrame *out_frame = self.frame;
    //important！
    av_frame_copy_props(out_frame, inF);

    if(NULL == out_frame->data[0]){
        out_frame->format  = self.dstPixFmt;
        out_frame->width   = self.picWidth;
        out_frame->height  = self.picHeight;
        
        av_image_fill_linesizes(out_frame->linesize, out_frame->format, out_frame->width);
        av_image_alloc(out_frame->data, out_frame->linesize, self.picWidth, self.picHeight, self.dstPixFmt, 1);
    }
    
    int ret = sws_scale(self.sws_ctx, (const uint8_t* const*)inF->data, inF->linesize, 0, inF->height, out_frame->data, out_frame->linesize);
    if(ret < 0){
        // convert error, try next frame
        av_log(NULL, AV_LOG_ERROR, "fail scale video");
        av_freep(&out_frame->data);
        return NO;
    }
    
    *outP = out_frame;
    return YES;
}

@end
