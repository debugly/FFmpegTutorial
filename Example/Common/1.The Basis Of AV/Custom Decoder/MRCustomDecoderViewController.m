//
//  MRCustomDecoderViewController.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/4/15.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MRCustomDecoderViewController.h"
#import <FFmpegTutorial/FFTPlayer0x06.h>
#import <FFmpegTutorial/FFTDispatch.h>

@interface MRCustomDecoderViewController ()

@property (strong) FFTPlayer0x06 *player;
@property (weak) IBOutlet NSTextField *inputField;
@property (nonatomic) int audioPktCount;
@property (nonatomic) int videoPktCount;
@property (nonatomic) int audioFrameCount;
@property (nonatomic) int videoFrameCount;
#if TARGET_OS_IPHONE
@property (weak, nonatomic) IBOutlet UILabel *audioPktLb;
@property (weak, nonatomic) IBOutlet UILabel *videoPktLb;
@property (weak, nonatomic) IBOutlet UILabel *audioFrmLb;
@property (weak, nonatomic) IBOutlet UILabel *videoFrmLb;
#endif
@end

@implementation MRCustomDecoderViewController

- (void)dealloc
{
}

#if TARGET_OS_IPHONE

- (void)setAudioPktCount:(int)audioPktCount
{
    if (_audioPktCount != audioPktCount) {
        _audioPktCount = audioPktCount;
        mr_async_main_queue(^{
            self.audioPktLb.text = [NSString stringWithFormat:@"%d",self.audioPktCount];
        });
    }
}

- (void)setVideoPktCount:(int)videoPktCount
{
    if (_videoPktCount != videoPktCount) {
        _videoPktCount = videoPktCount;
        mr_async_main_queue(^{
            self.videoPktLb.text = [NSString stringWithFormat:@"%d",self.videoPktCount];
        });
    }
}

- (void)setAudioFrameCount:(int)audioFrameCount
{
    if (_audioFrameCount != audioFrameCount) {
        _audioFrameCount = audioFrameCount;
        mr_async_main_queue(^{
            self.audioFrmLb.text = [NSString stringWithFormat:@"%d",self.audioFrameCount];
        });
    }
}

- (void)setVideoFrameCount:(int)videoFrameCount
{
    if (_videoFrameCount != videoFrameCount) {
        _videoFrameCount = videoFrameCount;
        mr_async_main_queue(^{
            self.videoFrmLb.text = [NSString stringWithFormat:@"%d",self.videoFrameCount];
        });
    }
}
#endif

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
    
    FFTPlayer0x06 *player = [[FFTPlayer0x06 alloc] init];
    player.contentPath = url;

    __weakSelf__
    player.onError = ^(FFTPlayer0x06 *player,NSError *err){
        NSLog(@"%@",err);
        __strongSelf__
        self.player = nil;
    };
    
    player.onReadPkt = ^(FFTPlayer0x06 *player,int a,int v){
        __strongSelf__
        self.audioPktCount = a;
        self.videoPktCount = v;
    };
    
    player.onDecoderFrame = ^(FFTPlayer0x06 *player,int a, int v) {
        __strongSelf__
        self.audioFrameCount = a;
        self.videoFrameCount = v;
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
#if TARGET_OS_IPHONE
    [self.inputField resignFirstResponder];
#endif
}

@end
