//
//  FFPlayer0x30.h
//  FFmpegTutorial
//
//  Created by qianlongxu on 2020/7/17.
//

#import <Foundation/Foundation.h>
#import "FFPlayerHeader.h"
#import <CoreVideo/CVPixelBuffer.h>

NS_ASSUME_NONNULL_BEGIN
@protocol FFPlayer0x30Delegate <NSObject>

@optional
- (void)reveiveFrameToRenderer:(CVPixelBufferRef)img;
- (void)onInitAudioRender:(MRSampleFormat)fmt;

@end

@interface FFPlayer0x30 : NSObject

///播放地址
@property (nonatomic, copy) NSString *contentPath;
///code is FFPlayerErrorCode enum.
@property (nonatomic, strong, nullable) NSError *error;
///期望的像素格式
@property (nonatomic, assign) MRPixelFormatMask supportedPixelFormats;
///期望的音频采样深度
@property (nonatomic, assign) MRSampleFormatMask supportedSampleFormats;
///期望的音频采样率，比如 44100
@property (nonatomic, assign) int supportedSampleRate;

@property (nonatomic, weak) id <FFPlayer0x30Delegate> delegate;
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
- (void)onVideoEnds:(dispatch_block_t)block;

///m/n 缓冲情况
- (NSString *)peekPacketBufferStatus;

// 获取 packet 形式的音频数据，返回实际填充的字节数
- (UInt32)fetchPacketSample:(uint8_t*)buffer
                  wantBytes:(UInt32)bufferSize;

// 获取 planar 形式的音频数据，返回实际填充的字节数
- (UInt32)fetchPlanarSample:(uint8_t*)left
                   leftSize:(UInt32)leftSize
                      right:(uint8_t*)right
                  rightSize:(UInt32)rightSize;

@end

NS_ASSUME_NONNULL_END
