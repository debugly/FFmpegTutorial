//
//  MRVideoScale.h
//  FFmpegTutorial
//
//  Created by Matt Reach on 2020/6/3.
//
// 像素格式转换类

#import <Foundation/Foundation.h>
#import "FFPlayerHeader.h"

NS_ASSUME_NONNULL_BEGIN

typedef struct AVFrame AVFrame;

@interface MRVideoScale : NSObject

/// @param srcPixFmt 原始图像像素格式
/// @param dstPixFmt 目标图像像素格式
/// @param srcWidth  原始图像宽度
/// @param srcHeight 原始图像高度
/// @param dstWidth  目标图像宽度
/// @param dstHeight 目标图像高度
- (instancetype)initWithSrcPixFmt:(int)srcPixFmt
                        dstPixFmt:(int)dstPixFmt
                         srcWidth:(int)srcWidth
                        srcHeight:(int)srcHeight
                         dstWidth:(int)dstWidth
                        dstHeight:(int)dstHeight;

/// @param inF  需要转换的帧
/// @param outP 转换的结果[不要free相关内存，通过ref/unref的方式使用]
- (BOOL)rescaleFrame:(AVFrame *)inF
            outFrame:(AVFrame *_Nonnull*_Nonnull)outP;

@end

NS_ASSUME_NONNULL_END
