//
//  MR0x30ViewController.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/7/16.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x30ViewController.h"
#import <FFmpegTutorial/FFTPlayer0x30.h>
#import <FFmpegTutorial/FFTHudControl.h>
#import <FFmpegTutorial/FFTConvertUtil.h>
#import <FFmpegTutorial/FFTDispatch.h>
#import <FFmpegTutorial/FFTPlayerHeader.h>
#import <MRFFmpegPod/libavutil/frame.h>
#import "MRRWeakProxy.h"
#import "NSFileManager+Sandbox.h"
#import "MRUtil.h"
#import "MR0x30VideoRenderer.h"
#import "MR0x30AudioRenderer.h"
#import "FFTAudioFrameQueue.h"
#import "FFTVideoFrameQueue.h"

//将音频裸流PCM写入到文件
#define DEBUG_RECORD_PCM_TO_FILE 0

@interface MR0x30ViewController ()
{
#if DEBUG_RECORD_PCM_TO_FILE
    FILE * file_pcm_l;
    FILE * file_pcm_r;
#endif
}

@property (strong) FFTPlayer0x30 *player;
@property (weak) IBOutlet NSTextField *inputField;
@property (weak) IBOutlet NSProgressIndicator *indicatorView;
@property (weak) IBOutlet MR0x30VideoRenderer *videoRenderer;

@property (strong) FFTHudControl *hud;
@property (weak) NSTimer *timer;
@property (copy) NSString *videoPixelInfo;
@property (copy) NSString *audioSamplelInfo;
@property (nonatomic,assign) int sampleRate;
@property (nonatomic,assign) MRPixelFormat videoFmt;
@property (nonatomic,assign) MRSampleFormat audioFmt;

//音频渲染
@property (nonatomic,strong) MR0x30AudioRenderer * audioRender;
@property (atomic,strong) FFTAudioFrameQueue *audioFrameQueue;
@property (atomic,strong) FFTVideoFrameQueue *videoFrameQueue;
@end

@implementation MR0x30ViewController

- (void)_stop
{
    [self.audioFrameQueue cancel];
    [self stopAudio];
    
#if DEBUG_RECORD_PCM_TO_FILE
    [self close_all_file];
#endif
    
    [self.videoFrameQueue cancel];
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
    
    //假定视频帧率是 30；
    MRRWeakProxy *weakProxy = [MRRWeakProxy weakProxyWithTarget:self];
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1.0/30 target:weakProxy selector:@selector(onTimer:) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    self.timer = timer;
}

- (void)updateHud
{
    [self.hud setHudValue:[NSString stringWithFormat:@"%02d",self.player.audioFrameCount] forKey:@"a-frame"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%02d",self.player.videoFrameCount] forKey:@"v-frame"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%02d",self.player.audioPktCount] forKey:@"a-pack"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%02d",self.player.videoPktCount] forKey:@"v-pack"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%@",self.videoPixelInfo] forKey:@"v-pixel"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%@",self.audioSamplelInfo] forKey:@"a-sample"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%d",[self.audioFrameQueue count]] forKey:@"a-frame-q"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%d",[self.videoFrameQueue count]] forKey:@"v-frame-q"];
    
    [self.hud setHudValue:self.audioRender.name forKey:@"a-renderer"];
}

- (void)onTimer:(NSTimer *)sender
{
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

- (void)parseURL:(NSString *)url
{
    if (self.player) {
        [self.player asyncStop];
        self.player = nil;
    }
    [self.audioFrameQueue cancel];
    self.audioFrameQueue = nil;
    [self.videoFrameQueue cancel];
    self.videoFrameQueue = nil;
    
    [self stopAudio];
    [self.timer invalidate];
    self.timer = nil;

    [self close_all_file];
    [self.indicatorView startAnimation:nil];
    
    FFTPlayer0x30 *player = [[FFTPlayer0x30 alloc] init];
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
        
        int width  = [info[kFFTPlayer0x30Width] intValue];
        int height = [info[kFFTPlayer0x30Height] intValue];
        self.videoRenderer.videoSize = CGSizeMake(width, height);
        self.audioFrameQueue = [[FFTAudioFrameQueue alloc] init];
        [self setupAudioRender:self.audioFmt sampleRate:self.sampleRate];
        
        double streamTimeBase  = [info[kFFTPlayer0x30StreamTimeBase] doubleValue];
        double averageDuration = [info[kFFTPlayer0x30AverageDuration] doubleValue];
        
        self.videoFrameQueue = [[FFTVideoFrameQueue alloc] init];
        self.videoFrameQueue.streamTimeBase = streamTimeBase;
        self.videoFrameQueue.averageDuration = averageDuration;
        
#warning AudioQueue需要等buffer填充满了才能播放，这里为了简单就先延迟2s再播放
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            [self.indicatorView stopAnimation:nil];
            [self prepareTickTimerIfNeed];
            [self playAudio];
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
    
    player.onDecoderFrame = ^(int type, int serial, AVFrame * _Nonnull frame) {
        __strongSelf__
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
}

#pragma - mark Video

- (void)enQueueVideoFrame:(AVFrame *)frame
{
    const char *fmt_str = av_pixel_fmt_to_string(frame->format);
    
    self.videoPixelInfo = [NSString stringWithFormat:@"(%s)%dx%d",fmt_str,frame->width,frame->height];
    [self.videoFrameQueue enQueue:frame];
}

- (void)displayVideoFrame:(AVFrame *)frame
{
    [self.videoRenderer displayAVFrame:frame];
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
    MR0x30AudioRenderer *audioRender = [[MR0x30AudioRenderer alloc] initWithFmt:fmt preferredAudioQueue:YES sampleRate:sampleRate];
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
