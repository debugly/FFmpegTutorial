//
//  MR0x33ViewController.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/7/20.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x33ViewController.h"
#import <FFmpegTutorial/FFTPlayer0x33.h>
#import <FFmpegTutorial/FFTHudControl.h>
#import <FFmpegTutorial/FFTConvertUtil.h>
#import <FFmpegTutorial/FFTDispatch.h>
#import <FFmpegTutorial/FFTPlayerHeader.h>
#import <MRFFmpegPod/libavutil/frame.h>
#import "MRRWeakProxy.h"
#import "NSFileManager+Sandbox.h"
#import "MRUtil.h"

@interface MR0x33ViewController ()

@property (strong) FFTPlayer0x33 *player;
@property (weak) IBOutlet NSTextField *inputField;
@property (weak) IBOutlet NSProgressIndicator *indicatorView;
@property (weak) IBOutlet NSView *videoRendererContainer;

@property (strong) FFTHudControl *hud;
@property (weak) NSTimer *timer;
@property (nonatomic,assign) int sampleRate;
@property (nonatomic,assign) MRPixelFormat videoFmt;
@property (nonatomic,assign) MRSampleFormat audioFmt;

@end

@implementation MR0x33ViewController

- (void)_stop
{
    if (_timer) {
        [_timer invalidate];
        _timer = nil;
    }
    
    if (_player) {
        [_player asyncStop];
        _player = nil;
    }
    
    [self.hud destroyContentView];
    self.hud = nil;
}

- (void)dealloc
{
    [self _stop];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.inputField.stringValue = KTestVideoURL1;
    self.hud = [[FFTHudControl alloc] init];
    NSView *hudView = [self.hud contentView];
    [self.view addSubview:hudView];
    CGRect rect = self.view.bounds;
    CGFloat screenWidth = [[NSScreen mainScreen]frame].size.width;
    rect.size.width = MIN(screenWidth / 5.0, 240);
    rect.size.height = CGRectGetHeight(self.view.bounds) - 210;
    rect.origin.x = CGRectGetWidth(self.view.bounds) - rect.size.width;
    [hudView setFrame:rect];
    hudView.autoresizingMask = NSViewMinXMargin | NSViewMaxYMargin;
    [hudView setHidden:YES];
    
    _sampleRate = 44100;
    _videoFmt = MR_PIX_FMT_NV12;
    _audioFmt = MR_SAMPLE_FMT_S16;
}

- (void)prepareTickTimerIfNeed
{
    if (self.timer && ![self.timer isValid]) {
        return;
    }

    MRRWeakProxy *weakProxy = [MRRWeakProxy weakProxyWithTarget:self];
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:weakProxy selector:@selector(onTimer:) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    self.timer = timer;
}

- (void)updateHud
{
    [self.hud setHudValue:[NSString stringWithFormat:@"%02d",self.player.audioFrameCount] forKey:@"a-frame"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%02d",self.player.videoFrameCount] forKey:@"v-frame"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%02d",self.player.audioPktCount] forKey:@"a-pack"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%02d",self.player.videoPktCount] forKey:@"v-pack"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%@",self.player.videoPixelInfo] forKey:@"v-pixel"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%@",self.player.audioSamplelInfo] forKey:@"a-sample"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%d",self.player.audioFrameQueueSize] forKey:@"a-frame-q"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%d",self.player.videoFrameQueueSize] forKey:@"v-frame-q"];
    
    [self.hud setHudValue:self.player.audioRenderName forKey:@"a-renderer"];
}

- (void)onTimer:(NSTimer *)sender
{
    [self updateHud];
}

- (void)parseURL:(NSString *)url
{
    if (self.player) {
        [self.player asyncStop];
        self.player = nil;
    }
    
    [self.timer invalidate];
    self.timer = nil;

    [self.indicatorView startAnimation:nil];
    
    FFTPlayer0x33 *player = [[FFTPlayer0x33 alloc] init];
    player.contentPath = url;
    player.supportedPixelFormat  = _videoFmt;
    player.supportedSampleRate   = _sampleRate;
    player.supportedSampleFormat = _audioFmt;
    
    __weakSelf__
    player.onStreamOpened = ^(NSDictionary * _Nonnull info) {
        __strongSelf__
        
        NSLog(@"---SteamInfo-------------------");
        NSLog(@"%@",info);
        NSLog(@"----------------------");
        
        [self.videoRendererContainer addSubview:self.player.videoRender];
        self.player.videoRender.frame = [self.videoRendererContainer bounds];
        self.player.videoRender.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        
#warning 这里为了简单就先延迟2s再播放
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.indicatorView stopAnimation:nil];
            [self.player play];
            [self prepareTickTimerIfNeed];
            [[self.hud contentView]setHidden:NO];
        });
    };
    
    player.onError = ^(NSError * _Nonnull e) {
        __strongSelf__
        [self.indicatorView stopAnimation:nil];
        [self alert:[self.player.error localizedDescription]];
        self.player = nil;
        [self.timer invalidate];
        self.timer = nil;
    };
    
    [player prepareToPlay];
    [player load];
    self.player = player;
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

- (IBAction)onSelectedVideMode:(NSPopUpButton *)sender
{
    NSMenuItem *item = [sender selectedItem];
        
    if (item.tag == 1) {
        [self.player.videoRender setContentMode:MRViewContentModeScaleToFill];
    } else if (item.tag == 2) {
        [self.player.videoRender setContentMode:MRViewContentModeScaleAspectFill];
    } else if (item.tag == 3) {
        [self.player.videoRender setContentMode:MRViewContentModeScaleAspectFit];
    }
}

- (IBAction)onSelectAudioFmt:(NSPopUpButton *)sender
{
    NSMenuItem *item = [sender selectedItem];
    int targetFmt = 0;
    if (item.tag == 1) {
        targetFmt = MR_SAMPLE_FMT_S16;
    } else if (item.tag == 2) {
        targetFmt = MR_SAMPLE_FMT_S16P;
    } else if (item.tag == 3) {
        targetFmt = MR_SAMPLE_FMT_FLT;
    } else if (item.tag == 4) {
        targetFmt = MR_SAMPLE_FMT_FLTP;
    }
    if (_audioFmt == targetFmt) {
        return;
    }
    _audioFmt = targetFmt;
    
    if (self.player) {
        NSString *url = self.player.contentPath;
        [self.player asyncStop];
        self.player = nil;
        [self parseURL:url];
    }
}

- (IBAction)onSelectSampleRate:(NSPopUpButton *)sender
{
    NSMenuItem *item = [sender selectedItem];
    int sampleRate = 0;
    if (item.tag == 1) {
        sampleRate = 44100;
    } else if (item.tag == 2) {
        sampleRate = 44800;
    } else if (item.tag == 3) {
        sampleRate = 192000;
    }
    if (_sampleRate != sampleRate) {
        _sampleRate = sampleRate;
        if (self.player) {
            NSString *url = self.player.contentPath;
            [self.player asyncStop];
            self.player = nil;
            [self parseURL:url];
        }
    }
}

- (IBAction)onSelectVideoFormat:(NSPopUpButton *)sender
{
    NSMenuItem *item = [sender selectedItem];
    int targetFmt = 0;
    if (item.tag == 1) {
        //nv12
        targetFmt = MR_PIX_FMT_NV12;
    } else if (item.tag == 2) {
        //nv21
        targetFmt = MR_PIX_FMT_NV21;
    } else if (item.tag == 3) {
        //yuv420p
        targetFmt = MR_PIX_FMT_YUV420P;
    } else if (item.tag == 4) {
        //uyvy422
        targetFmt = MR_PIX_FMT_UYVY422;
    } else if (item.tag == 5) {
        //yuyv422
        targetFmt = MR_PIX_FMT_YUYV422;
    }
    if (_videoFmt == targetFmt) {
        return;
    }
    _videoFmt = targetFmt;
    
    if (self.player) {
        NSString *url = self.player.contentPath;
        [self.player asyncStop];
        self.player = nil;
        [self parseURL:url];
    }
}

- (void)alert:(NSString *)msg
{
    NSAlert *alert = [[NSAlert alloc] init];
    [alert addButtonWithTitle:@"知道了"];
    [alert setMessageText:@"错误提示"];
    [alert setInformativeText:msg];
    [alert setAlertStyle:NSInformationalAlertStyle];
    NSModalResponse returnCode = [alert runModal];
    
    if (returnCode == NSAlertFirstButtonReturn)
    {
        //nothing todo
    }
    else if (returnCode == NSAlertSecondButtonReturn)
    {
        
    }
}

@end
