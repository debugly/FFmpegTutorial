//
//  MR0x04ViewController.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/4/15.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x04ViewController.h"
#import <FFmpegTutorial/FFTPlayer0x04.h>

@interface MR0x04ViewController ()

@property (strong) FFTPlayer0x04 *player;
@property (weak) IBOutlet NSTextField *inputField;
@property int audioPktCount;
@property int videoPktCount;

@end

@implementation MR0x04ViewController

- (void)dealloc
{
}

- (void)parseURL:(NSString *)url
{
    if (self.player) {
        [self.player asyncStop];
        self.player = nil;
    }
    self.audioPktCount = 0;
    self.videoPktCount = 0;
    
    FFTPlayer0x04 *player = [[FFTPlayer0x04 alloc] init];
    player.contentPath = url;

    __weakSelf__
    [player onError:^{
        __strongSelf__
        self.player = nil;
    }];
    
    player.onReadPkt = ^(int a,int v){
        __strongSelf__
        self.audioPktCount = a;
        self.videoPktCount = v;
    };
    
    [player prepareToPlay];
    [player play];
    self.player = player;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.inputField.stringValue = KTestVideoURL1;
    self.audioPktCount = 0;
    self.videoPktCount = 0;
}

- (void)viewWillDisappear
{
    [super viewWillDisappear];
    if (_player) {
        [_player asyncStop];
        _player = nil;
    }
}

#pragma - mark actions

- (IBAction)go:(NSButton *)sender
{
    if (self.inputField.stringValue.length > 0) {
        [self parseURL:self.inputField.stringValue];
    } else {
        self.inputField.placeholderString = @"请输入视频地址";
    }
}

@end
