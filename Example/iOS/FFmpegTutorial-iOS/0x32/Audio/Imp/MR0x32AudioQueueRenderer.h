//
//  MR0x32AudioQueueRenderer.h
//  FFmpegTutorial-iOS
//
//  Created by Matt Reach on 2020/8/4.
//  Copyright © 2020 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//
//Audio Queue support packet fmt only!

#import <Foundation/Foundation.h>
#import "MR0x32AudioRendererImpProtocol.h"

NS_ASSUME_NONNULL_BEGIN

@interface MR0x32AudioQueueRenderer : NSObject <MR0x32AudioRendererImpProtocol>

@end

NS_ASSUME_NONNULL_END
