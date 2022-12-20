//
//  MRPacketQueueViewController.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/12/10.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//
// 增加 packet queue，创建解码线程;
// 上层代码没改动，具体改动在 FFTPlayer0x31 里。

#import "MRCrossPlatformUtil.h"

NS_ASSUME_NONNULL_BEGIN

@interface MRPacketQueueViewController : MRBaseViewController

@end

NS_ASSUME_NONNULL_END
