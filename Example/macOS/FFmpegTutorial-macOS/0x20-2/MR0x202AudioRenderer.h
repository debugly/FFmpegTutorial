//
//  MR0x202AudioRenderer.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/9/26.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//
// 音频渲染器，内部根据音频采样深度自动和数据组织格式
// 自动选择 AudioUnit 或者 AudioQueue;
// 可以将 preferredAudioQueue 设置为 YES，择优先选择 AudioQueue

#import <Foundation/Foundation.h>
#import <FFmpegTutorial/FFPlayerHeader.h>
NS_ASSUME_NONNULL_BEGIN

typedef UInt32(^MRFetchPacketSample)(uint8_t*buffer,UInt32 bufferSize);
typedef UInt32(^MRFetchPlanarSample)(uint8_t*left,UInt32 leftSize,uint8_t*right,UInt32 rightSize);

@interface MR0x202AudioRenderer : NSObject

//采用audio queue？默认NO
@property (nonatomic, assign, readonly) BOOL preferredAudioQueue;
//采样深度
@property (nonatomic, assign, readonly) MRSampleFormat sampleFmt;

#warning TODO outputVolume
//声音大小
@property (nonatomic, assign) float outputVolume;

- (instancetype)initWithFmt:(MRSampleFormat)fmt
        preferredAudioQueue:(BOOL)preferredAudioQueue
                 sampleRate:(int)sampleRate;

- (void)onFetchPacketSample:(MRFetchPacketSample)block;
- (void)onFetchPlanarSample:(MRFetchPlanarSample)block;

- (void)play;
- (void)pause;

@end

NS_ASSUME_NONNULL_END
