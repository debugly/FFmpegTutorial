//
//  MR0x157VideoRenderer.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/1/24.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MR0x141VideoRendererProtocol.h"

typedef struct AVFrame AVFrame;
NS_ASSUME_NONNULL_BEGIN

@interface MR0x157VideoRenderer : NSOpenGLView<MR0x141VideoRendererProtocol>
//画面原始尺寸；
@property (assign) CGSize videoSize;

- (void)displayAVFrame:(AVFrame *)frame;
- (NSImage *)snapshot;

@end

NS_ASSUME_NONNULL_END
