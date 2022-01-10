//
//  MR0x40ViewController.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/1/10.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x40ViewController.h"
#import <FFmpegTutorial/FFPlayer0x40.h>
#import "MR0x40VideoRenderer.h"

@interface MR0x40ViewController ()<FFPlayer0x40Delegate>

@property (strong) FFPlayer0x40 *player;
@property (weak) IBOutlet MR0x40VideoRenderer *videoRenderer;

@end

@implementation MR0x40ViewController

- (void)dealloc
{
    if (_player) {
        [_player stop];
        _player = nil;
    }
}

- (void)reveiveFrameToRenderer:(CMSampleBufferRef)sampleBuffer
{
    CFRetain(sampleBuffer);
    dispatch_sync(dispatch_get_main_queue(), ^{
        [self.videoRenderer enqueueSampleBuffer:sampleBuffer];
        CFRelease(sampleBuffer);
    });
}

- (void)preparePlayer
{
    if (self.player) {
        [self.player stop];
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
        [self.player stop];
        self.player = nil;
    }
}

- (IBAction)onExchange:(NSSegmentedControl *)sender
{
    self.player.videoType = sender.selectedSegment;
}

@end
