//
//  MR0x151VideoRenderer.h
//  FFmpegTutorial-iOS
//
//  Created by qianlongxu on 2020/7/10.
//  Copyright © 2020 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreVideo/CVPixelBuffer.h>

typedef enum : NSUInteger {
    MRViewContentModeScaleToFill0x151,
    MRViewContentModeScaleAspectFill0x151,
    MRViewContentModeScaleAspectFit0x151
} MRViewContentMode0x151;

@interface MR0x151VideoRenderer : UIView

@property (nonatomic, assign) BOOL isFullYUVRange;
@property (nonatomic, assign) MRViewContentMode0x151 contentMode;

- (void)displayPixelBuffer:(CVPixelBufferRef)pixelBuffer;

@end
