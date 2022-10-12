//
//  MR0x11VideoRenderer.h
//  FFmpegTutorial-iOS
//
//  Created by Matt Reach on 2020/6/5.
//  Copyright © 2020 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <CoreGraphics/CGImage.h>

NS_ASSUME_NONNULL_BEGIN

@interface MR0x11VideoRenderer : UIView

- (void)dispalyCGImage:(CGImageRef)img;

@end

NS_ASSUME_NONNULL_END
