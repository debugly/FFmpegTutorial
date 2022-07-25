//
//  FFDecoder0x34.h
//  FFmpegTutorial
//
//  Created by Matt Reach on 2022/7/25.
//
// 自定义解码器类
// 通过代理衔接输入输出

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct AVStream AVStream;
typedef struct AVFormatContext AVFormatContext;
typedef struct AVPacket AVPacket;
typedef struct AVFrame AVFrame;

@class FFDecoder0x34;
@protocol FFDecoderDelegate0x34 <NSObject>

@required
///将解码后的 AVFrame 给 delegater
- (void)decoder:(FFDecoder0x34 *)decoder reveivedAFrame:(AVFrame *)frame;

@end

@interface FFDecoder0x34 : NSObject

@property (nonatomic, assign) AVFormatContext *ic;
@property (nonatomic, assign) int streamIdx;
@property (nonatomic, copy) NSString * name;
@property (nonatomic, weak) id <FFDecoderDelegate0x34> delegate;
@property (nonatomic, assign, readonly) AVStream * stream;
//for video is enum AVPixelFormat,for audio is enum AVSampleFormat,
@property (nonatomic, assign, readonly) int format;
@property (nonatomic, assign, readonly) int picWidth;
@property (nonatomic, assign, readonly) int picHeight;

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
