//
//  FFTPlayer0x30.h
//  FFmpegTutorial
//
//  Created by qianlongxu on 2022/7/10.
//

#import <Foundation/Foundation.h>
#import "FFTPlayerHeader.h"

NS_ASSUME_NONNULL_BEGIN

typedef struct AVFrame AVFrame;
//videoOpened info's key
typedef NSString * const kFFTPlayer0x30InfoKey;

//视频宽；单位像素
FOUNDATION_EXPORT kFFTPlayer0x30InfoKey kFFTPlayer0x30Width;
//视频高；单位像素
FOUNDATION_EXPORT kFFTPlayer0x30InfoKey kFFTPlayer0x30Height;
//视频流时基
FOUNDATION_EXPORT kFFTPlayer0x30InfoKey kFFTPlayer0x30StreamTimeBase;
//视频桢平均时长
FOUNDATION_EXPORT kFFTPlayer0x30InfoKey kFFTPlayer0x30AverageDuration;

@interface FFTPlayer0x30 : NSObject

///播放地址
@property (nonatomic, copy) NSString *contentPath;
///code is FFPlayerErrorCode enum.
@property (nonatomic, strong, nullable) NSError *error;
///记录读到的视频包总数
@property (atomic, assign, readonly) int videoPktCount;
///记录读到的音频包总数
@property (atomic, assign, readonly) int audioPktCount;
///记录解码后的视频桢总数
@property (atomic, assign, readonly) int videoFrameCount;
///记录解码后的音频桢总数
@property (atomic, assign, readonly) int audioFrameCount;
///指定输出的视频像素格式
@property (nonatomic, assign) MRPixelFormat supportedPixelFormat;
///指定输出的音频采样格式
@property (nonatomic, assign) MRSampleFormat supportedSampleFormat;
///期望的音频采样率，比如 44100;不指定时使用音频的采样率
@property (nonatomic, assign) int supportedSampleRate;

@property (nonatomic, copy) void(^onStreamOpened)(NSDictionary *info);
@property (nonatomic, copy) void(^onReadPkt)(int a,int v);
//type: 1->video;2->audio;
@property (nonatomic, copy) void(^onDecoderFrame)(int type,int serial,AVFrame *frame);
@property (nonatomic, copy) void(^onError)(NSError *);

///准备
- (void)prepareToPlay;
///读包
- (void)play;
///停止读包
- (void)asyncStop;

@end

NS_ASSUME_NONNULL_END
