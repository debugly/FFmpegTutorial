//
//  FFPlayer0x03.h
//  FFmpegTutorial
//
//  Created by qianlongxu on 2020/4/27.
//

#import <Foundation/Foundation.h>
#import "FFPlayerHeader.h"

NS_ASSUME_NONNULL_BEGIN

@interface FFPlayer0x03 : NSObject

///播放地址
@property (nonatomic, copy) NSString *contentPath;
///code is FFPlayerErrorCode enum.
@property (nonatomic, strong, nullable) NSError *error;

///准备
- (void)prepareToPlay;
///读包
- (void)play;
///停止读包
- (void)stop;
///发生错误，具体错误为 self.error
- (void)onError:(dispatch_block_t)block;

- (void)onPacketBufferEmpty:(dispatch_block_t)block;
- (void)onPacketBufferFull:(dispatch_block_t)block;

///m/n 缓冲情况
- (NSString *)peekPacketBufferStatus;

//模拟消耗

///消耗缓存队列里的音视频packet各一个
- (void)consumePackets;
///消耗掉缓存队列里的所有packet
- (void)consumeAllPackets;

@end

NS_ASSUME_NONNULL_END
