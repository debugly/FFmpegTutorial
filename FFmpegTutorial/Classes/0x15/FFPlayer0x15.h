//
//  FFPlayer0x15.h
//  FFmpegTutorial
//
//  Created by qianlongxu on 2020/6/25.
//

#import <Foundation/Foundation.h>
#import "FFPlayerHeader.h"
#import <CoreVideo/CVPixelBuffer.h>

NS_ASSUME_NONNULL_BEGIN

//videoOpened info's key
typedef NSString * const kFFPlayer0x15InfoKey;
//视频时长；单位s
FOUNDATION_EXPORT kFFPlayer0x15InfoKey kFFPlayer0x15Duration;
//视频封装格式；可能有多个，使用 ”,“ 分割
FOUNDATION_EXPORT kFFPlayer0x15InfoKey kFFPlayer0x15ContainerFmt;
//视频宽；单位像素
FOUNDATION_EXPORT kFFPlayer0x15InfoKey kFFPlayer0x15Width;
//视频高；单位像素
FOUNDATION_EXPORT kFFPlayer0x15InfoKey kFFPlayer0x15Height;
//视频编码格式
FOUNDATION_EXPORT kFFPlayer0x15InfoKey kFFPlayer0x15VideoFmt;
//音频编码格式
FOUNDATION_EXPORT kFFPlayer0x15InfoKey kFFPlayer0x15AudioFmt;
//视频旋转角度
FOUNDATION_EXPORT kFFPlayer0x15InfoKey kFFPlayer0x15Rotate;

@class FFPlayer0x15;
@protocol FFPlayer0x15Delegate <NSObject>

@optional
- (void)reveiveFrameToRenderer:(CVPixelBufferRef)img;
- (void)player:(FFPlayer0x15*)player videoDidOpen:(NSDictionary *)info;

@end

@interface FFPlayer0x15 : NSObject

///播放地址
@property (nonatomic, copy) NSString *contentPath;
///code is FFPlayerErrorCode enum.
@property (nonatomic, strong, nullable) NSError *error;
///期望的像素格式
@property (nonatomic, assign) MRPixelFormatMask supportedPixelFormats;
@property (nonatomic, weak) id <FFPlayer0x15Delegate> delegate;
///记录解码后的视频桢总数
@property (atomic, assign, readonly) int videoFrameCount;
///记录解码后的音频桢总数
@property (atomic, assign, readonly) int audioFrameCount;

///准备
- (void)prepareToPlay;
///读包
- (void)play;
///停止读包
- (void)asyncStop;
///发生错误，具体错误为 self.error
- (void)onError:(dispatch_block_t)block;

- (void)onPacketBufferEmpty:(dispatch_block_t)block;
- (void)onPacketBufferFull:(dispatch_block_t)block;

///缓冲情况
- (MR_PACKET_SIZE)peekPacketBufferStatus;

@end

NS_ASSUME_NONNULL_END
