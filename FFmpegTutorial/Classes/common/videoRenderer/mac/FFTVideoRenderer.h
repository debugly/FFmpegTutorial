//
//  FFTVideoRenderer.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/10/6.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "FFTVideoRendererProtocol.h"

typedef struct AVFrame AVFrame;
NS_ASSUME_NONNULL_BEGIN

@interface FFTVideoRenderer : NSOpenGLView<FFTVideoRendererProtocol>
//画面原始尺寸；
@property (assign) CGSize videoSize;

- (void)displayAVFrame:(AVFrame *)frame;
- (NSImage *)snapshot;

@end

NS_ASSUME_NONNULL_END
