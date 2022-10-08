//
//  FFTAudioFrameQueue.m
//  FFmpegTutorial
//
//  Created by qianlongxu on 2022/10/6.
//

#import "FFTAudioFrameQueue.h"
#import "FFTPlayerHeader.h"
#import <libavutil/frame.h>

@interface FFTAudioFrameQueue()
{
    //音频frame已经读的数据
    int _audioFrameRead;
}
@end

@implementation FFTAudioFrameQueue

- (void)enQueue:(AVFrame *)frame
{
    FFFrameItem *item = [[FFFrameItem alloc] initWithAVFrame:frame];

    if (frame->pts != AV_NOPTS_VALUE) {
        AVRational tb = (AVRational){1, frame->sample_rate};
        item.pts = frame->pts * av_q2d(tb);
    }
    
    item.duration = av_q2d((AVRational){frame->nb_samples, frame->sample_rate});
    
    [self push:item];
}

- (int)doFillAudioBuffers:(uint8_t * [2])buffer
                 byteSize:(int)bufferSize
{
    FFFrameItem *item = [self peek];
    if (!item) {
        return 0;
    }
    AVFrame *frame = item.frame;
    int data_size = audio_buffer_size(frame);
    int leave = data_size - _audioFrameRead;
    if (leave <= 0) {
        _audioFrameRead = 0;
        [self pop];
        return 0;
    }
    
    int cpSize = MIN(bufferSize,leave);
    
    for (int i = 0; i < 2; i++) {
        uint8_t *dst = buffer[i];
        if (NULL != dst) {
            uint8_t *src = (uint8_t *)(frame->data[i]) + _audioFrameRead;
            memcpy(dst, src, cpSize);
        } else {
            break;
        }
    }
    _audioFrameRead += cpSize;
    
    if (data_size - _audioFrameRead <= 0) {
        _audioFrameRead = 0;
        [self pop];
    }
    
    return cpSize;
}

- (double)clock
{
    FFFrameItem *item = [self peek];
    if (!item) {
        return [self peekLast].pts;
    }
    
    AVFrame *frame = item.frame;
    int data_size = audio_buffer_size(frame);
    float percent = 1.0 * _audioFrameRead / data_size;
    double audio_clock = item.pts + percent * item.frame->nb_samples / item.frame->sample_rate;
    //double bytes_per_sec = self.supportedSampleRate * self.audioClk.bytesPerSample;
    //double audio_clock = audio_pts - 2.0 * (ap->offset + filled) / bytes_per_sec;
    return audio_clock;
}

- (int)fillBuffers:(uint8_t * _Nonnull [_Nullable 2])buffer
          byteSize:(int)bufferSize
{
    int totalFilled = 0;
    while (bufferSize > 0) {
        int filled = [self doFillAudioBuffers:buffer byteSize:bufferSize];
        if (filled) {
            totalFilled += filled;
            bufferSize -= filled;
        } else {
            break;
        }
    }
    return totalFilled;
}

@end
