//
//  FFPlayer0x16.h
//  FFmpegTutorial
//
//  Created by qianlongxu on 2022/7/5.
//

#import <Foundation/Foundation.h>
#import "FFPlayerHeader.h"

//videoOpened info's key
typedef NSString * const kFFPlayer0x16InfoKey;

//视频宽；单位像素
FOUNDATION_EXPORT kFFPlayer0x16InfoKey kFFPlayer0x16Width;
//视频高；单位像素
FOUNDATION_EXPORT kFFPlayer0x16InfoKey kFFPlayer0x16Height;

NS_ASSUME_NONNULL_BEGIN
typedef struct AVFrame AVFrame;

@interface FFPlayer0x16 : NSObject

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
///期望的像素格式
@property (nonatomic, assign) MRPixelFormatMask supportedPixelFormats;

@property (nonatomic, copy) void(^onVideoOpened)(NSDictionary *info);
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
