//
//  FFSyncClock0x35.m
//  FFmpegTutorial
//
//  Created by qianlongxu on 2022/8/1.
//

#import "FFSyncClock0x35.h"

@implementation FFSyncClock0x35

- (void)setClock:(double)pts
{
    self.pts = pts;
}

- (double)getClock
{
    return self.pts;
}

@end
