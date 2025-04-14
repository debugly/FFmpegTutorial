//
//  FFTVideoScale.h
//  FFmpegTutorial
//
//  Created by Matt Reach on 2020/7/10.
//
// 像素格式转换类

#import <Foundation/Foundation.h>
#import "FFTPlayerHeader.h"

NS_ASSUME_NONNULL_BEGIN

typedef struct AVFrame AVFrame;

@interface FFTVideoScale : NSObject

/// @param src 原帧像素格式
/// @param dest 目标帧像素格式
/// @return YES:可以转换； NO:无法转换
+ (BOOL)checkCanConvertFrom:(int)src to:(int)dest;

/// @param srcPixFmt 原帧像素格式
/// @param dstPixFmt 目标帧像素格式
/// @param picWidth 图像宽度
/// @param picHeight 图像高度
- (instancetype)initWithSrcPixFmt:(int)srcPixFmt
                        dstPixFmt:(int)dstPixFmt
                         picWidth:(int)picWidth
                        picHeight:(int)picHeight;

/// @param inF 需要转换的帧
/// @param outP 转换的结果[不要free相关内存，通过ref/unref的方式使用]
- (BOOL)rescaleFrame:(AVFrame *)inF out:(AVFrame *_Nonnull*_Nonnull)outP;

@end

NS_ASSUME_NONNULL_END
