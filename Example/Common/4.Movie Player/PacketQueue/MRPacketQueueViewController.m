//
//  MRPacketQueueViewController.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/12/10.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MRPacketQueueViewController.h"
#import <FFmpegTutorial/FFTPlayer0x31.h>
#import <FFmpegTutorial/FFTHudControl.h>
#import <FFmpegTutorial/FFTConvertUtil.h>
#import <FFmpegTutorial/FFTAudioFrameQueue.h>
#import <FFmpegTutorial/FFTVideoFrameQueue.h>
#import <libavutil/frame.h>
#import "MRRWeakProxy.h"
#import "MRMetalView.h"
#import "MRAudioRenderer.h"

@interface MRPacketQueueViewController ()
{
    CVPixelBufferPoolRef _pixelBufferPoolRef;
}
@property (strong) FFTPlayer0x31 *player;
@property (weak) IBOutlet NSTextField *inputField;
@property (weak) IBOutlet NSProgressIndicator *indicatorView;
@property (weak) IBOutlet NSView *playbackView;
@property (strong) FFTHudControl *hud;
@property (weak) NSTimer *timer;
@property (copy) NSString *audioSampleInfo;
@property (copy) NSString *videoPixelInfo;
//音频渲染
@property (nonatomic,strong) MRAudioRenderer *audioRenderer;
@property (atomic,strong) FFTAudioFrameQueue *audioFrameQueue;
//视频渲染
@property (nonatomic,weak) MRMetalView *videoRenderer;
@property (atomic,strong) FFTVideoFrameQueue *videoFrameQueue;

@end

@implementation MRPacketQueueViewController

- (void)_stop
{
    [self.audioFrameQueue cancel];
    [self.videoFrameQueue cancel];
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
    //假定视频 30 帧；
    MRRWeakProxy *weakProxy = [MRRWeakProxy weakProxyWithTarget:self];
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0/30 target:weakProxy selector:@selector(onTimer:) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    self.timer = timer;
}

- (void)updateHud
{
    [self.hud setHudValue:[NSString stringWithFormat:@"%02d",self.player.audioFrameCount] forKey:@"a-frame"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%02d",self.player.audioPktCount] forKey:@"a-pack"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%d",[self.audioFrameQueue count]] forKey:@"a-frame-q"];
    [self.hud setHudValue:[NSString stringWithFormat:@"%d",[self.videoFrameQueue count]] forKey:@"v-frame-q"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%@",self.audioSampleInfo] forKey:@"a-format"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%@",self.videoPixelInfo] forKey:@"v-pixel"];
    
    [self.hud setHudValue:self.audioRenderer.name forKey:@"a-renderer"];
    NSString *renderer = NSStringFromClass([self.videoRenderer class]);
    renderer = [renderer stringByReplacingOccurrencesOfString:@"MR" withString:@""];
    renderer = [renderer stringByReplacingOccurrencesOfString:@"View" withString:@""];
    [self.hud setHudValue:renderer forKey:@"v-renderer"];
}

- (void)onTimer:(NSTimer *)sender
{
    [self.indicatorView stopAnimation:nil];
    
    static int tickCount = 0;
    
    if (tickCount == 0) {
        [self updateHud];
    } else if (++tickCount == 30) {
        [self updateHud];
        tickCount = 0;
    }
    
    FFFrameItem *item = [_videoFrameQueue peek];
    if (item) {
        [self displayVideoFrame:item.frame];
        [_videoFrameQueue pop];
    } else {
        NSLog(@"has no video frame to display.");
    }
}

- (void)alert:(NSString *)msg
{
    [self alert:@"知道了" msg:msg];
}

- (CVPixelBufferRef)createCVPixelBufferFromAVFrame:(AVFrame *)frame
{
    if (_pixelBufferPoolRef) {
        NSDictionary *attributes = (__bridge NSDictionary *)CVPixelBufferPoolGetPixelBufferAttributes(_pixelBufferPoolRef);
        int _width = [[attributes objectForKey:(NSString*)kCVPixelBufferWidthKey] intValue];
        int _height = [[attributes objectForKey:(NSString*)kCVPixelBufferHeightKey] intValue];
        int _format = [[attributes objectForKey:(NSString*)kCVPixelBufferPixelFormatTypeKey] intValue];
        
        if (frame->width != _width || frame->height != _height || [FFTConvertUtil cvpixelFormatTypeWithAVFrame:frame] != _format) {
            CVPixelBufferPoolRelease(_pixelBufferPoolRef);
            _pixelBufferPoolRef = NULL;
        }
    }
    
    if (!_pixelBufferPoolRef) {
        _pixelBufferPoolRef = [FFTConvertUtil createPixelBufferPoolWithAVFrame:frame];
    }
    return [FFTConvertUtil pixelBufferFromAVFrame:frame opt:_pixelBufferPoolRef];
}

- (void)enQueueVideoFrame:(AVFrame *)frame
{
    const char *fmt_str = av_pixel_fmt_to_string(frame->format);
    self.videoPixelInfo = [NSString stringWithFormat:@"(%s)%dx%d",fmt_str,frame->width,frame->height];
    [self.videoFrameQueue enQueue:frame];
}

- (void)displayVideoFrame:(AVFrame *)frame
{
    CVPixelBufferRef img = [self createCVPixelBufferFromAVFrame:frame];
    if (img) {
        if (frame->format == AV_PIX_FMT_NV21) {
            [self.videoRenderer displayNV21PixelBuffer:img];
        } else {
            [self.videoRenderer displayPixelBuffer:img];
        }
        CVPixelBufferRelease(img);
    }
}

- (void)prepareRendererView
{
    MRMetalView *videoRenderer = [[MRMetalView alloc] initWithFrame:self.playbackView.bounds];
    [self.playbackView addSubview:videoRenderer];
#if TARGET_OS_OSX
    [self.playbackView addSubview:videoRenderer positioned:NSWindowBelow relativeTo:nil];
#endif
    videoRenderer.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.videoRenderer = videoRenderer;
}

- (void)parseURL:(NSString *)url
{
    if (self.player) {
        [self.player asyncStop];
        self.player = nil;
        
        [self.timer invalidate];
        self.timer = nil;
        
        [self.videoRenderer removeFromSuperview];
        self.videoRenderer = nil;
    }
    
    [self.audioFrameQueue cancel];
    self.audioFrameQueue = nil;
    
    [self.videoFrameQueue cancel];
    self.videoFrameQueue = nil;
    [self stopAudio];
    
    FFTPlayer0x31 *player = [[FFTPlayer0x31 alloc] init];
    player.contentPath = url;
    player.supportedPixelFormat  = MR_PIX_FMT_NV12;
    player.supportedSampleRate   = 48000;
    player.supportedSampleFormat = MR_SAMPLE_FMT_S16;
    
    __weakSelf__
    player.onStreamOpened = ^(FFTPlayer0x31 *player, NSDictionary * _Nonnull info) {
        __strongSelf__
        if (player != self.player) {
            return;
        }
        
        [self.indicatorView stopAnimation:nil];
        self.audioFrameQueue = [[FFTAudioFrameQueue alloc] init];
        [self setupAudioRender:player.supportedSampleFormat sampleRate:player.supportedSampleRate];
        [self playAudio];
        
        [self prepareRendererView];
        self.videoFrameQueue = [[FFTVideoFrameQueue alloc] init];
        
        NSLog(@"---VideoInfo-------------------");
        NSLog(@"%@",info);
        NSLog(@"----------------------");
    };
    
    player.onError = ^(FFTPlayer0x31 *player, NSError * _Nonnull e) {
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
    
    player.onDecoderFrame = ^(FFTPlayer0x31 *player, int type, int serial, AVFrame * _Nonnull frame) {
        __strongSelf__
        if (player != self.player) {
            return;
        }
        //video
        if (type == 1) {
            [self enQueueVideoFrame:frame];
        }
        //audio
        else if (type == 2) {
            [self enQueueAudioFrame:frame];
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
    rect.origin.y = CGRectGetHeight(rect) - 100;
    rect.size.height = 130;
#else
    CGFloat screenWidth = [[NSScreen mainScreen]frame].size.width;
    rect.size.height = MIN(screenWidth / 3.0, 210);
#endif
    [hudView setFrame:rect];
    
    hudView.autoresizingMask = NSViewWidthSizable;
    
    self.inputField.stringValue = KTestVideoURL1;
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

- (void)enQueueAudioFrame:(AVFrame *)frame
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
}

@end
