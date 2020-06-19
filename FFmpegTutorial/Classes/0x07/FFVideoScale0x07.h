//
//  FFVideoScale0x07.h
//  FFmpegTutorial
//
//  Created by Matt Reach on 2020/6/3.
//
// 像素格式转换类

#import <Foundation/Foundation.h>
#import "FFPlayerHeader.h"

NS_ASSUME_NONNULL_BEGIN

typedef struct AVFrame AVFrame;

@interface FFVideoScale0x07 : NSObject

/// @param srcPixFmt 原帧像素格式
/// @param dstPixFmt 目标帧像素格式
/// @param picWidth  图像宽度
/// @param picHeight 图像高度
- (instancetype)initWithSrcPixFmt:(int)srcPixFmt
                        dstPixFmt:(int)dstPixFmt
                         picWidth:(int)picWidth
                        picHeight:(int)picHeight;

/// @param inF  需要转换的帧
/// @param outP 转换的结果[不要free相关内存，通过ref/unref的方式使用]
- (BOOL) rescaleFrame:(AVFrame *)inF out:(AVFrame *_Nonnull*_Nonnull)outP;

@end

NS_ASSUME_NONNULL_END
