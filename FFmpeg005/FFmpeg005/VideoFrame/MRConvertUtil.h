//
//  MRConvertUtil.h
//  FFmpeg005
//
//  Created by Matt Reach on 2019/1/25.
//  Copyright © 2019 Awesome FFmpeg Study Demo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <CoreVideo/CVPixelBuffer.h>
#import <libavutil/frame.h>

NS_ASSUME_NONNULL_BEGIN

@interface MRConvertUtil : NSObject

+ (CVPixelBufferRef)pixelBufferFromAVFrame:(AVFrame*)pFrame w:(int)w h:(int)h;

+ (UIImage *)imageFromCVPixelBuffer:(CVPixelBufferRef)pixelBuffer w:(int)w h:(int)h;

+ (UIImage *)imageFromAVFrame:(AVFrame*)video_frame w:(int)w h:(int)h;

+ (UIImage *)imageFromAVFrameV2:(AVFrame*)video_frame w:(int)w h:(int)h;
@end

NS_ASSUME_NONNULL_END
