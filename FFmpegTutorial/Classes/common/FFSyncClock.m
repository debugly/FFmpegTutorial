//
//  FFSyncClock.m
//  FFmpegTutorial
//
//  Created by qianlongxu on 2022/8/1.
//

#import "FFSyncClock.h"

@implementation FFSyncClock

- (void)setClock:(double)pts
{
    self.pts = pts;
}

- (double)getClock
{
    return self.pts;
}

@end
