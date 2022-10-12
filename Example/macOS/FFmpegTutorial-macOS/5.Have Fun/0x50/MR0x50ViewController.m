//
//  MR0x50ViewController.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/9/8.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x50ViewController.h"
#import <FFmpegTutorial/FFTPlayer0x50.h>
#import <FFmpegTutorial/FFTDispatch.h>
#import "MR0x50VideoRenderer.h"

@interface MR0x50ViewController ()<FFTPlayer0x50Delegate>

@property (strong) FFTPlayer0x50 *player;
@property (weak) IBOutlet MR0x50VideoRenderer *videoRenderer;

@end

@implementation MR0x50ViewController

- (void)dealloc
{
    if (_player) {
        [_player asyncStop];
        _player = nil;
    }
}

- (void)reveiveFrameToRenderer:(CMSampleBufferRef)sampleBuffer
{
    CFRetain(sampleBuffer);
    mr_sync_main_queue(^{
        [self.videoRenderer enqueueSampleBuffer:sampleBuffer];
        CFRelease(sampleBuffer);
    });
}

- (void)preparePlayer
{
    if (self.player) {
        [self.player asyncStop];
        self.player = nil;
    }
    
    FFTPlayer0x50 *player = [[FFTPlayer0x50 alloc] init];
    player.videoType = FFTPlayer0x50Video3ballType;
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
    [self.view setWantsLayer:YES];
    self.view.layer.backgroundColor = [[NSColor whiteColor] CGColor];
    [self preparePlayer];
}

- (void)viewWillAppear
{
    [super viewWillAppear];
    [self.player prapareWithSize:self.videoRenderer.bounds.size];
    [self.player play];
}

- (void)viewWillDisappear
{
    [super viewWillDisappear];
    if (self.player) {
        [self.player asyncStop];
        self.player = nil;
    }
}

- (IBAction)onExchange:(NSSegmentedControl *)sender
{
    self.player.videoType = sender.selectedSegment;
}

@end
