//
//  FFPlayer0x33.h
//  FFmpegTutorial
//
//  Created by qianlongxu on 2022/7/20.
//

#import <Foundation/Foundation.h>
#import "FFPlayerHeader.h"
#import "MRPlatform.h"
#import "MR0x33VideoRendererProtocol.h"

NS_ASSUME_NONNULL_BEGIN

//videoOpened info's key
typedef NSString * const kFFPlayer0x33InfoKey;
//视频宽；单位像素
FOUNDATION_EXPORT kFFPlayer0x33InfoKey kFFPlayer0x33Width;
//视频高；单位像素
FOUNDATION_EXPORT kFFPlayer0x33InfoKey kFFPlayer0x33Height;


typedef struct AVFrame AVFrame;

@interface FFPlayer0x33 : NSObject

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
///记录解码后还没渲染的视频桢总数
@property (assign, readonly) int videoFrameQueueSize;
@property (assign, readonly) int audioFrameQueueSize;
@property (nonatomic, copy, readonly) NSString * audioRenderName;
@property (nonatomic, copy) NSString * videoPixelInfo;
@property (nonatomic, copy) NSString * audioSamplelInfo;

///指定输出的视频像素格式
@property (nonatomic, assign) MRPixelFormat supportedPixelFormat;
///指定输出的音频采样格式
@property (nonatomic, assign) MRSampleFormat supportedSampleFormat;
///期望的音频采样率，比如 44100;不指定时使用音频的采样率
@property (nonatomic, assign) int supportedSampleRate;

@property (nonatomic, copy) void(^onStreamOpened)(NSDictionary *info);
@property (nonatomic, copy) void(^onReadPkt)(int a,int v);
@property (nonatomic, copy) void(^onError)(NSError *);
//lazy getter
@property (nonatomic, strong) UIView<MR0x33VideoRendererProtocol> *videoRender;
///准备
- (void)prepareToPlay;
///读包
- (void)load;
///停止读包
- (void)asyncStop;
//播放
- (void)play;

@end

NS_ASSUME_NONNULL_END
