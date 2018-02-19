//
//  MRVideoFrame.h
//  FFmpeg004
//
//  Created by Matt Reach on 2018/1/29.
//  Copyright © 2018年 Awesome FFmpeg Study Demo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <libavutil/frame.h>
#import <CoreMedia/CMSampleBuffer.h>

@interface MRVideoFrame : NSObject

@property (assign, nonatomic) CMSampleBufferRef sampleBuffer;
@property (assign, nonatomic) AVFrame *frame;
@property (assign, nonatomic) float duration;
@property (assign, nonatomic) int linesize;
@property (assign, nonatomic) BOOL eof;

@end
