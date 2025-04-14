//
//  FFTAudioResample.h
//  FFmpegTutorial
//
//  Created by Matt Reach on 2022/7/10.
//
// 音频格式转换类

#import <Foundation/Foundation.h>
#import "FFTPlayerHeader.h"

NS_ASSUME_NONNULL_BEGIN

typedef struct AVFrame AVFrame;

@interface FFTAudioResample : NSObject

@property (nonatomic, assign, readonly) int out_sample_fmt;
@property (nonatomic, assign, readonly) int out_sample_rate;

/// @param srcFmt 原音频格式
/// @param dstFmt 目标音频格式
/// @param srcChannel 原声道数
/// @param dstChannel 目标声道数
/// @param srcRate 原采样率
/// @param dstRate 目标采样率
- (instancetype)initWithSrcSampleFmt:(int)srcFmt
                        dstSampleFmt:(int)dstFmt
                          srcChannel:(int)srcChannel
                          dstChannel:(int)dstChannel
                             srcRate:(int)srcRate
                             dstRate:(int)dstRate;

/// @param inF 需要转换的帧
/// @param outP 转换的结果[不要free相关内存，通过ref/unref的方式使用]
- (BOOL)resampleFrame:(AVFrame *)inF out:(AVFrame *_Nonnull*_Nonnull)outP;

@end

NS_ASSUME_NONNULL_END
