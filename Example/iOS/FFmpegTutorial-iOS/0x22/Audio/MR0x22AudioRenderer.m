//
//  MR0x22AudioRenderer.m
//  FFmpegTutorial-iOS
//
//  Created by Matt Reach on 2020/7/16.
//  Copyright © 2020 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x22AudioRenderer.h"
#import <AVFoundation/AVFoundation.h>
#import "MR0x22AudioQueueRenderer.h"
#import "MR0x22AudioUnitRenderer.h"

@interface MR0x22AudioRenderer ()
{
    float _outputVolume;
}

@property (nonatomic, assign, readwrite) MRSampleFormat sampleFmt;
@property (nonatomic, strong) id<MR0x22AudioRendererImpProtocol> audioRendererImp;

@end


@implementation MR0x22AudioRenderer

@synthesize outputVolume = _outputVolume;

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
            self.audioRendererImp = [[MR0x22AudioQueueRenderer alloc] init];
            [self.audioRendererImp setup:rate isFloatFmt:MR_Sample_Fmt_Is_FloatX(fmt)];
            return;
        } else {
            NSLog(@"audio queue not support planar fmt, will use audio unit!");
        }
    }
    
    self.audioRendererImp = [[MR0x22AudioUnitRenderer alloc] init];
    [self.audioRendererImp setup:rate isFloatFmt:MR_Sample_Fmt_Is_FloatX(fmt) isPacket:MR_Sample_Fmt_Is_Packet(fmt)];
}

- (void)onFetchPacketSample:(MRFetchPacketSample)block
{
    [self.audioRendererImp onFetchPacketSample:block];
}

- (void)onFetchPlanarSample:(MRFetchPlanarSample)block
{
    [self.audioRendererImp onFetchPlanarSample:block];
}

- (void)paly
{
    [self.audioRendererImp play];
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
