//
//  MRVideoFrame.m
//  FFmpeg003
//
//  Created by Matt Reach on 2017/10/20.
//  Copyright © 2018年 Awesome FFmpeg Study Demo. All rights reserved.
//

#import "MRVideoFrame.h"

@implementation MRVideoFrame

- (void)dealloc
{
    if (self.video_frame) {
        //用完后记得释放掉
        av_frame_free(&self->_video_frame);
        self.video_frame = NULL;
    }
}

@end
