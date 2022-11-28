//
//  MRCoreGraphicsView.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/7/8.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import <CoreGraphics/CGImage.h>
#import "MRGAMViewProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface MRCoreGraphicsView : NSView<MRGAMViewProtocol>

@end

NS_ASSUME_NONNULL_END
