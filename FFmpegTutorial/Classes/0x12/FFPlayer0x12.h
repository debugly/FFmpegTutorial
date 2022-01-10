//
//  FFPlayer0x12.h
//  FFmpegTutorial
//
//  Created by qianlongxu on 2020/6/6.
//

#import <Foundation/Foundation.h>
#import "FFPlayerHeader.h"

NS_ASSUME_NONNULL_BEGIN
@class CIImage;
@protocol FFPlayer0x12Delegate <NSObject>

@optional
- (void)reveiveFrameToRenderer:(CIImage *)img;

@end

@interface FFPlayer0x12 : NSObject

///播放地址
@property (nonatomic, copy) NSString *contentPath;
///code is FFPlayerErrorCode enum.
@property (nonatomic, strong, nullable) NSError *error;
///期望的像素格式
@property (nonatomic, assign) MRPixelFormatMask supportedPixelFormats;
@property (nonatomic, weak) id <FFPlayer0x12Delegate> delegate;
///记录解码后的视频桢总数
@property (atomic, assign, readonly) int videoFrameCount;
///记录解码后的音频桢总数
@property (atomic, assign, readonly) int audioFrameCount;

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

///缓冲情况
- (MR_PACKET_SIZE)peekPacketBufferStatus;

@end

NS_ASSUME_NONNULL_END
