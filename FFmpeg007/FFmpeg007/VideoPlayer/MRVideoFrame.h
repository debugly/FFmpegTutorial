//
//  MRVideoFrame.h
//  FFmpeg007
//
//  Created by Matt Reach on 2018/2/10.
//  Copyright © 2018年 Awesome FFmpeg Study Demo. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <libavutil/frame.h>
#import <libavcodec/avcodec.h>

@interface MRVideoFrame : NSObject

@property (assign, nonatomic) AVPacket *packet;
@property (assign, nonatomic) AVFrame *frame;
@property (assign, nonatomic) float duration;
@property (assign, nonatomic) BOOL eof;

@end
