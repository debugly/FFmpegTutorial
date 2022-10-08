//
//  FFTAudioQueueRenderer.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/10/7.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

//Audio Queue Support packet fmt only!

#import <Foundation/Foundation.h>
#import "FFTAudioRendererImpProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface FFTAudioQueueRenderer : NSObject <FFTAudioRendererImpProtocol>

@end

NS_ASSUME_NONNULL_END
