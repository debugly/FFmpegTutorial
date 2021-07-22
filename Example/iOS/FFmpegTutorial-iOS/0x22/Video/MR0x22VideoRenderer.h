//
//  MR0x22VideoRenderer.h
//  FFmpegTutorial-iOS
//
//  Created by qianlongxu on 2020/7/16.
//  Copyright © 2020 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreVideo/CVPixelBuffer.h>

@interface MR0x22VideoRenderer : UIView

@property (nonatomic, assign) BOOL isFullYUVRange;

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;

@end
