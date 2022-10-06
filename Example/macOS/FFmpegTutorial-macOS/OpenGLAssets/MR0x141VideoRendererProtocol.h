//
//  MR0x141VideoRendererProtocol.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/7/26.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    MR0x141ContentModeScaleToFill,
    MR0x141ContentModeScaleAspectFill,
    MR0x141ContentModeScaleAspectFit
} MR0x141ContentMode;

@protocol MR0x141VideoRendererProtocol <NSObject>

@required;
- (void)setContentMode:(MR0x141ContentMode)contentMode;
- (MR0x141ContentMode)contentMode;

@end

NS_ASSUME_NONNULL_END
