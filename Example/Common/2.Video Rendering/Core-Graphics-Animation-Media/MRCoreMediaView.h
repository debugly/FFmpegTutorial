//
//  MRCoreMediaView.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/7/11.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MRCrossPlatformUtil.h"
#import <CoreMedia/CMSampleBuffer.h>
#import "MRVideoRenderingProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface MRCoreMediaView : NSView<MRVideoRenderingProtocol>

- (void)cleanScreen;

@end

NS_ASSUME_NONNULL_END
