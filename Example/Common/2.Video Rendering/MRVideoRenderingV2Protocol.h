//
//  MRVideoRenderingV2Protocol.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/11/29.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//
// 

#import "MRVideoRenderingBasicProtocol.h"
#import <CoreVideo/CVPixelBuffer.h>

NS_ASSUME_NONNULL_BEGIN

@protocol MRVideoRenderingV2Protocol <MRVideoRenderingBasicProtocol>

@required;
- (void)displayPixelBuffer:(CVPixelBufferRef)img;
- (void)displayNV21PixelBuffer:(CVPixelBufferRef)img;

@end

NS_ASSUME_NONNULL_END
