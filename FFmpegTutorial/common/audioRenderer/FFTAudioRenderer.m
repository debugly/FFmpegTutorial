//
//  FFTAudioRenderer.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/10/7.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "FFTAudioRenderer.h"
#import <AVFoundation/AVFoundation.h>
#import "FFTAudioQueueRenderer.h"
#import "FFTAudioUnitRenderer.h"

//将音频裸流PCM写入到文件
#define DEBUG_RECORD_PCM_TO_FILE 0

@interface FFTAudioRenderer ()
{
    float _outputVolume;
#if DEBUG_RECORD_PCM_TO_FILE
    FILE * file_pcm_l;
    FILE * file_pcm_r;
#endif
}

@property (nonatomic, assign, readwrite) MRSampleFormat sampleFmt;
@property (nonatomic, assign, readwrite) BOOL preferredAudioQueue;
@property (nonatomic, strong) id<FFTAudioRendererImpProtocol> audioRendererImp;

@end

@implementation FFTAudioRenderer

@synthesize outputVolume = _outputVolume;

- (void)dealloc
{
    [self.audioRendererImp stop];
    self.audioRendererImp = nil;
#if DEBUG_RECORD_PCM_TO_FILE
    if (NULL != file_pcm_l) {
        fclose(file_pcm_l);
        file_pcm_l = NULL;
    }
    if (NULL != file_pcm_r) {
        fclose(file_pcm_r);
        file_pcm_r = NULL;
    }
#endif
}

- (instancetype)initWithFmt:(MRSampleFormat)fmt
        preferredAudioQueue:(BOOL)preferredAudioQueue
                 sampleRate:(int)sampleRate
{
    self = [super init];
    if (self) {
        self.sampleFmt = fmt;
        self.preferredAudioQueue = preferredAudioQueue;
        //优先使用audiounit，只有明确选择 audio queue 并且格式支持时才用 audio queue！
        if (self.preferredAudioQueue) {
            if (MR_Sample_Fmt_Is_Packet(fmt)) {
                self.audioRendererImp = [[FFTAudioQueueRenderer alloc] init];
            } else {
                NSLog(@"audio queue not support planar fmt, will use audio unit!");
            }
        }
        
        if (!self.audioRendererImp) {
            self.audioRendererImp = [[FFTAudioUnitRenderer alloc] init];
        }
        [self.audioRendererImp setupAudioRender:fmt sampleRate:sampleRate];
    }
    return self;
}

- (NSString *)name
{
    return [self.audioRendererImp name];
}

- (void)onFetchSamples:(MRFetchSamples)block
{
    [self.audioRendererImp onFetchSamples:block];
}

- (void)play
{
    [self.audioRendererImp play];
}

- (void)pause
{
    [self.audioRendererImp pause];
}

- (void)stop
{
    [self.audioRendererImp stop];
}

- (float)outputVolume
{
    return 1.0;
}

- (void)setOutputVolume:(float)outputVolume
{
    _outputVolume = outputVolume;
}

@end
