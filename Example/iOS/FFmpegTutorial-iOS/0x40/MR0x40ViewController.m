//
//  MR0x40ViewController.m
//  FFmpegTutorial-iOS
//
//  Created by qianlongxu on 2022/1/10.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//
//

#import "MR0x40ViewController.h"
#import <FFmpegTutorial/FFPlayer0x40.h>
#import "MR0x40VideoRenderer.h"

@interface MR0x40ViewController ()<FFPlayer0x40Delegate>

@property (strong) FFPlayer0x40 *player;
@property (weak, nonatomic) IBOutlet MR0x40VideoRenderer *videoRenderer;

@end

@implementation MR0x40ViewController

- (void)dealloc
{
    if (_player) {
        [_player asyncStop];
        _player = nil;
    }
}

- (void)preparePlayer
{
    if (self.player) {
        [self.player asyncStop];
        self.player = nil;
    }
    
    FFPlayer0x40 *player = [[FFPlayer0x40 alloc] init];
    
    __weakSelf__
    [player onError:^{
        __strongSelf__
        self.player = nil;
    }];
    
    player.delegate = self;
    self.player = player;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.videoRenderer.contentMode = UIViewContentModeScaleAspectFit;
    [self preparePlayer];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    [self.player prapareWithSize:self.videoRenderer.bounds.size];
    [self.player play];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    if (self.player) {
        [self.player asyncStop];
        self.player = nil;
    }
}

- (IBAction)onExchange:(UISegmentedControl *)sender
{
    self.player.videoType = sender.selectedSegmentIndex;
}

- (void)reveiveFrameToRenderer:(CMSampleBufferRef)sampleBuffer
{
    CFRetain(sampleBuffer);
    dispatch_sync(dispatch_get_main_queue(), ^{
        [self.videoRenderer enqueueSampleBuffer:sampleBuffer];
        CFRelease(sampleBuffer);
    });
}

@end
