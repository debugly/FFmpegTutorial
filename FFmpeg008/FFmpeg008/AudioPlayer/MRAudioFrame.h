//
//  MRAudioFrame.h
//  FFmpeg008
//
//  Created by Matt Reach on 2018/2/21.
//  Copyright © 2018年 Awesome FFmpeg Study Demo. All rights reserved.
//  开源地址: https://github.com/debugly/StudyFFmpeg
//

#import <Foundation/Foundation.h>
#import <libavcodec/avcodec.h>

@interface MRAudioFrame : NSObject

@property (assign, nonatomic) AVPacket *packet;
@property (assign, nonatomic) AVFrame  *frame;
@property (assign, nonatomic) float position;
@property (assign, nonatomic) float duration;
@property (nonatomic, strong) NSData *samples;
@property (assign, nonatomic) BOOL eof;

@end
