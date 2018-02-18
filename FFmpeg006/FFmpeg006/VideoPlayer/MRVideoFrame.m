//
//  MRVideoFrame.m
//  FFmpeg004
//
//  Created by Matt Reach on 2018/1/20.
//  Copyright © 2018年 Awesome FFmpeg Study Demo. All rights reserved.
//

#import "MRVideoFrame.h"

@implementation MRVideoFrame

- (void)setFrame:(AVFrame *)frame
{
    if (frame != _frame) {
        if (_frame) {
            av_frame_free(&_frame);
        }
        _frame = av_frame_clone(frame);
    }
}

- (void)dealloc
{
    if (_frame) {
        av_frame_free(&_frame);
    }
}

@end
