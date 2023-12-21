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
#import <libavutil/frame.h>
#import "MRCoreAnimationView.h"
#import "MRCoreGraphicsView.h"
#import "MRCoreMediaView.h"
#import "MRRWeakProxy.h"

@interface MRGAMViewController ()
{
    MRPixelFormatMask _pixelFormat;
    MRRenderingMode _renderingMode;
}

@property (strong) FFTPlayer0x10 *player;

@property (weak) NSView<MRVideoRenderingProtocol>* videoRenderer;
@property (assign) Class<MRVideoRenderingProtocol> renderingClazz;
@property (weak) IBOutlet NSTextField *inputField;
@property (weak) IBOutlet NSProgressIndicator *indicatorView;
@property (weak) IBOutlet NSView *playbackView;
#if TARGET_OS_OSX
@property (weak) IBOutlet NSPopUpButton *formatPopup;
#else
@property (weak, nonatomic) IBOutlet MRSegmentedControl *formatSegCtrl;
#endif
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
    [self alert:@"知道了" msg:msg];
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
        [self prepareRendererWidthClass:self.renderingClazz];
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
    NSArray *fmts = @[@"RGBA",@"RGB0",@"ARGB",@"0RGB",@"RGB24",@"RGB555"];
    NSArray *tags = @[@(MR_PIX_FMT_MASK_RGBA),@(MR_PIX_FMT_MASK_RGB0),@(MR_PIX_FMT_MASK_ARGB),@(MR_PIX_FMT_MASK_0RGB),@(MR_PIX_FMT_MASK_RGB24),@(MR_PIX_FMT_MASK_RGB555)];
    
#if TARGET_OS_OSX
    [self.formatPopup removeAllItems];
    [self.formatPopup addItemsWithTitles:fmts];
    for (int i = 0; i < [[self.formatPopup itemArray] count]; i++) {
        NSMenuItem * item = [self.formatPopup itemAtIndex:i];
        item.tag = [tags[i] intValue];
    }
#else
    [self.formatSegCtrl removeAllSegments];
    for (int i = 0; i < [fmts count]; i++) {
        NSString *title = fmts[i];
        [self.formatSegCtrl insertSegmentWithTitle:title atIndex:i animated:NO tag:[tags[i] intValue]];
    }
    self.formatSegCtrl.selectedSegmentIndex = 0;
#endif
    _pixelFormat = [[tags firstObject] intValue];
}

- (void)setupCoreGraphicsPixelFormats
{
    [self setupCoreAnimationPixelFormats];
}

- (void)setupCoreMediaPixelFormats
{
    NSArray *fmts = @[@"BGRA",@"ARGB",@"NV12",@"YUYV",@"UYVY"];
    NSArray *tags = @[@(MR_PIX_FMT_MASK_BGRA),@(MR_PIX_FMT_MASK_ARGB),@(MR_PIX_FMT_MASK_NV12),@(MR_PIX_FMT_MASK_YUYV422),@(MR_PIX_FMT_MASK_UYVY422)];
#if TARGET_OS_OSX
    [self.formatPopup removeAllItems];
    [self.formatPopup addItemsWithTitles:fmts];
    for (int i = 0; i < [[self.formatPopup itemArray] count]; i++) {
        NSMenuItem * item = [self.formatPopup itemAtIndex:i];
        item.tag = [tags[i] intValue];
    }
#else
    [self.formatSegCtrl removeAllSegments];
    for (int i = 0; i < [fmts count]; i++) {
        NSString *title = fmts[i];
        [self.formatSegCtrl insertSegmentWithTitle:title atIndex:i animated:NO tag:[tags[i] intValue]];
    }
    self.formatSegCtrl.selectedSegmentIndex = 0;
#endif
    _pixelFormat = [[tags firstObject] intValue];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.hud = [[FFTHudControl alloc] init];
    NSView *hudView = [self.hud contentView];
    [self.playbackView addSubview:hudView];
    hudView.layer.zPosition = 100;
    CGRect rect = self.playbackView.bounds;
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
    _renderingMode = MRRenderingModeScaleAspectFit;
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
#if TARGET_OS_IPHONE
    [self.inputField resignFirstResponder];
#endif
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
#if TARGET_OS_OSX
    [self.playbackView addSubview:videoRenderer positioned:NSWindowBelow relativeTo:nil];
#endif
    videoRenderer.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.videoRenderer = videoRenderer;
    [self.videoRenderer setRenderingMode:_renderingMode];
    return YES;
}

- (BOOL)prepareCoreAnimationView
{
    if (self.renderingClazz != [MRCoreAnimationView class]) {
        [self setupCoreAnimationPixelFormats];
        self.renderingClazz = [MRCoreAnimationView class];
        return YES;
    }
    return NO;
}

- (BOOL)prepareCoreGraphicsView
{
    if (self.renderingClazz != [MRCoreGraphicsView class]) {
        [self setupCoreGraphicsPixelFormats];
        self.renderingClazz = [MRCoreGraphicsView class];
        return YES;
    }
    return NO;
}

- (BOOL)prepareCoreMediaView
{
    if (self.renderingClazz != [MRCoreMediaView class]) {
        [self setupCoreMediaPixelFormats];
        self.renderingClazz = [MRCoreMediaView class];
        return YES;
    }
    return NO;
}

- (void)doSelectedVideoRenderer:(int)tag
{
    BOOL created = NO;
    if (tag == 1) {
        created = [self prepareCoreAnimationView];
    } else if (tag == 2) {
        created = [self prepareCoreGraphicsView];
    } else if (tag == 3) {
        created = [self prepareCoreMediaView];
    }
    
    if (created) {
        [self go:nil];
    }
}

- (void)doSelectedVideMode:(int)tag
{
    MRRenderingMode renderingMode = MRRenderingModeScaleToFill;
    if (tag == 1) {
        renderingMode = MRRenderingModeScaleToFill;
    } else if (tag == 2) {
        renderingMode = MRRenderingModeScaleAspectFill;
    } else if (tag == 3) {
        renderingMode = MRRenderingModeScaleAspectFit;
    }
    if (_renderingMode != renderingMode) {
        _renderingMode = renderingMode;
        [self.videoRenderer setRenderingMode:renderingMode];
    }
}

- (void)doSelectPixelFormat:(MRPixelFormatMask)fmt
{
    if (_pixelFormat != fmt) {
        _pixelFormat = fmt;
        [self go:nil];
    }
}

#if TARGET_OS_OSX
- (IBAction)onSelectedVideoRenderer:(NSPopUpButton *)sender
{
    NSMenuItem *item = [sender selectedItem];
    [self doSelectedVideoRenderer:(int)item.tag];
}

- (IBAction)onSelectedVideMode:(NSPopUpButton *)sender
{
    NSMenuItem *item = [sender selectedItem];
    [self doSelectedVideMode:(int)item.tag];
}

- (IBAction)onSelectPixelFormat:(NSPopUpButton *)sender
{
    NSMenuItem *item = [sender selectedItem];
    [self doSelectPixelFormat:(MRPixelFormatMask)item.tag];
}
#else

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    UIView *ctrlPanel = self.formatSegCtrl.superview;
    ctrlPanel.hidden = !ctrlPanel.isHidden;
    self.hud.contentView.hidden = !ctrlPanel.isHidden;
}

- (IBAction)onSelectedVideoRenderer:(MRSegmentedControl *)sender
{
    [self doSelectedVideoRenderer:(int)[sender tagForCurrentSelected] + 1];
}

- (IBAction)onSelectedVideMode:(MRSegmentedControl *)sender
{
    [self doSelectedVideMode:(int)[sender tagForCurrentSelected] + 1];
}

- (IBAction)onSelectPixelFormat:(MRSegmentedControl *)sender
{
    [self doSelectPixelFormat:(MRPixelFormatMask)[sender tagForCurrentSelected]];
}

#endif

@end
