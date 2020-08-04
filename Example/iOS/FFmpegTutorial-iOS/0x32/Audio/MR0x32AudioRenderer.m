//
//  MR0x32AudioRenderer.m
//  FFmpegTutorial-iOS
//
//  Created by Matt Reach on 2020/8/4.
//  Copyright © 2020 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
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
@property (nonatomic, strong) id<MR0x32AudioRendererImpProtocol> audioRendererImp;

@end

@implementation MR0x32AudioRenderer

@synthesize outputVolume = _outputVolume;

- (void)dealloc
{
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

+ (int)setPreferredSampleRate:(int)rate
{
    [[AVAudioSession sharedInstance] setPreferredSampleRate:rate error:nil];
    return (int)[[AVAudioSession sharedInstance] sampleRate];
}

- (void)active
{
    [[AVAudioSession sharedInstance]setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker error:nil];
    
    [[AVAudioSession sharedInstance]setActive:YES error:nil];
}

- (void)setupWithFmt:(MRSampleFormat)fmt sampleRate:(int)rate
{
    self.sampleFmt = fmt;
    ///优先使用audiounit，只有明确选择 audio queue 并且格式支持时才用 audio queue！
    if (self.preferredAudioQueue) {
        if (MR_Sample_Fmt_Is_Packet(fmt)) {
            self.audioRendererImp = [[MR0x32AudioQueueRenderer alloc] init];
            [self.audioRendererImp setup:rate isFloatFmt:MR_Sample_Fmt_Is_FloatX(fmt)];
            return;
        } else {
            NSLog(@"audio queue not support planar fmt, will use audio unit!");
        }
    }
    
    self.audioRendererImp = [[MR0x32AudioUnitRenderer alloc] init];
    [self.audioRendererImp setup:rate isFloatFmt:MR_Sample_Fmt_Is_FloatX(fmt) isPacket:MR_Sample_Fmt_Is_Packet(fmt)];
    
#if DEBUG_RECORD_PCM_TO_FILE
    if (file_pcm_l == NULL) {
        const char *l = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"L.pcm"]UTF8String];
        NSLog(@"%s",l);
        file_pcm_l = fopen(l, "wb+");
    }
    
    if (file_pcm_r == NULL) {
        const char *r = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"R.pcm"]UTF8String];
        NSLog(@"%s",r);
        file_pcm_r = fopen(r, "wb+");
    }
#endif

}

- (void)onFetchPacketSample:(MRFetchPacketSample)block
{
#if DEBUG_RECORD_PCM_TO_FILE
    [self.audioRendererImp onFetchPacketSample:^UInt32(uint8_t * _Nonnull buffer, UInt32 bufferSize) {
        if (block) {
            UInt32 filled = block(buffer,bufferSize);
            fwrite(buffer, 1, filled, self->file_pcm_l);
            return filled;
        } else {
            return 0;
        }
    }];
#else
    [self.audioRendererImp onFetchPacketSample:block];
#endif
}

- (void)onFetchPlanarSample:(MRFetchPlanarSample)block
{
#if DEBUG_RECORD_PCM_TO_FILE
    [self.audioRendererImp onFetchPlanarSample:^UInt32(uint8_t * _Nonnull left, UInt32 leftSize, uint8_t * _Nonnull right, UInt32 rightSize) {
        if (block) {
            UInt32 filled = block(left,leftSize,right,rightSize);
            fwrite(left, 1, filled, self->file_pcm_l);
            fwrite(right, 1, filled, self->file_pcm_r);
            return filled;
        } else {
            return 0;
        }
    }];
#else
    [self.audioRendererImp onFetchPlanarSample:block];
#endif
}

- (void)paly
{
    [self.audioRendererImp play];
}

- (void)pause
{
    [self.audioRendererImp pause];
}

- (float)outputVolume
{
    return [[AVAudioSession sharedInstance]outputVolume];
}

- (void)setOutputVolume:(float)outputVolume
{
    _outputVolume = outputVolume;
}

@end
