//
//  MRLegacyGLNV21View.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/8/2.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Cocoa/Cocoa.h>
#import "MRLegacyGLViewProtocol.h"

typedef struct AVFrame AVFrame;

NS_ASSUME_NONNULL_BEGIN

@interface MRLegacyGLNV21View : NSOpenGLView<MRLegacyGLViewProtocol>

- (void)displayAVFrame:(AVFrame *)frame;

@end

NS_ASSUME_NONNULL_END
