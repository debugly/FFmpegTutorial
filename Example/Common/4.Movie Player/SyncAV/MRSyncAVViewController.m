//
//  MRSyncAVViewController.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2023/12/21.
//  Copyright © 2023 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MRSyncAVViewController.h"
#import <FFmpegTutorial/FFTPlayer0x35.h>
#import <FFmpegTutorial/FFTHudControl.h>
#import <FFmpegTutorial/FFTConvertUtil.h>
#import <FFmpegTutorial/FFTDispatch.h>
#import <FFmpegTutorial/FFTPlayerHeader.h>
#import <libavutil/frame.h>
#import "MRRWeakProxy.h"

@interface MRSyncAVViewController ()

@property (strong) FFTPlayer0x35 *player;
@property (weak) IBOutlet NSTextField *inputField;
@property (weak) IBOutlet NSProgressIndicator *indicatorView;
@property (weak) IBOutlet NSView *videoRendererContainer;

@property (strong) FFTHudControl *hud;
@property (weak) NSTimer *timer;
@property (nonatomic,assign) int sampleRate;
@property (nonatomic,assign) MRPixelFormat videoFmt;
@property (nonatomic,assign) MRSampleFormat audioFmt;
#if TARGET_OS_IOS
@property (weak, nonatomic) IBOutlet MRSegmentedControl *videoFmtSegCtrl;
@property (weak, nonatomic) IBOutlet MRSegmentedControl *scalingSegCtrl;
@property (weak, nonatomic) IBOutlet MRSegmentedControl *audioFmtSegCtrl;
@property (weak, nonatomic) IBOutlet MRSegmentedControl *audioSampleSegCtrl;
#endif
@property (nonatomic,assign) IJKMPMovieScalingMode scalingMode;

@end

@implementation MRSyncAVViewController

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
    
    self.hud = [[FFTHudControl alloc] init];
    NSView *hudView = [self.hud contentView];
    [self.view addSubview:hudView];
    hudView.layer.zPosition = 100;
    CGRect rect = self.view.bounds;
#if TARGET_OS_IPHONE
    CGFloat viewHeigth = CGRectGetHeight(rect);
    CGFloat viewWidth  = CGRectGetWidth(rect);
    rect.size.height = 195;
    rect.size.width = 240;
    rect.origin.x = viewWidth - rect.size.width;
    rect.origin.y = viewHeigth - rect.size.height;
    [hudView setFrame:rect];
    hudView.autoresizingMask = UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleLeftMargin;
#else
    CGFloat screenWidth = [[NSScreen mainScreen]frame].size.width;
    rect.size.height = MIN(screenWidth / 3.0, 310);
    hudView.autoresizingMask = NSViewWidthSizable;
    [hudView setFrame:rect];
#endif
    
    self.inputField.stringValue = KTestVideoURL1;
    
#if TARGET_OS_IPHONE
    [self setupIOS];
#else
    _sampleRate = 44100;
    _audioFmt = MR_SAMPLE_FMT_S16;
    _videoFmt = MR_PIX_FMT_NV12;
    _scalingMode = IJKMPMovieScalingModeFill;
#endif
}

#if TARGET_OS_IPHONE
- (void)setupIOS
{
    {
        NSArray *fmts = @[@"BGRA",@"BGR0",@"NV12",@"NV21",@"UYVY",@"YUYV",@"YUV420P"];
        NSArray *tags = @[@(MR_PIX_FMT_BGRA),@(MR_PIX_FMT_BGR0),@(MR_PIX_FMT_NV12),@(MR_PIX_FMT_NV21),@(MR_PIX_FMT_UYVY422),@(MR_PIX_FMT_YUYV422),@(MR_PIX_FMT_YUV420P)];
        [self.videoFmtSegCtrl removeAllSegments];
        for (int i = 0; i < [fmts count]; i++) {
            NSString *title = fmts[i];
            [self.videoFmtSegCtrl insertSegmentWithTitle:title atIndex:i animated:NO tag:[tags[i] intValue]];
        }
        self.videoFmtSegCtrl.selectedSegmentIndex = 0;
        _videoFmt = [[tags firstObject] intValue];
    }
    
    {
        NSArray *scalings = @[@"Scale To Fill",@"Scale Aspect Fill",@"Scale Aspect Fit"];
        NSArray *tags = @[@(IJKMPMovieScalingModeFill),@(IJKMPMovieScalingModeAspectFill),@(IJKMPMovieScalingModeAspectFit)];
        [self.scalingSegCtrl removeAllSegments];
        for (int i = 0; i < [scalings count]; i++) {
            NSString *title = scalings[i];
            [self.scalingSegCtrl insertSegmentWithTitle:title atIndex:i animated:NO tag:[tags[i] intValue]];
        }
        self.scalingSegCtrl.selectedSegmentIndex = 0;
        _scalingMode = [[tags firstObject] intValue];
    }
    
    {
        NSArray *fmts = @[@"S16",@"S16P",@"Float",@"FloatP"];
        NSArray *tags = @[@(MR_SAMPLE_FMT_S16),@(MR_SAMPLE_FMT_S16P),@(MR_SAMPLE_FMT_FLT),@(MR_SAMPLE_FMT_FLTP)];
        [self.audioFmtSegCtrl removeAllSegments];
        for (int i = 0; i < [fmts count]; i++) {
            NSString *title = fmts[i];
            [self.audioFmtSegCtrl insertSegmentWithTitle:title atIndex:i animated:NO tag:[tags[i] intValue]];
        }
        self.audioFmtSegCtrl.selectedSegmentIndex = 0;
        _audioFmt = [[tags firstObject] intValue];
    }
    
    {
        NSArray *fmts = @[@"44100",@"48000",@"96000",@"192000"];
        NSArray *tags = @[@(44100),@(48000),@(96000),@(192000)];
        [self.audioSampleSegCtrl removeAllSegments];
        for (int i = 0; i < [fmts count]; i++) {
            NSString *title = fmts[i];
            [self.audioSampleSegCtrl insertSegmentWithTitle:title atIndex:i animated:NO tag:[tags[i] intValue]];
        }
        self.audioSampleSegCtrl.selectedSegmentIndex = 0;
        _sampleRate = [[tags firstObject] intValue];
    }
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    UIView *ctrlPanel = self.videoFmtSegCtrl.superview;
    ctrlPanel.hidden = !ctrlPanel.isHidden;
    self.hud.contentView.hidden = !ctrlPanel.isHidden;
}

#endif

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
    
    [self.hud setHudValue:self.player.videoRender.name forKey:@"v-renderer"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%0.2f",self.player.audioPosition] forKey:@"a-pos"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%0.2f",self.player.videoPosition] forKey:@"v-pos"];
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
    
    FFTPlayer0x35 *player = [[FFTPlayer0x35 alloc] init];
    player.contentPath = url;
    player.pixelFormat  = _videoFmt;
    player.sampleRate   = _sampleRate;
    player.sampleFormat = _audioFmt;
    
    __weakSelf__
    player.onStreamOpened = ^(FFTPlayer0x35 *player,NSDictionary * _Nonnull info) {
        __strongSelf__
        
        NSLog(@"---SteamInfo-------------------");
        NSLog(@"%@",info);
        NSLog(@"----------------------");
        
        self.player.videoRender.scalingMode = self.scalingMode;
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
    
    player.onError = ^(FFTPlayer0x35 *player, NSError * _Nonnull e) {
        __strongSelf__
        [self.indicatorView stopAnimation:nil];
        [self alert:@"错误提示" msg:[self.player.error localizedDescription]];
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
#if TARGET_OS_IPHONE
    [self.inputField resignFirstResponder];
#endif
}

- (void)exchangeAudioFmt:(int)targetFmt
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

- (void)exchangeSampleRate:(int)sampleRate
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

- (void)exchangeVideoFormat:(int)targetFmt
{
    _videoFmt = targetFmt;
    
    if (self.player) {
        NSString *url = self.player.contentPath;
        [self.player asyncStop];
        self.player = nil;
        [self parseURL:url];
    }
}

#if TARGET_OS_OSX
- (IBAction)onSelectedVideMode:(NSPopUpButton *)sender
{
    int itemTag = (int)[sender selectedItem].tag;
    if (itemTag == 1) {
        [self.player.videoRender setScalingMode:IJKMPMovieScalingModeFill];
    } else if (itemTag == 2) {
        [self.player.videoRender setScalingMode:IJKMPMovieScalingModeAspectFill];
    } else if (itemTag == 3) {
        [self.player.videoRender setScalingMode:IJKMPMovieScalingModeAspectFit];
    }
}

- (IBAction)onSelectAudioFmt:(NSPopUpButton *)sender
{
    int itemTag = (int)[sender selectedItem].tag;
    int targetFmt = 0;
    if (itemTag == 1) {
        targetFmt = MR_SAMPLE_FMT_S16;
    } else if (itemTag == 2) {
        targetFmt = MR_SAMPLE_FMT_S16P;
    } else if (itemTag == 3) {
        targetFmt = MR_SAMPLE_FMT_FLT;
    } else if (itemTag == 4) {
        targetFmt = MR_SAMPLE_FMT_FLTP;
    }
    [self exchangeAudioFmt:targetFmt];
}

- (IBAction)onSelectSampleRate:(NSPopUpButton *)sender
{
    int itemTag = (int)[sender selectedItem].tag;
    int sampleRate = 0;
    if (itemTag == 1) {
        sampleRate = 44100;
    } else if (itemTag == 2) {
        sampleRate = 48000;
    } else if (itemTag == 3) {
        sampleRate = 192000;
    }
    [self exchangeSampleRate:sampleRate];
}

- (IBAction)onSelectVideoFormat:(NSPopUpButton *)sender
{
    int itemTag = (int)[sender selectedItem].tag;
    int targetFmt = 0;
    if (itemTag == 1) {
        //nv12
        targetFmt = MR_PIX_FMT_NV12;
    } else if (itemTag == 2) {
        //bgra
        targetFmt = MR_PIX_FMT_BGRA;
    } else if (itemTag == 3) {
        //bgr0
        targetFmt = MR_PIX_FMT_BGR0;
    } else if (itemTag == 4) {
        //uyvy422
        targetFmt = MR_PIX_FMT_UYVY422;
    } else if (itemTag == 5) {
        //yuyv422
        targetFmt = MR_PIX_FMT_YUYV422;
    } else if (itemTag == 6) {
        //yuv420p
        targetFmt = MR_PIX_FMT_YUV420P;
    }
    if (_videoFmt == targetFmt) {
        return;
    }
    [self exchangeVideoFormat:targetFmt];
}
#else

- (IBAction)onSelectedVideMode:(MRSegmentedControl *)sender
{
    [self.player.videoRender setScalingMode:(int)[sender tagForCurrentSelected]];
}

- (IBAction)onSelectAudioFmt:(MRSegmentedControl *)sender
{
    [self exchangeAudioFmt:(int)[sender tagForCurrentSelected]];
}

- (IBAction)onSelectSampleRate:(MRSegmentedControl *)sender
{
    [self exchangeSampleRate:(int)[sender tagForCurrentSelected]];
}

- (IBAction)onSelectVideoFormat:(MRSegmentedControl *)sender
{
    [self exchangeVideoFormat:(int)[sender tagForCurrentSelected]];
}
#endif

@end
