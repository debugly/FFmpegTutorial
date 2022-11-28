//
//  MRModernGLViewProtocol.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/11/28.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef struct AVFrame AVFrame;

typedef enum : NSUInteger {
    MRMGLContentModeScaleToFill,
    MRMGLContentModeScaleAspectFill,
    MRMGLContentModeScaleAspectFit
} MRMGLContentMode;

@protocol MRModernGLViewProtocol <NSObject>

@required;
- (void)setContentMode:(MRMGLContentMode)contentMode;
- (MRMGLContentMode)contentMode;
- (void)displayAVFrame:(AVFrame *)frame;

@end

NS_ASSUME_NONNULL_END
