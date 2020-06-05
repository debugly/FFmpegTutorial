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

+ (CGImageRef)cgImageFromRGBFrame:(AVFrame*)frame;
+ (CVPixelBufferRef)pixelBufferFromAVFrame:(AVFrame*)frame;
+ (CVPixelBufferRef)pixelBufferFromAVFrame:(AVFrame*)frame opt:(CVPixelBufferPoolRef _Nullable)poolRef;

@end

NS_ASSUME_NONNULL_END
