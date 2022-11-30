//
//  MRGAMViewController.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/11/22.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MRGAMViewController.h"
#import <FFmpegTutorial/FFTPlayer0x10.h>
#import <FFmpegTutorial/FFTHudControl.h>
#import <MRFFmpegPod/libavutil/frame.h>
#import "MRCoreAnimationView.h"
#import "MRCoreGraphicsView.h"
#import "MRCoreMediaView.h"
#import "MRRWeakProxy.h"

@interface MRGAMViewController ()
{
    MRPixelFormatMask _pixelFormat;
}

@property (strong) FFTPlayer0x10 *player;

@property (weak) NSView<MRVideoRenderingProtocol>* videoRenderer;

@property (weak) IBOutlet NSTextField *inputField;
@property (weak) IBOutlet NSProgressIndicator *indicatorView;
@property (weak) IBOutlet NSView *playbackView;
@property (weak) IBOutlet NSPopUpButton *formatPopup;

@property (strong) FFTHudControl *hud;
@property (weak) NSTimer *timer;
@property (copy) NSString *videoPixelInfo;

@end

@implementation MRGAMViewController

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
    
    NSString *renderer = NSStringFromClass([self.videoRenderer class]);
    renderer = [renderer stringByReplacingOccurrencesOfString:@"MR" withString:@""];
    renderer = [renderer stringByReplacingOccurrencesOfString:@"View" withString:@""];
    [self.hud setHudValue:renderer forKey:@"renderer"];
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

- (void)setupCoreAnimationPixelFormats
{
    [self.formatPopup removeAllItems];
    [self.formatPopup addItemsWithTitles:@[@"RGBA",@"RGB0",@"ARGB",@"0RGB",@"RGB24",@"RGB555"]];
    NSArray *tags = @[@(MR_PIX_FMT_MASK_RGBA),@(MR_PIX_FMT_MASK_RGB0),@(MR_PIX_FMT_MASK_ARGB),@(MR_PIX_FMT_MASK_0RGB),@(MR_PIX_FMT_MASK_RGB24),@(MR_PIX_FMT_MASK_RGB555)];
    for (int i = 0; i< [[self.formatPopup itemArray] count]; i++) {
        NSMenuItem * item = [self.formatPopup itemAtIndex:i];
        item.tag = [tags[i] intValue];
    }
    _pixelFormat = [[tags firstObject] intValue];
}

- (void)setupCoreGraphicsPixelFormats
{
    [self setupCoreAnimationPixelFormats];
}

- (void)setupCoreMediaPixelFormats
{
    [self.formatPopup removeAllItems];
    [self.formatPopup addItemsWithTitles:@[@"BGRA",@"ARGB",@"NV12",@"YUYV",@"UYVY"]];
    NSArray *tags = @[@(MR_PIX_FMT_MASK_BGRA),@(MR_PIX_FMT_MASK_ARGB),@(MR_PIX_FMT_MASK_NV12),@(MR_PIX_FMT_MASK_YUYV422),@(MR_PIX_FMT_MASK_UYVY422)];
    for (int i = 0; i< [[self.formatPopup itemArray] count]; i++) {
        NSMenuItem * item = [self.formatPopup itemAtIndex:i];
        item.tag = [tags[i] intValue];
    }
    _pixelFormat = [[tags firstObject] intValue];
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
    
    [self prepareCoreAnimationView];
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

- (BOOL)prepareRendererWidthClass:(Class)clazz
{
    if (self.videoRenderer && [self.videoRenderer isKindOfClass:clazz]) {
        return NO;
    }
    [self.videoRenderer removeFromSuperview];
    self.videoRenderer = nil;
    
    NSView<MRVideoRenderingProtocol> *videoRenderer = [[clazz alloc] initWithFrame:self.playbackView.bounds];
    [self.playbackView addSubview:videoRenderer];
    videoRenderer.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.videoRenderer = videoRenderer;
    return YES;
}

- (BOOL)prepareCoreAnimationView
{
    if ([self prepareRendererWidthClass:[MRCoreAnimationView class]]) {
        [self setupCoreAnimationPixelFormats];
        return YES;
    }
    return NO;
}

- (BOOL)prepareCoreGraphicsView
{
    if ([self prepareRendererWidthClass:[MRCoreGraphicsView class]]) {
        [self setupCoreGraphicsPixelFormats];
        return YES;
    }
    return NO;
}

- (BOOL)prepareCoreMediaView
{
    if ([self prepareRendererWidthClass:[MRCoreMediaView class]]) {
        [self setupCoreMediaPixelFormats];
        return YES;
    }
    return NO;
}

- (IBAction)onSelectedVideoRenderer:(NSPopUpButton *)sender
{
    NSMenuItem *item = [sender selectedItem];
    BOOL created = NO;
    if (item.tag == 1) {
        created = [self prepareCoreAnimationView];
    } else if (item.tag == 2) {
        created = [self prepareCoreGraphicsView];
    } else if (item.tag == 3) {
        created = [self prepareCoreMediaView];
    }
    
    if (created) {
        [self go:nil];
    }
}

- (IBAction)onSelectedVideMode:(NSPopUpButton *)sender
{
    NSMenuItem *item = [sender selectedItem];
        
    if (item.tag == 1) {
        [self.videoRenderer setContentMode:MRContentModeScaleToFill];
    } else if (item.tag == 2) {
        [self.videoRenderer setContentMode:MRContentModeScaleAspectFill];
    } else if (item.tag == 3) {
        [self.videoRenderer setContentMode:MRContentModeScaleAspectFit];
    }
}

- (IBAction)onSelectPixelFormat:(NSPopUpButton *)sender
{
    NSMenuItem *item = [sender selectedItem];
    if (_pixelFormat != (MRPixelFormatMask)item.tag) {
        _pixelFormat = (MRPixelFormatMask)item.tag;
        [self go:nil];
    }
}

@end
