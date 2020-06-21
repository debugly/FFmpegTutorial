//
//  MRConvertUtil.h
//  FFmpegTutorial
//
//  Created by Matt Reach on 2020/6/3.
//
// AVFrame 转换工具类

#import <Foundation/Foundation.h>
#import <CoreMedia/CMSampleBuffer.h>

typedef struct AVFrame AVFrame;

NS_ASSUME_NONNULL_BEGIN

@interface MRConvertUtil : NSObject

+ (CGImageRef)cgImageFromRGBFrame:(AVFrame*)frame;
+ (CIImage* )ciImageFromFrame:(AVFrame*)frame;
+ (CVPixelBufferRef _Nullable)pixelBufferFromAVFrame:(AVFrame*)frame;
+ (CVPixelBufferRef _Nullable)pixelBufferFromAVFrame:(AVFrame*)frame opt:(CVPixelBufferPoolRef _Nullable)poolRef;
+ (CMSampleBufferRef)cmSampleBufferRefFromCVPixelBufferRef:(CVPixelBufferRef)pixelBuffer;
@end

NS_ASSUME_NONNULL_END
