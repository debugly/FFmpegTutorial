//
//  MRVideoFrame.m
//  FFmpeg006
//
//  Created by Matt Reach on 2017/10/20.
//  Copyright © 2018年 Awesome FFmpeg Study Demo. All rights reserved.
//

#import "MRVideoFrame.h"

@implementation MRVideoFrame

- (void)dealloc
{
    if (_video_frame) {
        //用完后记得释放掉
        av_frame_free(&_video_frame);
        _video_frame = NULL;
    }
    if (_sampleBuffer) {
        CFRelease(_sampleBuffer);
        _sampleBuffer = NULL;
    }
}

- (void)setSampleBuffer:(CMSampleBufferRef)sampleBuffer
{
    if (sampleBuffer != _sampleBuffer) {
        if (_sampleBuffer) {
            CFRelease(sampleBuffer);
        }
        CFRetain(sampleBuffer);
        _sampleBuffer = sampleBuffer;
    }
}

@end
