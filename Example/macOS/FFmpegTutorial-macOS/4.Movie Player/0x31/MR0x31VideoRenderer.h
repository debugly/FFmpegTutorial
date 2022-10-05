//
//  MR0x31VideoRenderer.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/7/16.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MRVideoRendererProtocol.h"

typedef struct AVFrame AVFrame;
NS_ASSUME_NONNULL_BEGIN

@interface MR0x31VideoRenderer : NSOpenGLView<MRVideoRendererProtocol>
//画面原始尺寸；
@property (assign) CGSize videoSize;

- (void)displayAVFrame:(AVFrame *)frame;
- (NSImage *)snapshot;

@end

NS_ASSUME_NONNULL_END
