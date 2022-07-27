//
//  FFSyncClock.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/7/27.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//


#import "FFSyncClock.h"
#import <libavutil/time.h>

@implementation FFSyncClock

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
    double time = av_gettime_relative() / 1000000.0;
    return self.pts_drift + time - (time - self.last_update);
}

@end
