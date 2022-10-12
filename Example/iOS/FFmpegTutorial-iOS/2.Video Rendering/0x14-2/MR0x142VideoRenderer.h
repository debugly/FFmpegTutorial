//
//  MR0x142VideoRenderer.h
//  FFmpegTutorial-iOS
//
//  Created by qianlongxu on 2022/10/1.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreVideo/CVPixelBuffer.h>

typedef enum : NSUInteger {
    MRViewContentModeScaleToFill0x142,
    MRViewContentModeScaleAspectFill0x142,
    MRViewContentModeScaleAspectFit0x142
} MRViewContentMode0x142;

@interface MR0x142VideoRenderer : UIView

@property (nonatomic, assign) BOOL isFullYUVRange;
@property (nonatomic, assign) MRViewContentMode0x142 contentMode;

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;

@end
