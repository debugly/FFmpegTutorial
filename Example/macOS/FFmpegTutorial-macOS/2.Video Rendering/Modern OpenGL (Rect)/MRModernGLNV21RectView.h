//
//  MRModernGLNV21RectView.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/1/19.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MRModernGLRectViewProtocol.h"

typedef struct AVFrame AVFrame;
NS_ASSUME_NONNULL_BEGIN

@interface MRModernGLNV21RectView : NSOpenGLView<MRModernGLRectViewProtocol>

- (void)displayAVFrame:(AVFrame *)frame;

@end

NS_ASSUME_NONNULL_END
