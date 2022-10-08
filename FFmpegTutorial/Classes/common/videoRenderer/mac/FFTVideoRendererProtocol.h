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
    MRViewContentModeScaleToFill,
    MRViewContentModeScaleAspectFill,
    MRViewContentModeScaleAspectFit
} MRViewContentMode;

@protocol FFTVideoRendererProtocol <NSObject>

@required;
- (void)setContentMode:(MRViewContentMode)contentMode;
- (MRViewContentMode)contentMode;

@end

NS_ASSUME_NONNULL_END
