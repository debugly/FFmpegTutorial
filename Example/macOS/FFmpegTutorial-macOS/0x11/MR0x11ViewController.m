//
//  MR0x11ViewController.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/4/15.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x11ViewController.h"
#import <FFmpegTutorial/FFPlayer0x10.h>
#import <FFmpegTutorial/MRConvertUtil.h>
#import "MRRWeakProxy.h"
#import "MR0x11VideoRenderer.h"
#import <MRFFmpegPod/libavutil/frame.h>

@interface MR0x11ViewController ()

@property (strong) FFPlayer0x10 *player;
@property (weak) IBOutlet NSTextField *inputField;
@property (weak) IBOutlet MR0x11VideoRenderer *videoRenderer;
@property (weak) IBOutlet NSTextField *infoLabel;

@property int audioPktCount;
@property int videoPktCount;
@property int audioFrameCount;
@property int videoFrameCount;

@end

@implementation MR0x11ViewController

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
    
    FFPlayer0x10 *player = [[FFPlayer0x10 alloc] init];
    player.contentPath = url;
    player.supportedPixelFormats =
    MR_PIX_FMT_MASK_RGBA;// |
//    MR_PIX_FMT_MASK_ARGB |
//    MR_PIX_FMT_MASK_0RGB |
//    MR_PIX_FMT_MASK_RGB24;
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
            mr_msleep(40);
            self.infoLabel.stringValue = [NSString stringWithFormat:@"%d,%lld",frame->format,frame->pts];
            [self displayVideoFrame:frame];
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

- (void)displayVideoFrame:(AVFrame *)frame
{
    CGImageRef img = [MRConvertUtil cgImageFromRGBFrame:frame];
    [self.videoRenderer dispalyCGImage:img];
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
