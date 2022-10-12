//
//  MR0x144VideoRenderer.h
//  FFmpegTutorial-iOS
//
//  Created by qianlongxu on 2022/10/1.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreVideo/CVPixelBuffer.h>

typedef enum : NSUInteger {
    MRViewContentModeScaleToFill0x144,
    MRViewContentModeScaleAspectFill0x144,
    MRViewContentModeScaleAspectFit0x144
} MRViewContentMode0x144;

@interface MR0x144VideoRenderer : UIView

@property (nonatomic, assign) BOOL isFullYUVRange;
@property (nonatomic, assign) MRViewContentMode0x144 contentMode;

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;

@end
