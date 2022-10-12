//
//  MR0x32AudioRenderer.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/9/26.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x32AudioRenderer.h"
#import <AVFoundation/AVFoundation.h>
#import "MR0x32AudioQueueRenderer.h"
#import "MR0x32AudioUnitRenderer.h"

//将音频裸流PCM写入到文件
#define DEBUG_RECORD_PCM_TO_FILE 0

@interface MR0x32AudioRenderer ()
{
    float _outputVolume;
#if DEBUG_RECORD_PCM_TO_FILE
    FILE * file_pcm_l;
    FILE * file_pcm_r;
#endif
}

@property (nonatomic, assign, readwrite) MRSampleFormat sampleFmt;
@property (nonatomic, assign, readwrite) BOOL preferredAudioQueue;
@property (nonatomic, strong) id<MR0x32AudioRendererImpProtocol> audioRendererImp;

@end

@implementation MR0x32AudioRenderer

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
                self.audioRendererImp = [[MR0x32AudioQueueRenderer alloc] init];
            } else {
                NSLog(@"audio queue not support planar fmt, will use audio unit!");
            }
        }
        
        if (!self.audioRendererImp) {
            self.audioRendererImp = [[MR0x32AudioUnitRenderer alloc] init];
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
#warning TODO
    return 1.0;
}

- (void)setOutputVolume:(float)outputVolume
{
    _outputVolume = outputVolume;
}

@end
