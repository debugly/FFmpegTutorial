//
//  MR0x0aVideoRenderer.h
//  FFmpegTutorial-iOS
//
//  Created by Matt Reach on 2020/6/8.
//  Copyright © 2020 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreMedia/CMSampleBuffer.h>

NS_ASSUME_NONNULL_BEGIN

@interface MR0x0aVideoRenderer : UIView

- (void)enqueueSampleBuffer:(CMSampleBufferRef)buffer;
- (void)cleanScreen;

@end

NS_ASSUME_NONNULL_END
