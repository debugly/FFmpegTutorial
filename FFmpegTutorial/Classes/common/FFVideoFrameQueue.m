//
//  FFVideoFrameQueue.m
//  FFmpegTutorial
//
//  Created by qianlongxu on 2022/10/6.
//

#import "FFVideoFrameQueue.h"
#import <libavutil/frame.h>

@implementation FFVideoFrameQueue

- (void)enQueue:(AVFrame *)frame
{
    FFFrameItem *item = [[FFFrameItem alloc] initWithAVFrame:frame];
    
    if (frame->pts != AV_NOPTS_VALUE) {
        item.pts = frame->pts * self.streamTimeBase;
    }
    //frame->pkt_duration;
    item.duration = self.averageDuration;
    
    [self push:item];
}

- (double)clock
{
    FFFrameItem *item = [self peek];
    if (item) {
        return item.pts;
    } else {
        return [self peekLast].pts;
    }
}

@end
