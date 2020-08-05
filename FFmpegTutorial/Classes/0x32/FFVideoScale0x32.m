//
//  FFVideoScale0x32.m
//  FFmpegTutorial
//
//  Created by Matt Reach on 2020/8/4.
//

#import "FFVideoScale0x32.h"
#import "FFPlayerInternalHeader.h"
#include <libswscale/swscale.h>
#include <libavutil/imgutils.h>

@interface FFVideoScale0x32()

@property (nonatomic, assign) enum AVPixelFormat dstPixFmt;
@property (nonatomic, assign) struct SwsContext *sws_ctx;
@property (nonatomic, assign) int picWidth;
@property (nonatomic, assign) int picHeight;
//复用一个，效率更高些
@property (nonatomic, assign) AVFrame *frame;

@end

@implementation FFVideoScale0x32

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
