//
//  MR0x24AudioFrameQueue.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/7/14.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x24AudioFrameQueue.h"
#import <MRFFmpegPod/libavutil/frame.h>

@interface MR0x24FrameItem : NSObject
{
    BOOL _eof;
}
@property (nonatomic,assign) AVFrame *frame;
@property (nonatomic,assign) int read;

@end

@implementation MR0x24FrameItem

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

- (BOOL)eof
{
    return _eof;
}

- (int)fillBuffers:(uint8_t * [2])buffer
          byteSize:(int)bufferSize
{
    const int fmt = self.frame->format;
    
    int chanels = av_sample_fmt_is_planar(fmt) ? 1 : 2;
    //self.frame->linesize[i] 比 data_size 要大，所以有杂音
    int data_size = av_samples_get_buffer_size(self.frame->linesize, chanels, self.frame->nb_samples, fmt, 1);
    int leave = data_size - self.read;
    if (leave <= 0) {
        _eof = YES;
        return 0;
    }
    
    int cpSize = MIN(bufferSize,leave);
    
    for(int i = 0; i < 2; i++) {
        uint8_t *dst = buffer[i];
        if (NULL != dst) {
            uint8_t *src = (uint8_t *)(self.frame->data[i]) + self.read;
            memcpy(dst, src, cpSize);
        } else {
            break;
        }
    }
    self.read += cpSize;
    
    if (data_size - self.read <= 0) {
        _eof = YES;
        av_frame_unref(self.frame);
    }
    
    return cpSize;
}

@end

@interface MR0x24AudioFrameQueue ()

@property (nonatomic, strong) NSMutableArray *queue;
@property (nonatomic, strong) NSRecursiveLock *lock;
@property (nonatomic, strong) NSCondition *condition;
@property (nonatomic, strong) MR0x24FrameItem *currentItem;
@property (atomic, assign) BOOL canceled;

@end

@implementation MR0x24AudioFrameQueue

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
    MR0x24FrameItem *item = [[MR0x24FrameItem alloc] initWithAVFrame:frame];
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

- (MR0x24FrameItem *)waitAitem
{
    MR0x24FrameItem *item = nil;
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

- (int)fillBuffers:(uint8_t * [2])buffer
           byteSize:(int)bufferSize
{
    int totalFilled = 0;
    while (bufferSize > 0) {
        if (!self.currentItem || [self.currentItem eof]) {
            self.currentItem = nil;
        }
        
        if (!self.currentItem) {
            self.currentItem = [self waitAitem];
        }
        if (self.canceled) {
            return totalFilled;
        }
        int filled = [self.currentItem fillBuffers:buffer byteSize:bufferSize];
        totalFilled += filled;
        bufferSize -= filled;
    }
    return totalFilled;
}

@end
