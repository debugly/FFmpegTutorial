//
//  MRGAMViewProtocol.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/11/27.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct AVFrame AVFrame;

typedef enum : NSUInteger {
    MRGAMContentModeScaleToFill,
    MRGAMContentModeScaleAspectFill,
    MRGAMContentModeScaleAspectFit
} MRGAMContentMode;

@protocol MRGAMViewProtocol <NSObject>

@required;
- (void)setContentMode:(MRGAMContentMode)contentMode;
- (MRGAMContentMode)contentMode;
- (void)displayAVFrame:(AVFrame *)frame;

@end

NS_ASSUME_NONNULL_END
