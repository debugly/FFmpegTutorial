//
//  FFVideoScale0x07.m
//  FFmpegTutorial
//
//  Created by Matt Reach on 2020/6/3.
//

#import "FFVideoScale0x07.h"
#import "FFPlayerInternalHeader.h"
#include <libswscale/swscale.h>
#include <libavutil/imgutils.h>

@interface FFVideoScale0x07()

@property (nonatomic, assign) enum AVPixelFormat srcPixFmt;
@property (nonatomic, assign) enum AVPixelFormat dstPixFmt;
@property (nonatomic, assign) struct SwsContext *sws_ctx;
@property (nonatomic, assign) int picWidth;
@property (nonatomic, assign) int picHeight;

@end

@implementation FFVideoScale0x07

- (instancetype)initWithSrcPixFmt:(int)srcPixFmt
                        dstPixFmt:(int)dstPixFmt
                         picWidth:(int)picWidth
                        picHeight:(int)picHeight
{
    self = [super init];
    if (self) {
        self.srcPixFmt = srcPixFmt;
        self.dstPixFmt = dstPixFmt;
        self.picWidth  = picWidth;
        self.picHeight = picHeight;
        
        self.sws_ctx = sws_getContext(picWidth, picHeight, srcPixFmt, picWidth, picHeight, dstPixFmt, SWS_POINT, NULL, NULL, NULL);
    }
    return self;
}

- (BOOL) rescaleFrame:(AVFrame *)inF out:(AVFrame **)outP
{
    AVFrame *out_frame = av_frame_alloc();
    ///important！
    av_frame_copy_props(out_frame, inF);
    
    out_frame->format  = self.dstPixFmt;
    out_frame->width   = self.picWidth;
    out_frame->height  = self.picHeight;
    
    memcpy(out_frame->linesize, inF->linesize, sizeof(out_frame->linesize));
    
    av_image_alloc(out_frame->data, out_frame->linesize, self.picWidth, self.picHeight, self.dstPixFmt, 1);
    
    int ret = sws_scale(self.sws_ctx, (const uint8_t* const*)inF->data, inF->linesize, 0, inF->height, out_frame->data, out_frame->linesize);
    if(ret < 0){
        // convert error, try next frame
        av_log(NULL, AV_LOG_ERROR, "fail scale video");
        av_freep(&out_frame->data);
        av_frame_free(&out_frame);
        return NO;
    }
    
    *outP = out_frame;
    return YES;
}

@end
