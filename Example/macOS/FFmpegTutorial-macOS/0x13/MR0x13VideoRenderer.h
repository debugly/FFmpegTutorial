//
//  MR0x13VideoRenderer.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/7/11.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreMedia/CMSampleBuffer.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    MRViewContentModeScaleToFill,
    MRViewContentModeScaleAspectFill,
    MRViewContentModeScaleAspectFit
} MRViewContentMode;

@interface MR0x13VideoRenderer : NSView

- (void)setContentMode:(MRViewContentMode)contentMode;
- (MRViewContentMode)contentMode;
- (void)enqueueSampleBuffer:(CMSampleBufferRef)buffer;
- (void)cleanScreen;

@end

NS_ASSUME_NONNULL_END
