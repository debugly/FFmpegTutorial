//
//  MRCoreAnimationView.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/7/9.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MRGAMVideoRendererProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface MRCoreAnimationView : NSImageView <MRGAMVideoRendererProtocol>

@end

NS_ASSUME_NONNULL_END
