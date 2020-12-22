//
//  MRVideoScale.m
//  FFmpegTutorial
//
//  Created by Matt Reach on 2020/6/3.
//
// https://stackoverflow.com/questions/59778299/ffmpeg-sws-scale-returns-error-slice-parameters-0-2160-are-invalid
// https://blog.csdn.net/leixiaohua1020/article/details/12029505

#import "MRVideoScale.h"
#import "FFPlayerInternalHeader.h"
#include <libswscale/swscale.h>
#include <libavutil/imgutils.h>

@interface MRVideoScale()

@property (nonatomic, assign) enum AVPixelFormat dstPixFmt;
@property (nonatomic, assign) struct SwsContext *sws_ctx;
@property (nonatomic, assign) int srcWidth;
@property (nonatomic, assign) int srcHeight;
@property (nonatomic, assign) int dstWidth;
@property (nonatomic, assign) int dstHeight;
//复用一个，效率更高些
@property (nonatomic, assign) AVFrame *frame;

@end

@implementation MRVideoScale

- (void)dealloc
{
    if (self.frame) {
        if(_frame->data[0] != NULL){
            av_freep(_frame->data);
        }
        av_frame_free(&_frame);
    }
    if (self.sws_ctx) {
        sws_freeContext(self.sws_ctx);
    }
}

- (instancetype)initWithSrcPixFmt:(int)srcPixFmt
                        dstPixFmt:(int)dstPixFmt
                         srcWidth:(int)srcWidth
                        srcHeight:(int)srcHeight
                         dstWidth:(int)dstWidth
                        dstHeight:(int)dstHeight
{
    self = [super init];
    if (self) {
        
        self.dstPixFmt = dstPixFmt;
        self.srcWidth  = srcWidth;
        self.srcHeight = srcHeight;
        self.dstWidth = dstWidth;
        self.dstHeight = dstHeight;
        self.sws_ctx = sws_getContext(srcWidth, srcHeight, srcPixFmt,
                                      dstWidth, dstHeight, dstPixFmt,
                                      SWS_FAST_BILINEAR, NULL, NULL, NULL);
        self.frame = av_frame_alloc();
    }
    return self;
}

- (BOOL)rescaleFrame:(AVFrame *)inF
            outFrame:(AVFrame **)outF
{
    AVFrame *out_frame = self.frame;
    //important！
    av_frame_copy_props(out_frame, inF);

    if(NULL == out_frame->data[0]){
        out_frame->format = self.dstPixFmt;
        out_frame->width  = self.dstWidth;
        out_frame->height = self.dstHeight;
    
        av_image_fill_linesizes(out_frame->linesize, out_frame->format, out_frame->width);
        av_image_alloc(out_frame->data, out_frame->linesize, self.srcWidth, self.srcHeight, self.dstPixFmt, 1);
    }
    
    int ret = sws_scale(self.sws_ctx,
                        (const uint8_t* const*)inF->data,
                        inF->linesize,
                        0,
                        inF->height,
                        out_frame->data,
                        out_frame->linesize);
    if(ret < 0){
        // convert error, try next frame
        av_log(NULL, AV_LOG_ERROR, "fail scale video");
        av_freep(&out_frame->data);
        return NO;
    }
    
    *outF = out_frame;
    return YES;
}

@end
