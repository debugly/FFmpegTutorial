//
//  FFTAudioUnitRenderer.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/10/7.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "FFTAudioRendererImpProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface FFTAudioUnitRenderer : NSObject <FFTAudioRendererImpProtocol>

@end

NS_ASSUME_NONNULL_END
