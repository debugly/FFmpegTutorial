//
//  FFTFrameQueue.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/7/27.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "FFTFrameQueue.h"
#import <MRFFmpegPod/libavutil/frame.h>
#import <MRFFmpegPod/libavutil/rational.h>

@implementation FFFrameItem

- (instancetype)initWithAVFrame:(AVFrame *)frame
{
    self = [super init];
    if (self) {
        self.frame = av_frame_alloc();
        av_frame_ref(self.frame, frame);
    }
    return self;
}

- (void)dealloc
{
    av_frame_free(&_frame);
}

@end

@interface FFTFrameQueue ()

@property (nonatomic, strong) NSMutableArray *queue;
@property (nonatomic, strong) NSRecursiveLock *lock;
@property (atomic, assign) BOOL canceled;
@property (nonatomic, strong) FFFrameItem *lastFrame;
@end

@implementation FFTFrameQueue

- (void)dealloc
{
    
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.queue = [NSMutableArray array];
        self.lock = [[NSRecursiveLock alloc] init];
    }
    return self;
}

- (void)cancel
{
    self.canceled = YES;
}

- (BOOL)isCanceled
{
    return self.canceled;
}

- (void)push:(FFFrameItem *)item
{
    if (self.canceled) {
        return;
    }
    [self.lock lock];
    [self.queue addObject:item];
    [self.lock unlock];
}

- (void)pop
{
    if (!self.canceled) {
        [self.lock lock];
        if ([self.queue count] > 0) {
            self.lastFrame = [self.queue objectAtIndex:0];
            [self.queue removeObjectAtIndex:0];
        }
        [self.lock unlock];
    }
}

- (int)count
{
    [self.lock lock];
    int size = (int)[self.queue count];
    [self.lock unlock];
    return size;
}

- (FFFrameItem *)peekLast
{
    return self.lastFrame;
}

- (FFFrameItem *)peek
{
    [self.lock lock];
    FFFrameItem *item = [self.queue firstObject];
    [self.lock unlock];
    return item;
}

- (FFFrameItem *)peekNext
{
    FFFrameItem *item = nil;
    [self.lock lock];
    if ([self.queue count] > 1) {
        item = [self.queue objectAtIndex:1];
    }
    [self.lock unlock];
    return item;
}

@end
