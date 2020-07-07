//
//  MR0x0bVideoRenderer.h
//  FFmpegTutorial-iOS
//
//  Created by Matt Reach on 2020/6/25.
//  Copyright © 2020 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <UIKit/UIKit.h>
#import <FFmpegTutorial/FFPlayerHeader.h>

NS_ASSUME_NONNULL_BEGIN

@interface MR0x0bVideoRenderer : UIView

- (void)displayYUV420pPicture:(MRPicture *)pframe;
/**
 清屏
 */
- (void)cleanScreen;

@end

NS_ASSUME_NONNULL_END
