//
//  FFTPacketQueue.m
//  FFmpegTutorial
//
//  Created by qianlongxu on 2022/7/16.
//

#import "FFTPacketQueue.h"
#import <libavcodec/packet.h>

@interface FFTPacketQueueItem : NSObject

@property (nonatomic, assign) AVPacket pkt;

@end

@implementation FFTPacketQueueItem

- (instancetype)initWithAVPacket:(AVPacket *)pkt
{
    self = [super init];
    if (self) {
        self.pkt = *pkt;
    }
    return self;
}

- (void)dealloc
{
    av_packet_unref(&_pkt);
}

- (AVPacket *)pktPtr
{
    return &_pkt;
}

@end

@interface FFTPacketQueue ()

@property (nonatomic, strong) NSMutableArray *queue;
@property (nonatomic, strong) NSRecursiveLock *lock;
@property (nonatomic, strong) NSCondition *condition;
@property (atomic, assign) BOOL canceled;

@end

@implementation FFTPacketQueue

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

- (void)enQueue:(AVPacket *)frame
{
    if (self.canceled) {
        return;
    }
    FFTPacketQueueItem *item = [[FFTPacketQueueItem alloc] initWithAVPacket:frame];
    [self.lock lock];
    [self.queue addObject:item];
    [self.lock unlock];
}

- (NSUInteger)count
{
    NSUInteger count = 0;
    [self.lock lock];
    count = [self.queue count];
    [self.lock unlock];
    return count;
}

- (FFTPacketQueueItem *)waitAitem
{
    FFTPacketQueueItem *item = nil;
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

- (FFTPacketQueueItem *)popAitem
{
    FFTPacketQueueItem *item = nil;
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

- (void)deQueue:(void (^)(AVPacket * _Nullable))block
{
    FFTPacketQueueItem *item = [self waitAitem];
    AVPacket *pkt = [item pktPtr];
    if (block) {
        block(pkt);
    }
    if (pkt) {
        av_packet_unref(pkt);
    }
}

@end
