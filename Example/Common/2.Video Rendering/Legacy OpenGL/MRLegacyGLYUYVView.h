//
//  MRLegacyGLYUYVView.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/7/11.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MRVideoRenderingProtocol.h"

typedef struct AVFrame AVFrame;

NS_ASSUME_NONNULL_BEGIN

@interface MRLegacyGLYUYVView : NSOpenGLView<MRVideoRenderingProtocol>

- (void)displayAVFrame:(AVFrame *)frame;

@end

NS_ASSUME_NONNULL_END
