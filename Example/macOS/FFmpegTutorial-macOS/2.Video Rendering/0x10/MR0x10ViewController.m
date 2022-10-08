//
//  MR0x10ViewController.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/7/5.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x10ViewController.h"
#import <FFmpegTutorial/FFTPlayer0x10.h>
#import <MRFFmpegPod/libavutil/frame.h>

@interface MR0x10ViewController ()

@property (strong) FFTPlayer0x10 *player;
@property (weak) IBOutlet NSTextField *inputField;
@property (weak) IBOutlet NSTextField *infoLabel;

@property int audioPktCount;
@property int videoPktCount;
@property int audioFrameCount;
@property int videoFrameCount;

@end

@implementation MR0x10ViewController

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
    
    self.audioFrameCount = 0;
    self.videoFrameCount = 0;
    
    FFTPlayer0x10 *player = [[FFTPlayer0x10 alloc] init];
    player.contentPath = url;
    
    player.supportedPixelFormats = MR_PIX_FMT_MASK_RGBA;// |
//    MR_PIX_FMT_MASK_NV12 |
//    MR_PIX_FMT_MASK_BGRA;
    ;
    __weakSelf__
    player.onError = ^(NSError *err){
        NSLog(@"%@",err);
        __strongSelf__
        self.player = nil;
    };
    
    player.onReadPkt = ^(int a,int v){
        __strongSelf__
        self.audioPktCount = a;
        self.videoPktCount = v;
    };
    
    player.onDecoderFrame = ^(int type,int serial,AVFrame *frame) {
        __strongSelf__
        //video
        if (type == 1) {
            self.videoFrameCount = serial;
            self.infoLabel.stringValue = [NSString stringWithFormat:@"%d,%lld",frame->format,frame->pts];
        }
        //audio
        else if (type == 2) {
            self.audioFrameCount = serial;
        }
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
