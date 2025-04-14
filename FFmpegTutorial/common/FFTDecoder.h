//
//  FFTDecoder.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/7/27.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//
// 自定义解码器类
// 通过代理衔接输入输出

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct AVStream AVStream;
typedef struct AVFormatContext AVFormatContext;
typedef struct AVPacket AVPacket;
typedef struct AVFrame AVFrame;
typedef struct AVRational AVRational;

@class FFTDecoder;
@protocol FFTDecoderDelegate <NSObject>

@required
///将解码后的 AVFrame 给 delegater
- (void)decoder:(FFTDecoder *)decoder reveivedAFrame:(AVFrame *)frame;
@optional
- (void)decoderEof:(FFTDecoder *)decoder;

@end

@interface FFTDecoder : NSObject

@property (nonatomic, assign) AVFormatContext *ic;
@property (nonatomic, assign) int streamIdx;
@property (nonatomic, copy) NSString * name;
@property (nonatomic, weak) id <FFTDecoderDelegate> delegate;
@property (nonatomic, assign, readonly) AVStream * stream;
//for video is enum AVPixelFormat,for audio is enum AVSampleFormat,
@property (nonatomic, assign, readonly) int format;
@property (nonatomic, assign, readonly) int picWidth;
@property (nonatomic, assign, readonly) int picHeight;
@property (nonatomic, assign, readonly) AVRational frameRate;
@property (nonatomic, assign, readonly) int sampleRate;
@property (nonatomic, assign, readonly) int channelLayout;
/**
 打开解码器，创建解码线程;
 return 0;（没有错误）
 */
- (int)open;
- (int)sendPacket:(AVPacket *)pkt;

@end


NS_ASSUME_NONNULL_END
