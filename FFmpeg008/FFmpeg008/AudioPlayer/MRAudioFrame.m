//
//  MRAudioFrame.m
//  FFmpeg008
//
//  Created by Matt Reach on 2018/2/21.
//  Copyright © 2018年 Awesome FFmpeg Study Demo. All rights reserved.
//  开源地址: https://github.com/debugly/StudyFFmpeg
//

#import "MRAudioFrame.h"

@implementation MRAudioFrame

- (void)setFrame:(AVFrame *)frame
{
    if (frame != _frame) {
        if (_frame) {
            av_frame_unref(_frame);
        }else{
            _frame = av_frame_alloc();
        }
        if (frame) {
            av_frame_ref(_frame, frame);
        }
    }
}

- (void)setPacket:(AVPacket *)packet
{
    if (packet != _packet) {
        if (_packet) {
            av_packet_unref(_packet);
        }else{
            _packet = malloc(sizeof(AVPacket));
            av_init_packet(_packet);
        }
        if (packet) {
            av_packet_ref(_packet, packet);
        }
    }
}

- (void)dealloc
{
    if (_frame) {
        av_frame_free(&_frame);
    }
    
    if (_packet) {
        av_packet_unref(_packet);
        free(_packet);
    }
}

@end
