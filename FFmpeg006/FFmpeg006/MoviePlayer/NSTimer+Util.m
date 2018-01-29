//
//  NSTimer+Util.m
//  轮播图
//
//  Created by Qianlong Xu on 15-1-7.
//  Copyright (c) 2015年 Demo. All rights reserved.
//

#import "NSTimer+Util.h"

@implementation NSTimer (Util)

+ (NSTimer *)mr_scheduledWithTimeInterval:(NSTimeInterval)ti repeats:(BOOL)yesOrNo block:(void (^)(void))block
{
   return [NSTimer scheduledTimerWithTimeInterval:ti target:self selector:@selector(mr_blockInvoke:) userInfo:[block copy] repeats:yesOrNo];
}

+ (void)mr_blockInvoke:(NSTimer *)sender
{
    void (^block)(void) = sender.userInfo;
    if (block) {
        block();
    }
}

- (void)mr_pauseTimer
{
    if (!self.isValid) {
        return;
    }
    [self setFireDate:[NSDate distantFuture]];
}

- (void)mr_resumeTimerAfterTimeInterval:(NSTimeInterval)interval
{
    if (![self isValid]) {
        return ;
    }
    [self setFireDate:[NSDate dateWithTimeIntervalSinceNow:interval]];
}

- (void)mr_resumeTimer
{
    [self mr_resumeTimerAfterTimeInterval:0];
}

@end
