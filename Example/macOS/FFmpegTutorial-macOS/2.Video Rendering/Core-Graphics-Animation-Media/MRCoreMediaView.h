//
//  MRCoreMediaView.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/7/11.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreMedia/CMSampleBuffer.h>
#import "MRGAMVideoRendererProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface MRCoreMediaView : NSView<MRGAMVideoRendererProtocol>

- (void)cleanScreen;

@end

NS_ASSUME_NONNULL_END
