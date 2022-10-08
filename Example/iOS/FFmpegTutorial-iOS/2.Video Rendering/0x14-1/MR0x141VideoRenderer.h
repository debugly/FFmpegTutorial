//
//  MR0x141VideoRenderer.h
//  FFmpegTutorial-iOS
//
//  Created by qianlongxu on 2022/10/1.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreVideo/CVPixelBuffer.h>

typedef enum : NSUInteger {
    MRViewContentModeScaleToFill0x141,
    MRViewContentModeScaleAspectFill0x141,
    MRViewContentModeScaleAspectFit0x141
} MRViewContentMode0x141;

@interface MR0x141VideoRenderer : UIView

@property (nonatomic, assign) BOOL isFullYUVRange;
@property (nonatomic, assign) MRViewContentMode0x141 contentMode;

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;

@end
