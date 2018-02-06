//
//  MRVideoFrame.h
//  FFmpeg004
//
//  Created by Matt Reach on 2018/1/29.
//  Copyright © 2018年 Awesome FFmpeg Study Demo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <libavutil/frame.h>

@interface MRVideoFrame : NSObject

@property (assign, nonatomic) float duration;
@property (assign, nonatomic) AVFrame *frame;

@end
