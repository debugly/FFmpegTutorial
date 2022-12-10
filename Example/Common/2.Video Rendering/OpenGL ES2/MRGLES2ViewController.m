//
//  MRGLES2ViewController.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/12/10.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MRGLES2ViewController.h"
#import <FFmpegTutorial/FFTPlayer0x10.h>
#import <FFmpegTutorial/FFTHudControl.h>
#import <MRFFmpegPod/libavutil/frame.h>
#import "MRGLES2RGBXView.h"
#import "MRGLES2NV12View.h"
#import "MRGLES2NV21View.h"
#import "MRRWeakProxy.h"

@interface MRGLES2ViewController ()
{
    MRPixelFormatMask _pixelFormat;
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

@implementation MRGLES2ViewController

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

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    self.hud = [[FFTHudControl alloc] init];
    NSView *hudView = [self.hud contentView];
    [self.playbackView addSubview:hudView];
    hudView.layer.zPosition = 100;
    CGRect rect = self.playbackView.bounds;
#if TARGET_OS_IPHONE
    rect.size.width = 300;
#else
    CGFloat screenWidth = [[NSScreen mainScreen]frame].size.width;
    rect.size.width = MIN(screenWidth / 5.0, 150);
#endif
    rect.origin.x = CGRectGetWidth(self.view.bounds) - rect.size.width;
    [hudView setFrame:rect];
    
    hudView.autoresizingMask = NSViewMinXMargin | NSViewHeightSizable;
    
    self.inputField.stringValue = KTestVideoURL1;
    
    [self setupPixelFormats];
}

- (void)setupPixelFormats
{
    NSArray *fmts = @[@"BGRA",@"BGR0",@"RGBA",@"RGB0",@"NV12",@"NV21",@"YUYV",@"UYVY",@"YUV420P"];
    NSArray *tags = @[@(MR_PIX_FMT_MASK_BGRA),@(MR_PIX_FMT_MASK_BGR0),@(MR_PIX_FMT_MASK_RGBA),@(MR_PIX_FMT_MASK_RGB0),@(MR_PIX_FMT_MASK_NV12),@(MR_PIX_FMT_MASK_NV21),@(MR_PIX_FMT_MASK_YUYV422),@(MR_PIX_FMT_MASK_UYVY422),@(MR_PIX_FMT_MASK_YUV420P)];
    [self.formatSegCtrl removeAllSegments];
    for (int i = 0; i < [fmts count]; i++) {
        NSString *title = fmts[i];
        [self.formatSegCtrl insertSegmentWithTitle:title atIndex:i animated:NO tag:[tags[i] intValue]];
    }
    self.formatSegCtrl.selectedSegmentIndex = 0;
    _pixelFormat = [[tags firstObject] intValue];
    [self updateRenderingClazz];
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
    //如果这里释放后，立马创建，会导致OpenGL错误：GL_INVALID_VALUE
    [self.videoRenderer removeFromSuperview];
    self.videoRenderer = nil;
    NSView<MRVideoRenderingProtocol> *videoRenderer = [[clazz alloc] initWithFrame:self.playbackView.bounds];
    [self.playbackView addSubview:videoRenderer];
#if TARGET_OS_OSX
    [self.playbackView addSubview:videoRenderer positioned:NSWindowBelow relativeTo:nil];
#endif
    videoRenderer.autoresizingMask = NSViewWidthSizable | NSViewHeightSizable;
    self.videoRenderer = videoRenderer;
    return YES;
}

- (void)updateRenderingClazz
{
    Class<MRVideoRenderingProtocol> renderingClazz = NULL;
    if (_pixelFormat == MR_PIX_FMT_MASK_BGRA ||
        _pixelFormat == MR_PIX_FMT_MASK_BGR0 ||
        _pixelFormat == MR_PIX_FMT_MASK_RGBA ||
        _pixelFormat == MR_PIX_FMT_MASK_RGB0)  {
        renderingClazz = [MRGLES2RGBXView class];
    } else if (_pixelFormat == MR_PIX_FMT_MASK_NV12)  {
        renderingClazz = [MRGLES2NV12View class];
    } else if (_pixelFormat == MR_PIX_FMT_MASK_NV21)  {
        renderingClazz = [MRGLES2NV21View class];
    } else if (_pixelFormat == MR_PIX_FMT_MASK_YUV420P)  {
        
    }
    self.renderingClazz = renderingClazz;
    //放在这里销毁的目的是避免和新renderer创建靠得太近，老的正在销毁时使用新的渲染会出错！
    [self.videoRenderer removeFromSuperview];
    self.videoRenderer = nil;
}

- (void)doSelectedVideMode:(int)tag
{
    if (tag == 1) {
        [self.videoRenderer setRenderingMode:MRRenderingModeScaleToFill];
    } else if (tag == 2) {
        [self.videoRenderer setRenderingMode:MRRenderingModeScaleAspectFill];
    } else if (tag == 3) {
        [self.videoRenderer setRenderingMode:MRRenderingModeScaleAspectFit];
    }
}

- (void)doSelectPixelFormat:(MRPixelFormatMask)fmt
{
    if (_pixelFormat != fmt) {
        _pixelFormat = fmt;
        [self updateRenderingClazz];
        [self go:nil];
    }
}

- (IBAction)onSelectedVideMode:(MRSegmentedControl *)sender
{
    [self doSelectedVideMode:(int)[sender tagForCurrentSelected] + 1];
}

- (IBAction)onSelectPixelFormat:(MRSegmentedControl *)sender
{
    [self doSelectPixelFormat:(MRPixelFormatMask)[sender tagForCurrentSelected]];
}

@end
