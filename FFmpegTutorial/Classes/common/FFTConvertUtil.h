//
//  FFTConvertUtil.h
//  FFmpegTutorial
//
//  Created by Matt Reach on 2020/6/3.
//
// AVFrame 转换工具类

#import <Foundation/Foundation.h>
#import <CoreMedia/CMSampleBuffer.h>
#import <CoreGraphics/CoreGraphics.h>

typedef struct AVFrame AVFrame;

NS_ASSUME_NONNULL_BEGIN

@interface FFTConvertUtil : NSObject

/**
AVFrame to CGImage，pixel fmt support [RGB555BE/RGB555LE/RGB24/ARGB/0RGB/RGBA/RGB0]
*/
+ (CGImageRef _Nullable)cgImageFromRGBFrame:(AVFrame*)frame;

/**
 AVFrame to CIImage，pixel fmt support [ARGB/0RGB/RGBA/RGB0/ABGR/0BGR/BGRA/BGR0]
 注：ABGR/0BGR form iOS 9 supported.
 */
+ (CIImage* )ciImageFromRGB32orBGR32Frame:(AVFrame*)frame;


/// create CVPixelBufferPool
/// @param format AVPixelFormat
/// @param w picture width
/// @param h picture height
/// @param fullRange video-range (luma=[16,235] chroma=[16,240])、full-range (luma=[0,255] chroma=[1,255]).
+ (CVPixelBufferPoolRef _Nullable)createCVPixelBufferPoolRef:(const int)format w:(const int)w h:(const int)h fullRange:(const bool)fullRange;

/**
AVFrame to CVPixelBuffer，pixel fmt support [RGB24/ARGB/0RGB/BGRA/BGR0/NV12/NV21]
注：内部会将 NV21 软排为 NV12.
*/
+ (CVPixelBufferRef _Nullable)pixelBufferFromAVFrame:(AVFrame*)frame opt:(CVPixelBufferPoolRef _Nullable)poolRef;

+ (CMSampleBufferRef)cmSampleBufferRefFromCVPixelBufferRef:(CVPixelBufferRef)pixelBuffer;

#if TARGET_OS_IOS
///截取原视频画面
+ (UIImage *)snapshot:(GLint)renderbuffer scale:(CGFloat)scale;
#else
///截取当前屏幕显示的画面
+ (NSImage *)snapshot:(NSOpenGLContext *)openGLContext size:(CGSize)size;
///截取原视频画面
+ (NSImage *)snapshotFBO:(GLint)renderbuffer size:(CGSize)size;
#endif

//黑白电视机雪花屏
+ (CVPixelBufferRef)snowPixelBuffer:(int)w h:(int)h opt:(CVPixelBufferPoolRef)poolRef;
//黑白色阶图
+ (CVPixelBufferRef)grayColorBarPixelBuffer:(int)w h:(int)h barNum:(int)barNum opt:(CVPixelBufferPoolRef)poolRef;
//三个小球
+ (CVPixelBufferRef)ball3PixelBuffer:(int)w h:(int)h opt:(CVPixelBufferPoolRef)poolRef;

@end

NS_ASSUME_NONNULL_END
