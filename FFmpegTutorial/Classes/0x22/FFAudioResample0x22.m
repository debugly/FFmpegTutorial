//
//  FFAudioResample0x22.m
//  FFmpegTutorial
//
//  Created by Matt Reach on 2020/7/16.
//

#import "FFAudioResample0x22.h"
#import "FFPlayerInternalHeader.h"
#include <libswresample/swresample.h>
#include <libavutil/samplefmt.h>

@interface FFAudioResample0x22()

@property (nonatomic, assign, readwrite) int out_sample_fmt;
@property (nonatomic, assign, readwrite) int out_sample_rate;

@property (nonatomic, assign) struct SwrContext *swr_ctx;
//复用一个，效率更高些
@property (nonatomic, assign) AVFrame *frame;

@end

@implementation FFAudioResample0x22

- (void)dealloc
{
    if (self.frame) {
        if(_frame->data[0] != NULL){
            av_freep(_frame->data);
        }
//        av_frame_free(&_frame);
    }
}

- (instancetype)initWithSrcSampleFmt:(int)in_sample_fmt
                        dstSampleFmt:(int)out_sample_fmt
                          srcChannel:(int)in_ch_layout
                          dstChannel:(int)out_ch_layout
                             srcRate:(int)in_sample_rate
                             dstRate:(int)out_sample_rate
{
    self = [super init];
    if (self) {
        
        self.out_sample_rate = out_sample_rate;
        self.out_sample_fmt = out_sample_fmt;
        
        SwrContext *swr_ctx = swr_alloc_set_opts(NULL,
                                                 out_ch_layout,out_sample_fmt,out_sample_rate,
                                                 in_ch_layout,in_sample_fmt,in_sample_rate,
                                                 0,
                                                 NULL);
        
        int ret = swr_init(swr_ctx);
        if (ret) {
            swr_free(&swr_ctx);
            return nil;
        } else {
            self.swr_ctx = swr_ctx;
        }
        
        self.frame = av_frame_alloc();
    }
    return self;
}

- (BOOL)resampleFrame:(AVFrame *)inF out:(AVFrame **)outP
{
    AVFrame *out_frame = self.frame;
    //important！otherwise sample is not right! or use av_frame_move_ref relese and reset the outP in call side!
    av_frame_unref(out_frame);
    //important！
    av_frame_copy_props(out_frame, inF);

    //int64_t dst_ch_layout;
    //av_opt_get_int(d.swr_ctx, "out_channel_layout", 0, &dst_ch_layout);
    out_frame->channel_layout = inF->channel_layout;
    out_frame->sample_rate = self.out_sample_rate;
    out_frame->format = self.out_sample_fmt;
    
    int ret = swr_convert_frame(self.swr_ctx, out_frame, inF);
    if(ret < 0){
        // convert error, try next frame
        av_log(NULL, AV_LOG_ERROR, "fail resample audio");
        return -1;
    }
    
    *outP = out_frame;
    return YES;
}

@end
