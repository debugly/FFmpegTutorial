//
//  MRVideoEmbedViewController.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/7/20.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MRVideoEmbedViewController.h"
#import <FFmpegTutorial/FFTPlayer0x32.h>
#import <FFmpegTutorial/FFTHudControl.h>
#import <FFmpegTutorial/FFTConvertUtil.h>
#import <FFmpegTutorial/FFTDispatch.h>
#import <FFmpegTutorial/FFTPlayerHeader.h>
#import <libavutil/frame.h>
#import "MRRWeakProxy.h"
#import "MRAudioRenderer.h"
#import "FFTAudioFrameQueue.h"

//将音频裸流PCM写入到文件
#define DEBUG_RECORD_PCM_TO_FILE 0

@interface MRVideoEmbedViewController ()
{
#if DEBUG_RECORD_PCM_TO_FILE
    FILE * file_pcm_l;
    FILE * file_pcm_r;
#endif
}

@property (strong) FFTPlayer0x32 *player;
@property (weak) IBOutlet NSTextField *inputField;
@property (weak) IBOutlet NSProgressIndicator *indicatorView;
@property (weak) IBOutlet NSView *videoRendererContainer;

@property (strong) FFTHudControl *hud;
@property (weak) NSTimer *timer;
@property (copy) NSString *audioSamplelInfo;
@property (nonatomic,assign) int sampleRate;
@property (nonatomic,assign) MRPixelFormat videoFmt;
@property (nonatomic,assign) MRSampleFormat audioFmt;
#if TARGET_OS_IOS
@property (weak, nonatomic) IBOutlet MRSegmentedControl *videoFmtSegCtrl;
@property (weak, nonatomic) IBOutlet MRSegmentedControl *scalingSegCtrl;
@property (weak, nonatomic) IBOutlet MRSegmentedControl *audioFmtSegCtrl;
@property (weak, nonatomic) IBOutlet MRSegmentedControl *audioSampleSegCtrl;
#endif
//音频渲染
@property (nonatomic,strong) MRAudioRenderer *audioRender;
@property (atomic,strong) FFTAudioFrameQueue *audioFrameQueue;
@property (nonatomic,assign) IJKMPMovieScalingMode scalingMode;

@end

@implementation MRVideoEmbedViewController

- (void)_stop
{
    [self.audioFrameQueue cancel];
    [self stopAudio];
    
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

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.hud = [[FFTHudControl alloc] init];
    NSView *hudView = [self.hud contentView];
    [self.view addSubview:hudView];
    hudView.layer.zPosition = 100;
    CGRect rect = self.view.bounds;
#if TARGET_OS_IPHONE
    rect.origin.y = CGRectGetHeight(rect) - 100;
    rect.size.height = 150;
#else
    CGFloat screenWidth = [[NSScreen mainScreen]frame].size.width;
    rect.size.height = MIN(screenWidth / 3.0, 210);
#endif
    [hudView setFrame:rect];
    hudView.autoresizingMask = NSViewWidthSizable;
    
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
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%@",self.audioSamplelInfo] forKey:@"a-sample"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%d",[self.audioFrameQueue count]] forKey:@"a-frame-q"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%d",self.player.videoFrameQueueSize] forKey:@"v-frame-q"];
    
    [self.hud setHudValue:self.audioRender.name forKey:@"a-renderer"];
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
    [self.audioFrameQueue cancel];
    self.audioFrameQueue = nil;
    
    [self stopAudio];
    [self.timer invalidate];
    self.timer = nil;

    [self close_all_file];
    [self.indicatorView startAnimation:nil];
    
    FFTPlayer0x32 *player = [[FFTPlayer0x32 alloc] init];
    player.contentPath = url;
    player.pixelFormat  = _videoFmt;
    player.sampleRate   = _sampleRate;
    player.sampleFormat = _audioFmt;
    player.videoRender.scalingMode = _scalingMode;
    __weakSelf__
    player.onStreamOpened = ^(FFTPlayer0x32 *player,NSDictionary * _Nonnull info) {
        __strongSelf__
        
        NSLog(@"---SteamInfo-------------------");
        NSLog(@"%@",info);
        NSLog(@"----------------------");
        
        [self.videoRendererContainer addSubview:self.player.videoRender];
        self.player.videoRender.frame = [self.videoRendererContainer bounds];
        self.player.videoRender.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
        
        self.audioFrameQueue = [[FFTAudioFrameQueue alloc] init];
        [self setupAudioRender:self.audioFmt sampleRate:self.sampleRate];
        
#warning AudioQueue需要等buffer填充满了才能播放，这里为了简单就先延迟2s再播放
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.indicatorView stopAnimation:nil];
            [self playAudio];
            [self prepareTickTimerIfNeed];
            [[self.hud contentView]setHidden:NO];
        });
    };
    
    player.onError = ^(FFTPlayer0x32 *player, NSError * _Nonnull e) {
        __strongSelf__
        [self.indicatorView stopAnimation:nil];
        [self alert:@"播放错误" msg:[self.player.error localizedDescription]];
        self.player = nil;
        [self.timer invalidate];
        self.timer = nil;
    };
    
    player.onDecoderAudioFrame = ^(FFTPlayer0x32 *player,int serial, AVFrame * _Nonnull frame) {
        __strongSelf__
        [self enQueueAudioFrame:frame];
    };
    [player prepareToPlay];
    [player play];
    self.player = player;
}

#pragma - mark Audio

- (void)playAudio
{
    [self.audioRender play];
}

- (void)pauseAudio
{
    [self.audioRender pause];
}

- (void)stopAudio
{
    [self.audioRender stop];
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

- (void)setupAudioRender:(MRSampleFormat)fmt sampleRate:(Float64)sampleRate
{
    //这里指定了优先使用AudioQueue，当遇到不支持的格式时，自动使用AudioUnit
    MRAudioRenderer *audioRender = [[MRAudioRenderer alloc] initWithFmt:fmt preferredAudioQueue:YES sampleRate:sampleRate];
    __weakSelf__
    [audioRender onFetchSamples:^UInt32(uint8_t * _Nonnull *buffer, UInt32 bufferSize) {
        __strongSelf__
        return [self fillBuffers:buffer byteSize:bufferSize];
    }];
    self.audioRender = audioRender;
}

- (UInt32)fillBuffers:(uint8_t *[2])buffer
             byteSize:(UInt32)bufferSize
{
    int filled = [self.audioFrameQueue fillBuffers:buffer byteSize:bufferSize];
#if DEBUG_RECORD_PCM_TO_FILE
    for(int i = 0; i < 2; i++) {
        uint8_t *src = buffer[i];
        if (NULL != src) {
            if (i == 0) {
                if (file_pcm_l == NULL) {
                    NSString *fileName = [NSString stringWithFormat:@"L-%@.pcm",self.audioSamplelInfo];
                    const char *l = [[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]UTF8String];
                    NSLog(@"create file:%s",l);
                    file_pcm_l = fopen(l, "wb+");
                }
                fwrite(src, bufferSize, 1, file_pcm_l);
            } else if (i == 1) {
                if (file_pcm_r == NULL) {
                    NSString *fileName = [NSString stringWithFormat:@"R-%@.pcm",self.audioSamplelInfo];
                    const char *r = [[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]UTF8String];
                    NSLog(@"create file:%s",r);
                    file_pcm_r = fopen(r, "wb+");
                }
                fwrite(src, bufferSize, 1, file_pcm_r);
            }
        }
    }
#endif
    return filled;
}

- (void)enQueueAudioFrame:(AVFrame *)frame
{
    const char *fmt_str = av_sample_fmt_to_string(frame->format);
    self.audioSamplelInfo = [NSString stringWithFormat:@"(%s)%d",fmt_str,frame->sample_rate];
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
