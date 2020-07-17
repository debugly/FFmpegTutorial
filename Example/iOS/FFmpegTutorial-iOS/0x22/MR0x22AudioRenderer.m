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

@interface MR0x22AudioRenderer ()
{
    float _outputVolume;
}

@property (nonatomic, assign, readwrite) MRSampleFormat sampleFmt;
@property (nonatomic, strong) MR0x22AudioQueueRenderer *audioQueue;

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
    if (self.preferredAudioQueue) {
        if (MR_Sample_Fmt_Is_Packet(fmt)) {
            self.audioQueue = [[MR0x22AudioQueueRenderer alloc] init];
            [self.audioQueue setup:rate isFloatFmt:MR_Sample_Fmt_Is_FloatX(fmt)];
        } else {
            NSAssert(NO, @"audio queue not support planar fmt!");
        }
    } else {
#warning TODO
    }
}

- (void)onFetchPacketSample:(MRFetchPacketSample)block
{
    [self.audioQueue onFetchPacketSample:block];
}

- (void)paly
{
    [self.audioQueue play];
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
