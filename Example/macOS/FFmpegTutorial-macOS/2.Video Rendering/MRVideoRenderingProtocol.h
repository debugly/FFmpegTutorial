//
//  MRVideoRenderingProtocol.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/11/29.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MRVideoRenderingBasicProtocol.h"

NS_ASSUME_NONNULL_BEGIN
typedef struct AVFrame AVFrame;

@protocol MRVideoRenderingProtocol <MRVideoRenderingBasicProtocol>

@required;
- (void)displayAVFrame:(AVFrame *)frame;

@end

NS_ASSUME_NONNULL_END
