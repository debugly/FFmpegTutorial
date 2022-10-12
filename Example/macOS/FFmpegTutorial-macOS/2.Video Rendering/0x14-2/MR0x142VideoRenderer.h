//
//  MR0x142VideoRenderer.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/8/1.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MR0x141VideoRendererProtocol.h"

typedef struct AVFrame AVFrame;

NS_ASSUME_NONNULL_BEGIN

@interface MR0x142VideoRenderer : NSOpenGLView<MR0x141VideoRendererProtocol>

- (void)displayAVFrame:(AVFrame *)frame;

@end

NS_ASSUME_NONNULL_END
