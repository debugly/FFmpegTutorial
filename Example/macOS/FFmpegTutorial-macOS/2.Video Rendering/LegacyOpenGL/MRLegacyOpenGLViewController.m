//
//  MRLegacyOpenGLViewController.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/11/27.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MRLegacyOpenGLViewController.h"
#import <FFmpegTutorial/FFTPlayer0x10.h>
#import <FFmpegTutorial/FFTHudControl.h>
#import <MRFFmpegPod/libavutil/frame.h>
#import "MRLegacyBGRAView.h"
#import "MRLegacyNV12View.h"
#import "MRLegacyNV21View.h"
#import "MRLegacyYUYVView.h"
#import "MRLegacyUYVYView.h"
#import "MRLegacyYUV420PView.h"
#import "MRRWeakProxy.h"
#import "NSFileManager+Sandbox.h"
#import "MRUtil.h"

@interface MRLegacyOpenGLViewController ()
{
    CVPixelBufferPoolRef _pixelBufferPoolRef;
    MRPixelFormatMask _pixelFormat;
}

@property (strong) FFTPlayer0x10 *player;
@property (weak) NSView<MRLegacyOpenGLVideoRendererProtocol> *videoRenderer;

@property (weak) IBOutlet NSTextField *inputField;
@property (weak) IBOutlet NSProgressIndicator *indicatorView;
@property (weak) IBOutlet NSView *playbackView;

@property (strong) FFTHudControl *hud;
@property (weak) NSTimer *timer;
@property (copy) NSString *videoPixelInfo;

@end

@implementation MRLegacyOpenGLViewController

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
    
    if (!self.hud) {
        self.hud = [[FFTHudControl alloc] init];
        NSView *hudView = [self.hud contentView];
        [self.view addSubview:hudView];
        CGRect rect = self.videoRenderer.bounds;
        CGFloat screenWidth = [[NSScreen mainScreen]frame].size.width;
        rect.size.width = MIN(screenWidth / 5.0, 150);
        rect.origin.x = CGRectGetWidth(self.view.bounds) - rect.size.width;
        [hudView setFrame:rect];
        hudView.autoresizingMask = NSViewMinXMargin | NSViewHeightSizable;
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

- (void)prepareGLView:(Class)clazz
{
    [self.videoRenderer removeFromSuperview];
    self.videoRenderer = nil;
    
    NSView<MRLegacyOpenGLVideoRendererProtocol> *videoRenderer = [[clazz alloc] initWithFrame:self.playbackView.bounds];
    [self.playbackView addSubview:videoRenderer];
    videoRenderer.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.videoRenderer = videoRenderer;
}

- (void)prepareBGRAGLView
{
    _pixelFormat = MR_PIX_FMT_MASK_BGRA;
    [self prepareGLView:[MRLegacyBGRAView class]];
}

- (void)prepareNV12GLView
{
    _pixelFormat = MR_PIX_FMT_MASK_NV12;
    [self prepareGLView:[MRLegacyNV12View class]];
}

- (void)prepareNV21GLView
{
    _pixelFormat = MR_PIX_FMT_MASK_NV21;
    [self prepareGLView:[MRLegacyNV21View class]];
}

- (void)prepareYUYVGLView
{
    _pixelFormat = MR_PIX_FMT_MASK_YUYV422;
    [self prepareGLView:[MRLegacyYUYVView class]];
}

- (void)prepareUYVYGLView
{
    _pixelFormat = MR_PIX_FMT_MASK_UYVY422;
    [self prepareGLView:[MRLegacyUYVYView class]];
}

- (void)prepareYUV420PGLView
{
    _pixelFormat = MR_PIX_FMT_MASK_YUV420P;
    [self prepareGLView:[MRLegacyYUV420PView class]];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.inputField.stringValue = KTestVideoURL1;
    [self prepareBGRAGLView];
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
    [MRUtil saveImageToFile:[MRUtil nsImage2cg:img] path:filePath];
    NSLog(@"img:%@",filePath);
}

- (IBAction)onSelectedVideMode:(NSPopUpButton *)sender
{
    NSMenuItem *item = [sender selectedItem];
        
    if (item.tag == 1) {
        [self.videoRenderer setContentMode:MRLGLContentModeScaleToFill];
    } else if (item.tag == 2) {
        [self.videoRenderer setContentMode:MRLGLContentModeScaleAspectFill];
    } else if (item.tag == 3) {
        [self.videoRenderer setContentMode:MRLGLContentModeScaleAspectFit];
    }
}

- (IBAction)onSelectPixelFormat:(NSPopUpButton *)sender
{
    NSMenuItem *item = [sender selectedItem];
    
    if (item.tag == 1) {
        [self prepareBGRAGLView];
    } else if (item.tag == 2) {
        [self prepareNV12GLView];
    } else if (item.tag == 3) {
        [self prepareNV21GLView];
    } else if (item.tag == 4) {
        [self prepareYUV420PGLView];
    } else if (item.tag == 5) {
        [self prepareUYVYGLView];
    } else if (item.tag == 6) {
        [self prepareYUYVGLView];
    }
    
    [self go:nil];
}

@end
