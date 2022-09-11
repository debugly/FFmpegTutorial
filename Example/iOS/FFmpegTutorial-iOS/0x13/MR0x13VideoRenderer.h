//
//  MR0x13VideoRenderer.h
//  FFmpegTutorial-iOS
//
//  Created by Matt Reach on 2022/9/11.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreMedia/CMSampleBuffer.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    MRViewContentModeScaleToFill,
    MRViewContentModeScaleAspectFill,
    MRViewContentModeScaleAspectFit
} MRViewContentMode;

@interface MR0x13VideoRenderer : UIView

- (void)enqueueSampleBuffer:(CMSampleBufferRef)buffer;
- (void)cleanScreen;

- (void)setContentMode:(MRViewContentMode)contentMode;
- (MRViewContentMode)contentMode;

@end

NS_ASSUME_NONNULL_END
