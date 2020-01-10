//
//  MRConvertUtil.h
//  FFmpeg006-1
//
//  Created by Matt Reach on 2019/1/25.
//  Copyright © 2019 Awesome FFmpeg Study Demo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreVideo/CVPixelBuffer.h>
#import <CoreMedia/CMSampleBuffer.h>

@interface MRConvertUtil : NSObject

//黑白电视机雪花屏
+ (CVPixelBufferRef)snowPixelBuffer:(int)w h:(int)h opt:(CVPixelBufferPoolRef)poolRef;
//黑白色阶图
+ (CVPixelBufferRef)grayColorBarPixelBuffer:(int)w h:(int)h opt:(CVPixelBufferPoolRef)poolRef;

+ (UIImage *)imageFromCVPixelBuffer:(CVPixelBufferRef)pixelBuffer w:(int)w h:(int)h;

+ (CMSampleBufferRef)cmSampleBufferRefFromCVPixelBufferRef:(CVPixelBufferRef)pixelBuffer;

@end
