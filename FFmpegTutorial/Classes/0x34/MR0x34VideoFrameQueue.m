//
//  MR0x34VideoFrameQueue.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/7/25.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x34VideoFrameQueue.h"
#import <MRFFmpegPod/libavutil/frame.h>
#import <MRFFmpegPod/libavutil/rational.h>

@interface MR0x34VideoFrameItem : NSObject

@property (nonatomic,assign) AVFrame *frame;
@property (nonatomic,assign) int64_t pts;

@end

@implementation MR0x34VideoFrameItem

- (instancetype)initWithAVFrame:(AVFrame *)frame
{
    self = [super init];
    if (self) {
        _pts = frame->pts;
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

@interface MR0x34VideoFrameQueue ()

@property (nonatomic, strong) NSMutableArray *queue;
@property (nonatomic, strong) NSRecursiveLock *lock;
@property (nonatomic, strong) NSCondition *condition;
@property (atomic, assign) BOOL canceled;
@property (nonatomic,assign) int64_t position;

@end

@implementation MR0x34VideoFrameQueue

- (void)dealloc
{
    
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.queue = [NSMutableArray array];
        self.lock = [[NSRecursiveLock alloc] init];
        self.condition = [NSCondition new];
    }
    return self;
}

- (void)cancel
{
    self.canceled = YES;
}

- (void)enQueue:(AVFrame *)frame
{
    if (self.canceled) {
        return;
    }
    MR0x34VideoFrameItem *item = [[MR0x34VideoFrameItem alloc] initWithAVFrame:frame];
    [self.lock lock];
    [self.queue addObject:item];
    [self.lock unlock];
}

- (NSUInteger)size
{
    NSUInteger size = 0;
    [self.lock lock];
    size = [self.queue count];
    [self.lock unlock];
    return size;
}

- (MR0x34VideoFrameItem *)waitAitem
{
    MR0x34VideoFrameItem *item = nil;
    while (!self.canceled) {
        [self.lock lock];
        if ([self.queue count] > 0) {
            item = [self.queue firstObject];
            [self.queue removeObjectAtIndex:0];
            [self.lock unlock];
            break;
        } else {
            [self.lock unlock];
            [self.condition waitUntilDate:[NSDate dateWithTimeIntervalSinceNow:0.01]];
        }
    }
    return item;
}

- (MR0x34VideoFrameItem *)popAitem
{
    MR0x34VideoFrameItem *item = nil;
    if (!self.canceled) {
        [self.lock lock];
        if ([self.queue count] > 0) {
            item = [self.queue firstObject];
            [self.queue removeObjectAtIndex:0];
        }
        [self.lock unlock];
    }
    return item;
}

- (void)_updateFramePst:(MR0x34VideoFrameItem *)item
{
    if (item && item.pts != AV_NOPTS_VALUE) {
        int64_t pos = item.pts * av_q2d(self.time_base);
        self.position = pos;
    }
}

- (void)syncDeQueue:(AVFrame *)dst
{
    MR0x34VideoFrameItem *item = [self waitAitem];
    [self _updateFramePst:item];
    av_frame_move_ref(dst, item.frame);
}

- (void)asyncDeQueue:(void (^)(AVFrame * _Nullable))block
{
    MR0x34VideoFrameItem *item = [self popAitem];
    [self _updateFramePst:item];
    if (block) {
        block(item?item.frame:NULL);
    }
    av_frame_unref(item.frame);
}

@end
