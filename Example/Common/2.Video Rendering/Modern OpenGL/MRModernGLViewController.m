//
//  MRModernGLViewController.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/11/28.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MRModernGLViewController.h"
#import <FFmpegTutorial/FFTPlayer0x10.h>
#import <FFmpegTutorial/FFTHudControl.h>
#import <MRFFmpegPod/libavutil/frame.h>
#import "MRModernGLBGRAView.h"
#import "MRModernGLNV12View.h"
#import "MRModernGLNV21View.h"
#import "MRModernGLYUYVView.h"
#import "MRModernGLUYVYView.h"
#import "MRModernGLYUV420PView.h"
#import "MRRWeakProxy.h"
#import "NSFileManager+Sandbox.h"
#import "MRUtil.h"

@interface MRModernGLViewController ()
{
    CVPixelBufferPoolRef _pixelBufferPoolRef;
    MRPixelFormatMask _pixelFormat;
}

@property (strong) FFTPlayer0x10 *player;
@property (weak) NSView<MRVideoRenderingProtocol> *videoRenderer;

@property (weak) IBOutlet NSTextField *inputField;
@property (weak) IBOutlet NSProgressIndicator *indicatorView;
@property (weak) IBOutlet NSView *playbackView;

@property (strong) FFTHudControl *hud;
@property (weak) NSTimer *timer;
@property (copy) NSString *videoPixelInfo;

@end

@implementation MRModernGLViewController

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
    CVPixelBufferPoolRelease(_pixelBufferPoolRef);
    _pixelBufferPoolRef = NULL;
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
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%02d",self.player.videoFrameCount] forKey:@"v-frame"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%02d",self.player.audioPktCount] forKey:@"a-pack"];

    [self.hud setHudValue:[NSString stringWithFormat:@"%02d",self.player.videoPktCount] forKey:@"v-pack"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%@",self.videoPixelInfo] forKey:@"v-pixel"];
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

- (void)displayVideoFrame:(AVFrame *)frame
{
    const char *fmt_str = av_pixel_fmt_to_string(frame->format);
    self.videoPixelInfo = [NSString stringWithFormat:@"(%s)%dx%d",fmt_str,frame->width,frame->height];
    [self.videoRenderer displayAVFrame:frame];
}

- (void)parseURL:(NSString *)url
{
    if (self.player) {
        [self.player asyncStop];
        self.player = nil;
        
        [self.timer invalidate];
        self.timer = nil;
    }
    
    FFTPlayer0x10 *player = [[FFTPlayer0x10 alloc] init];
    player.contentPath = url;
    player.supportedPixelFormats = _pixelFormat;
    
    __weakSelf__
    player.onVideoOpened = ^(FFTPlayer0x10 *player, NSDictionary * _Nonnull info) {
        __strongSelf__
        if (player != self.player) {
            return;
        }
        //上一次 glview 完全销毁后，再创建
        [self prepareGLViewIfNeed];
        [self.indicatorView stopAnimation:nil];
        NSLog(@"---VideoInfo-------------------");
        NSLog(@"%@",info);
        NSLog(@"----------------------");
    };
    
    player.onError = ^(FFTPlayer0x10 *player, NSError * _Nonnull e) {
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
    
    player.onDecoderFrame = ^(FFTPlayer0x10 *player, int type, int serial, AVFrame * _Nonnull frame) {
        __strongSelf__
        if (player != self.player) {
            return;
        }
        //video
        if (type == 1) {
            @autoreleasepool {
                [self displayVideoFrame:frame];
            }
            mr_msleep(40);
        }
        //audio
        else if (type == 2) {
        }
    };
    [player prepareToPlay];
    [player play];
    self.player = player;
    
    [self prepareTickTimerIfNeed];
    [self.indicatorView startAnimation:nil];
}

- (void)prepareGLViewWidthClass:(Class)clazz
{
    if (self.videoRenderer && [self.videoRenderer isKindOfClass:clazz]) {
        return;
    }
    [self.videoRenderer removeFromSuperview];
    self.videoRenderer = nil;
    
    NSView<MRVideoRenderingProtocol> *videoRenderer = [[clazz alloc] initWithFrame:self.playbackView.bounds];
    [self.playbackView addSubview:videoRenderer];
    videoRenderer.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.videoRenderer = videoRenderer;
}

- (void)prepareGLViewIfNeed
{
    Class clazz = NULL;
    if (_pixelFormat == MR_PIX_FMT_MASK_BGRA) {
        clazz = [MRModernGLBGRAView class];
    } else if (_pixelFormat == MR_PIX_FMT_MASK_NV12) {
        clazz = [MRModernGLNV12View class];
    } else if (_pixelFormat == MR_PIX_FMT_MASK_NV21) {
        clazz = [MRModernGLNV21View class];
    } else if (_pixelFormat == MR_PIX_FMT_MASK_YUV420P) {
        clazz = [MRModernGLYUV420PView class];
    } else if (_pixelFormat == MR_PIX_FMT_MASK_UYVY422) {
        clazz = [MRModernGLUYVYView class];
    } else if (_pixelFormat == MR_PIX_FMT_MASK_YUYV422) {
        clazz = [MRModernGLYUYVView class];
    }
    [self prepareGLViewWidthClass:clazz];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.hud = [[FFTHudControl alloc] init];
    NSView *hudView = [self.hud contentView];
    [self.view addSubview:hudView];
    CGRect rect = self.playbackView.bounds;
    CGFloat screenWidth = [[NSScreen mainScreen]frame].size.width;
    rect.size.width = MIN(screenWidth / 5.0, 150);
    rect.origin.x = CGRectGetWidth(self.view.bounds) - rect.size.width;
    [hudView setFrame:rect];
    hudView.autoresizingMask = NSViewMinXMargin | NSViewHeightSizable;
    
    self.inputField.stringValue = KTestVideoURL1;
    _pixelFormat = MR_PIX_FMT_MASK_BGRA;
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
    if (!self.player) {
        return;
    }
    NSImage *img = nil;//[self.videoRenderer snapshot];
    if (!img) {
        return;
    }
    NSString *videoName = [[NSURL URLWithString:self.player.contentPath] lastPathComponent];
    if ([videoName isEqualToString:@"/"]) {
        videoName = @"未知";
    }
    NSString *folder = [NSFileManager mr_DirWithType:NSPicturesDirectory WithPathComponents:@[@"FFmpegTutorial",videoName]];
    long timestamp = [NSDate timeIntervalSinceReferenceDate] * 1000;
    NSString *filePath = [folder stringByAppendingPathComponent:[NSString stringWithFormat:@"%ld.jpg",timestamp]];
    [NSFileManager mr_saveImageToFile:[MRUtil nsImage2cg:img] path:filePath];
    NSLog(@"img:%@",filePath);
}

- (IBAction)onSelectedVideMode:(NSPopUpButton *)sender
{
    NSMenuItem *item = [sender selectedItem];
        
    if (item.tag == 1) {
        [self.videoRenderer setRenderingMode:MRRenderingModeScaleToFill];
    } else if (item.tag == 2) {
        [self.videoRenderer setRenderingMode:MRRenderingModeScaleAspectFill];
    } else if (item.tag == 3) {
        [self.videoRenderer setRenderingMode:MRRenderingModeScaleAspectFit];
    }
}

- (IBAction)onSelectPixelFormat:(NSPopUpButton *)sender
{
    NSMenuItem *item = [sender selectedItem];
    MRPixelFormatMask pixelFormat = 0;
    if (item.tag == 1) {
        pixelFormat = MR_PIX_FMT_MASK_BGRA;
    } else if (item.tag == 2) {
        pixelFormat = MR_PIX_FMT_MASK_NV12;
    } else if (item.tag == 3) {
        pixelFormat = MR_PIX_FMT_MASK_NV21;
    } else if (item.tag == 4) {
        pixelFormat = MR_PIX_FMT_MASK_YUV420P;
    } else if (item.tag == 5) {
        pixelFormat = MR_PIX_FMT_MASK_UYVY422;
    } else if (item.tag == 6) {
        pixelFormat = MR_PIX_FMT_MASK_YUYV422;
    }
    
    if (pixelFormat != _pixelFormat) {
        _pixelFormat = pixelFormat;
        [self.videoRenderer removeFromSuperview];
        self.videoRenderer = nil;
        [self go:nil];
    }
}

@end
