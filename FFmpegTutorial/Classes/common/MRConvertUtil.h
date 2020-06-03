//
//  MRConvertUtil.h
//  FFmpegTutorial
//
//  Created by Matt Reach on 2020/6/3.
//
// AVFrame 转换工具类

#import <Foundation/Foundation.h>

typedef struct AVFrame AVFrame;
NS_ASSUME_NONNULL_BEGIN

@interface MRConvertUtil : NSObject

+ (UIImage *)imageFromRGB24Frame:(AVFrame*)frame;

@end

NS_ASSUME_NONNULL_END
