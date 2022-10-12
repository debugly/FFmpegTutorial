//
//  FFTPlayer0x04.h
//  FFmpegTutorial
//
//  Created by qianlongxu on 2020/5/10.
//
// 创建读包线程，读取音视频包

#import <Foundation/Foundation.h>
#import "FFTPlayerHeader.h"

NS_ASSUME_NONNULL_BEGIN

@interface FFTPlayer0x04 : NSObject

///播放地址
@property (nonatomic, copy) NSString *contentPath;
///code is FFPlayerErrorCode enum.
@property (nonatomic, strong, nullable) NSError *error;
///记录读到的视频包总数
@property (atomic, assign, readonly) int videoPktCount;
///记录读到的音频包总数
@property (atomic, assign, readonly) int audioPktCount;
@property (nonatomic, copy) void(^onReadPkt)(int a,int v);
///准备
- (void)prepareToPlay;
///读包
- (void)play;
///停止读包
- (void)asyncStop;
///发生错误，具体错误为 self.error
- (void)onError:(dispatch_block_t)block;

@end

NS_ASSUME_NONNULL_END
