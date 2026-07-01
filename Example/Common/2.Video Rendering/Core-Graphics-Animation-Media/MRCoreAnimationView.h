//
//  MRCoreAnimationView.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/7/9.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutorial. All rights reserved.
//

#import "MRCrossPlatformUtil.h"
#import "MRVideoRenderingProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface MRCoreAnimationView : NSImageView <MRVideoRenderingProtocol>

@end

NS_ASSUME_NONNULL_END
