//
//  MRAudioRendererViewController.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/12/10.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MRAudioRendererViewController.h"
#import <FFmpegTutorial/FFTPlayer0x20.h>
#import <FFmpegTutorial/FFTHudControl.h>
#import <FFmpegTutorial/FFTAudioFrameQueue.h>
#import <libavutil/frame.h>
#import "MRRWeakProxy.h"

#import "MRAudioRenderer.h"

@interface MRAudioRendererViewController ()

@property (strong) FFTPlayer0x20 *player;
@property (weak) IBOutlet NSTextField *inputField;
@property (weak) IBOutlet NSProgressIndicator *indicatorView;
#if TARGET_OS_IPHONE
@property (weak, nonatomic) IBOutlet MRSegmentedControl *formatSegCtrl;
@property (weak, nonatomic) IBOutlet MRSegmentedControl *rateSegCtrl;
#endif
@property (strong) FFTHudControl *hud;
@property (weak) NSTimer *timer;
@property (copy) NSString *audioSampleInfo;
//音频渲染
@property (nonatomic,strong) MRAudioRenderer *audioRenderer;
@property (atomic,strong) FFTAudioFrameQueue *audioFrameQueue;

@property (nonatomic,assign) int sampleRate;
@property (nonatomic,assign) int audioFmt;

@end

@implementation MRAudioRendererViewController

- (void)_stop
{
    [self.audioFrameQueue cancel];
    [self stopAudio];
}

- (void)dealloc
{
    if (_timer) {
        [_timer invalidate];
        _timer = nil;
    }
    
    if (_player) {
        [_player asyncStop];
        _player = nil;
    }
    
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
    [self.indicatorView stopAnimation:nil];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%02d",self.player.audioFrameCount] forKey:@"a-frame"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%02d",self.player.audioPktCount] forKey:@"a-pack"];

    [self.hud setHudValue:[NSString stringWithFormat:@"%d",[self.audioFrameQueue count]] forKey:@"a-frame-q"];
   
    [self.hud setHudValue:[NSString stringWithFormat:@"%@",self.audioSampleInfo] forKey:@"a-format"];
    
    [self.hud setHudValue:self.audioRenderer.name forKey:@"renderer"];
}

- (void)alert:(NSString *)msg
{
    [self alert:@"知道了" msg:msg];
}

- (void)parseURL:(NSString *)url
{
    if (self.player) {
        [self.player asyncStop];
        self.player = nil;
        
        [self.timer invalidate];
        self.timer = nil;
    }
    
    [self.audioFrameQueue cancel];
    self.audioFrameQueue = nil;
    [self stopAudio];
    
    FFTPlayer0x20 *player = [[FFTPlayer0x20 alloc] init];
    player.contentPath = url;
    player.pixelFormat  = MR_PIX_FMT_NV21;
    player.sampleRate   = _sampleRate;
    player.sampleFormat = _audioFmt;
    
    __weakSelf__
    player.onStreamOpened = ^(FFTPlayer0x20 *player, NSDictionary * _Nonnull info) {
        __strongSelf__
        if (player != self.player) {
            return;
        }
        
        [self.indicatorView stopAnimation:nil];
        self.audioFrameQueue = [[FFTAudioFrameQueue alloc] init];
        [self setupAudioRender:self.audioFmt sampleRate:self.sampleRate];
        [self playAudio];
        NSLog(@"---VideoInfo-------------------");
        NSLog(@"%@",info);
        NSLog(@"----------------------");
    };
    
    player.onError = ^(FFTPlayer0x20 *player, NSError * _Nonnull e) {
        __strongSelf__
        if (player != self.player) {
            return;
        }
        [self.indicatorView stopAnimation:nil];
        [self alert:[self.player.error localizedDescription]];
        self.player = nil;
        [self.timer invalidate];
        self.timer = nil;
    };
    
    player.onDecoderFrame = ^(FFTPlayer0x20 *player, int type, int serial, AVFrame * _Nonnull frame) {
        __strongSelf__
        if (player != self.player) {
            return;
        }
        //video
        if (type == 1) {
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
    [self.indicatorView startAnimation:nil];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.hud = [[FFTHudControl alloc] init];
    NSView *hudView = [self.hud contentView];
    [self.view addSubview:hudView];
    hudView.layer.zPosition = 100;
    CGRect rect = self.view.bounds;
#if TARGET_OS_IPHONE
    CGFloat viewHeigth = CGRectGetHeight(rect);
    CGFloat viewWidth  = CGRectGetWidth(rect);
    rect.size.height = 100;
    rect.size.width = 240;
    rect.origin.x = viewWidth - rect.size.width;
    rect.origin.y = viewHeigth - rect.size.height;
    [hudView setFrame:rect];
    hudView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin;
#else
    CGFloat screenWidth = [[NSScreen mainScreen]frame].size.width;
    rect.size.height = MIN(screenWidth / 3.0, 210);
    hudView.autoresizingMask = NSViewWidthSizable;
    [hudView setFrame:rect];
#endif
    
    self.inputField.stringValue = KTestVideoURL1;
    
    [self setupSampleRates];
    [self setupSampleFormats];
}

#pragma - mark Audio

- (void)playAudio
{
    [self.audioRenderer play];
}

- (void)pauseAudio
{
    [self.audioRenderer pause];
}

- (void)stopAudio
{
    [self.audioRenderer stop];
}

- (void)setupAudioRender:(MRSampleFormat)fmt sampleRate:(Float64)sampleRate
{
    self.audioRenderer = [[MRAudioRenderer alloc] initWithFmt:fmt preferredAudioQueue:YES sampleRate:sampleRate];
    __weakSelf__
    [self.audioRenderer onFetchSamples:^UInt32(uint8_t * _Nonnull * _Nullable buffer, UInt32 bufferSize) {
        __strongSelf__
        return [self fillBuffers:buffer byteSize:bufferSize];
    }];
}

- (UInt32)fillBuffers:(uint8_t *[2])buffer
             byteSize:(UInt32)bufferSize
{
    return [self.audioFrameQueue fillBuffers:buffer byteSize:bufferSize];
}

- (void)displayAudioFrame:(AVFrame *)frame
{
    const char *fmt_str = av_sample_fmt_to_string(frame->format);
    self.audioSampleInfo = [NSString stringWithFormat:@"(%s)%d",fmt_str,frame->sample_rate];
    [self.audioFrameQueue enQueue:frame];
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

- (void)doSelectSampleFormat:(MRSampleFormat)targetFmt
{
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

- (void)doSelectSampleRate:(int)sampleRate
{
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

- (void)setupSampleFormats
{
#if TARGET_OS_IPHONE
    NSArray *fmts = @[@"S16",@"S16P",@"Float",@"FloatP"];
    NSArray *tags = @[@(MR_SAMPLE_FMT_S16),@(MR_SAMPLE_FMT_S16P),@(MR_SAMPLE_FMT_FLT),@(MR_SAMPLE_FMT_FLTP)];
    [self.formatSegCtrl removeAllSegments];
    for (int i = 0; i < [fmts count]; i++) {
        NSString *title = fmts[i];
        [self.formatSegCtrl insertSegmentWithTitle:title atIndex:i animated:NO tag:[tags[i] intValue]];
    }
    self.formatSegCtrl.selectedSegmentIndex = 0;
    _audioFmt = [[tags firstObject] intValue];
#else
    _audioFmt = MR_SAMPLE_FMT_S16;
#endif
}

- (void)setupSampleRates
{
#if TARGET_OS_IPHONE
    NSArray *fmts = @[@"44100",@"48000",@"96000",@"192000"];
    NSArray *tags = @[@(44100),@(48000),@(96000),@(192000)];
    [self.rateSegCtrl removeAllSegments];
    for (int i = 0; i < [fmts count]; i++) {
        NSString *title = fmts[i];
        [self.rateSegCtrl insertSegmentWithTitle:title atIndex:i animated:NO tag:[tags[i] intValue]];
    }
    self.rateSegCtrl.selectedSegmentIndex = 0;
    _sampleRate = [[tags firstObject] intValue];
#else
    _sampleRate = 44100;
#endif
}

#if TARGET_OS_OSX
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
    [self doSelectSampleFormat:targetFmt];
}

- (IBAction)onSelectSampleRate:(NSPopUpButton *)sender
{
    NSMenuItem *item = [sender selectedItem];
    int sampleRate = 0;
    if (item.tag == 1) {
        sampleRate = 44100;
    } else if (item.tag == 2) {
        sampleRate = 48000;
    } else if (item.tag == 3) {
        sampleRate = 96000;
    } else if (item.tag == 4) {
        sampleRate = 192000;
    }
    [self doSelectSampleRate:sampleRate];
}

#else

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    UIView *ctrlPanel = self.formatSegCtrl.superview;
    ctrlPanel.hidden = !ctrlPanel.isHidden;
    self.hud.contentView.hidden = !ctrlPanel.isHidden;
}

- (IBAction)onSelectAudioFormat:(MRSegmentedControl *)sender
{
    [self doSelectSampleFormat:(MRSampleFormat)[sender tagForCurrentSelected]];
}

- (IBAction)onSelectSampleRate:(MRSegmentedControl *)sender
{
    [self doSelectSampleRate:(int)[sender tagForCurrentSelected]];
}

#endif

@end
