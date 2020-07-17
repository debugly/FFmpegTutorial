//
//  MR0x22AudioRenderer.h
//  FFmpegTutorial-iOS
//
//  Created by Matt Reach on 2020/7/16.
//  Copyright © 2020 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <FFmpegTutorial/FFPlayerHeader.h>
NS_ASSUME_NONNULL_BEGIN

typedef UInt32(^MRFetchPacketSample)(uint8_t*buffer,UInt32 bufferSize);
typedef UInt32(^MRFetchPlanarSample)(uint8_t*left,UInt32 leftSize,uint8_t*right,UInt32 rightSize);

@interface MR0x22AudioRenderer : NSObject

//采用audio queue？默认NO
@property (nonatomic, assign) bool preferredAudioQueue;
//声音大小
@property (nonatomic, assign) float outputVolume;
//采样深度
@property (nonatomic, assign, readonly) MRSampleFormat sampleFmt;

///设置采样率
+ (int)setPreferredSampleRate:(int)rate;

- (void)active;
- (void)setupWithFmt:(MRSampleFormat)fmt sampleRate:(int)rate;
- (void)onFetchPacketSample:(MRFetchPacketSample)block;
- (void)onFetchPlanarSample:(MRFetchPlanarSample)block;
- (void)paly;

@end

NS_ASSUME_NONNULL_END
