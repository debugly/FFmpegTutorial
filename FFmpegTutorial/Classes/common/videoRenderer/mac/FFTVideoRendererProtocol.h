//
//  MRViewVideoRendererProtocol.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/7/26.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    FFTRenderingModeScaleToFill,
    FFTRenderingModeScaleAspectFill,
    FFTRenderingModeScaleAspectFit
} FFTRenderingMode;

@protocol FFTVideoRendererProtocol <NSObject>

@required;
- (void)setRenderingMode:(FFTRenderingMode)renderingMode;;
- (FFTRenderingMode)renderingMode;

@end

NS_ASSUME_NONNULL_END
