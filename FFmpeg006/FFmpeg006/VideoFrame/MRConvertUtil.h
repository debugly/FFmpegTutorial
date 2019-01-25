//
//  MRConvertUtil.h
//  FFmpeg006
//
//  Created by Matt Reach on 2019/1/25.
//  Copyright © 2019 Awesome FFmpeg Study Demo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreVideo/CVPixelBuffer.h>
#import <libavutil/frame.h>
#import <CoreMedia/CMSampleBuffer.h>

@interface MRConvertUtil : NSObject

+ (CVPixelBufferRef)pixelBufferFromAVFrame:(AVFrame*)pFrame w:(int)w h:(int)h;
+ (CVPixelBufferRef)pixelBufferFromAVFrame:(AVFrame*)pFrame w:(int)w h:(int)h opt:(CVPixelBufferPoolRef)poolRef;

+ (UIImage *)imageFromCVPixelBuffer:(CVPixelBufferRef)pixelBuffer w:(int)w h:(int)h;

+ (UIImage *)imageFromAVFrame:(AVFrame*)video_frame w:(int)w h:(int)h;

+ (UIImage *)imageFromAVFrameV2:(AVFrame*)video_frame w:(int)w h:(int)h;

+ (CMSampleBufferRef)cmSampleBufferRefFromCVPixelBufferRef:(CVPixelBufferRef)pixelBuffer;

@end
