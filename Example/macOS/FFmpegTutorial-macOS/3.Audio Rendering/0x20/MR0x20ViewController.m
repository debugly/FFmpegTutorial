//
//  MR0x20ViewController.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/7/10.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x20ViewController.h"
#import <FFmpegTutorial/FFTPlayer0x20.h>
#import <FFmpegTutorial/FFTHudControl.h>
#import <FFmpegTutorial/FFTPlayerHeader.h>
#import <MRFFmpegPod/libavutil/frame.h>
#import "MRRWeakProxy.h"
#import "MR0x20VideoRenderer.h"
#import "NSFileManager+Sandbox.h"
#import "MRUtil.h"

//将音频裸流PCM写入到文件
#define DEBUG_RECORD_PCM_TO_FILE 0

@interface MR0x20ViewController ()
{
#if DEBUG_RECORD_PCM_TO_FILE
    FILE * file_pcm_l;
    FILE * file_pcm_r;
#endif
}

@property (strong) FFTPlayer0x20 *player;
@property (weak) IBOutlet NSTextField *inputField;
@property (weak) IBOutlet NSProgressIndicator *indicatorView;
@property (weak) IBOutlet MR0x20VideoRenderer *videoRenderer;

@property (strong) FFTHudControl *hud;
@property (weak) NSTimer *timer;
@property (copy) NSString *videoPixelInfo;
@property (copy) NSString *audioSamplelInfo;
@property (nonatomic,assign) int sampleRate;
@property (nonatomic,assign) int videoFmt;
@property (nonatomic,assign) int audioFmt;

@end

@implementation MR0x20ViewController

- (void)_stop
{
#if DEBUG_RECORD_PCM_TO_FILE
    [self close_all_file];
#endif
    
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

- (void)prepareTickTimerIfNeed
{
    if (self.timer && ![self.timer isValid]) {
        return;
    }
    MRRWeakProxy *weakProxy = [MRRWeakProxy weakProxyWithTarget:self];
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:0.5 target:weakProxy selector:@selector(onTimer:) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    self.timer = timer;
}

- (void)onTimer:(NSTimer *)sender
{
    [self.hud setHudValue:[NSString stringWithFormat:@"%02d",self.player.audioFrameCount] forKey:@"a-frame"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%02d",self.player.videoFrameCount] forKey:@"v-frame"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%02d",self.player.audioPktCount] forKey:@"a-pack"];

    [self.hud setHudValue:[NSString stringWithFormat:@"%02d",self.player.videoPktCount] forKey:@"v-pack"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%@",self.videoPixelInfo] forKey:@"v-pixel"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%@",self.audioSamplelInfo] forKey:@"a-sample"];
}

- (void)displayVideoFrame:(AVFrame *)frame
{
    const char *fmt_str = av_pixel_fmt_to_string(frame->format);
    
    self.videoPixelInfo = [NSString stringWithFormat:@"(%s)%dx%d",fmt_str,frame->width,frame->height];
    [self.videoRenderer displayAVFrame:frame];
}

- (void)displayAudioFrame:(AVFrame *)frame
{
    const char *fmt_str = av_sample_fmt_to_string(frame->format);
    self.audioSamplelInfo = [NSString stringWithFormat:@"(%s)%d",fmt_str,frame->sample_rate];
    
#if DEBUG_RECORD_PCM_TO_FILE
    if (av_sample_fmt_is_planar(frame->format)) {
        if (file_pcm_l == NULL) {
            NSString *file_name = [NSString stringWithFormat:@"L-%s-%d.pcm",fmt_str,frame->sample_rate];
            const char *l = [[NSTemporaryDirectory() stringByAppendingPathComponent:file_name]UTF8String];
            NSLog(@"create file:%s",l);
            file_pcm_l = fopen(l, "wb+");
        }
        
        fwrite(frame->data[0], frame->linesize[0], 1, file_pcm_l);
        
        if (file_pcm_r == NULL) {
            NSString *file_name = [NSString stringWithFormat:@"R-%s-%d.pcm",fmt_str,frame->sample_rate];
            const char *r = [[NSTemporaryDirectory() stringByAppendingPathComponent:file_name]UTF8String];
            NSLog(@"create file:%s",r);
            file_pcm_r = fopen(r, "wb+");
        }
        fwrite(frame->data[1], frame->linesize[1], 1, file_pcm_r);
    } else {
        if (file_pcm_l == NULL) {
            NSString *file_name = [NSString stringWithFormat:@"%s-%d.pcm",fmt_str,frame->sample_rate];
            const char *l = [[NSTemporaryDirectory() stringByAppendingPathComponent:file_name]UTF8String];
            NSLog(@"create file:%s",l);
            file_pcm_l = fopen(l, "wb+");
        }
        fwrite(frame->data[0], frame->linesize[0], 1, file_pcm_l);
    }
#endif
}

- (void)close_all_file
{
#if DEBUG_RECORD_PCM_TO_FILE
    if (file_pcm_l) {
        fflush(file_pcm_l);
        fclose(file_pcm_l);
        file_pcm_l = NULL;
    }
    if (file_pcm_r) {
        fflush(file_pcm_r);
        fclose(file_pcm_r);
        file_pcm_r = NULL;
    }
#endif
}

- (void)parseURL:(NSString *)url
{
    if (self.player) {
        [self.player asyncStop];
        self.player = nil;
    }
    [self.timer invalidate];
    self.timer = nil;

    [self close_all_file];
    [self.indicatorView startAnimation:nil];
    
    FFTPlayer0x20 *player = [[FFTPlayer0x20 alloc] init];
    player.contentPath = url;
    player.supportedPixelFormat  = _videoFmt;
    player.supportedSampleRate   = _sampleRate;
    player.supportedSampleFormat = _audioFmt;
    
    __weakSelf__
    player.onStreamOpened = ^(NSDictionary * _Nonnull info) {
        __strongSelf__
        int width  = [info[kFFTPlayer0x20Width] intValue];
        int height = [info[kFFTPlayer0x20Height] intValue];
        self.videoRenderer.videoSize = CGSizeMake(width, height);
        [self.indicatorView stopAnimation:nil];
        NSLog(@"---VideoInfo-------------------");
        NSLog(@"%@",info);
        NSLog(@"----------------------");
    };
    
    player.onError = ^(NSError * _Nonnull e) {
        __strongSelf__
        [self.indicatorView stopAnimation:nil];
        [self alert:[self.player.error localizedDescription]];
        self.player = nil;
        [self.timer invalidate];
        self.timer = nil;
    };
    
    player.onDecoderFrame = ^(int type, int serial, AVFrame * _Nonnull frame) {
        __strongSelf__
        //video
        if (type == 1) {
            mr_msleep(40);
            @autoreleasepool {
                [self displayVideoFrame:frame];
            }
        }
        //audio
        else if (type == 2) {
            [self displayAudioFrame:frame];
        }
    };
    [player prepareToPlay];
    [player play];
    self.player = player;
    [self prepareTickTimerIfNeed];
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
    
    _sampleRate = 44100;
    _videoFmt = MR_PIX_FMT_NV12;
    _audioFmt = MR_SAMPLE_FMT_S16;
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

- (IBAction)onSaveSnapshot:(NSButton *)sender
{
    NSImage *img = [self.videoRenderer snapshot];
    NSString *videoName = [[NSURL URLWithString:self.player.contentPath] lastPathComponent];
    if ([videoName isEqualToString:@"/"]) {
        videoName = @"未知";
    }
    NSString *folder = [NSFileManager mr_DirWithType:NSPicturesDirectory WithPathComponents:@[@"FFmpegTutorial",videoName]];
    long timestamp = [NSDate timeIntervalSinceReferenceDate] * 1000;
    NSString *filePath = [folder stringByAppendingPathComponent:[NSString stringWithFormat:@"%ld.jpg",timestamp]];
    [MRUtil saveImageToFile:[MRUtil nsImage2cg:img] path:filePath];
    NSLog(@"img:%@",filePath);
}

- (IBAction)onSelectedVideMode:(NSPopUpButton *)sender
{
    NSMenuItem *item = [sender selectedItem];
        
    if (item.tag == 1) {
        [self.videoRenderer setContentMode:MR0x141ContentModeScaleToFill];
    } else if (item.tag == 2) {
        [self.videoRenderer setContentMode:MR0x141ContentModeScaleAspectFill];
    } else if (item.tag == 3) {
        [self.videoRenderer setContentMode:MR0x141ContentModeScaleAspectFit];
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
