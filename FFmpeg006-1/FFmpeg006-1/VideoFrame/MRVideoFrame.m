//
//  MRVideoFrame.m
//  FFmpeg006-1
//
//  Created by Matt Reach on 2017/10/20.
//  Copyright © 2018年 Awesome FFmpeg Study Demo. All rights reserved.
//

#import "MRVideoFrame.h"

@implementation MRVideoFrame

- (void)dealloc
{
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
