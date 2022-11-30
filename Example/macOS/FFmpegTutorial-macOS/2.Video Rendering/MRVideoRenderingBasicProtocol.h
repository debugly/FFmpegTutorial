//
//  MRVideoRenderingBasicProtocol.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/11/29.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef enum : NSUInteger {
    MRContentModeScaleToFill,
    MRContentModeScaleAspectFill,
    MRContentModeScaleAspectFit
} MRContentMode;

@protocol MRVideoRenderingBasicProtocol <NSObject>

@required;
- (void)setContentMode:(MRContentMode)contentMode;
- (MRContentMode)contentMode;

@end

NS_ASSUME_NONNULL_END
