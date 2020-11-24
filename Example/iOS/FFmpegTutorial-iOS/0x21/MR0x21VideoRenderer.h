//
//  MR0x21VideoRenderer.h
//  FFmpegTutorial-iOS
//
//  Created by qianlongxu on 2020/7/14.
//  Copyright © 2020 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreVideo/CVPixelBuffer.h>

@interface MR0x21VideoRenderer : UIView

@property (nonatomic, assign) BOOL isFullYUVRange;

- (void)setupGL;
- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;

@end
