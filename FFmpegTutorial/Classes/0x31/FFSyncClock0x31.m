//
//  FFSyncClock0x31.m
//  FFmpegTutorial
//
//  Created by Matt Reach on 2020/7/30.
//

#import "FFSyncClock0x31.h"
#import <libavutil/time.h>

@implementation FFSyncClock0x31

- (void)dealloc
{
    
}

- (void)setClock:(double)pts
{
    double time = av_gettime_relative() / 1000000.0;
    [self setClock:pts at:time];
}

- (void)setClock:(double)pts at:(double)time
{
    self.pts = pts;
    self.last_update = time;
    self.pts_drift = pts - time;
}

- (double)getClock
{
    if (self.paused) {
        return self.pts;
    } else {
        double time = av_gettime_relative() / 1000000.0;
        return self.pts_drift + time;
    }
}

@end
