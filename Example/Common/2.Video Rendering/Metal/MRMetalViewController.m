//
//  MRMetalViewController.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/12/10.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MRMetalViewController.h"
#import <FFmpegTutorial/FFTPlayer0x10.h>
#import <FFmpegTutorial/FFTHudControl.h>
#import <FFmpegTutorial/FFTConvertUtil.h>
#import <libavutil/frame.h>
#import "MRMetalView.h"
#import "MRRWeakProxy.h"
#import "NSFileManager+Sandbox.h"

@interface MRMetalViewController ()
{
    CVPixelBufferPoolRef _pixelBufferPoolRef;
    MRPixelFormatMask _pixelFormat;
    MRRenderingMode _renderingMode;
}

@property (strong) FFTPlayer0x10 *player;

@property (weak) MRMetalView *videoRenderer;
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

@implementation MRMetalViewController

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
    
    NSString *renderer = NSStringFromClass([self.videoRenderer class]);
    renderer = [renderer stringByReplacingOccurrencesOfString:@"MR" withString:@""];
    renderer = [renderer stringByReplacingOccurrencesOfString:@"View" withString:@""];
    [self.hud setHudValue:renderer forKey:@"renderer"];
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

- (void)displayVideoFrame:(AVFrame *)frame
{
    const char *fmt_str = av_pixel_fmt_to_string(frame->format);
    self.videoPixelInfo = [NSString stringWithFormat:@"(%s)%dx%d",fmt_str,frame->width,frame->height];
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
    [self.videoRenderer setRenderingMode:_renderingMode];
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
    
    FFTPlayer0x10 *player = [[FFTPlayer0x10 alloc] init];
    player.contentPath = url;
    player.supportedPixelFormats = _pixelFormat;
    __weakSelf__
    player.onVideoOpened = ^(FFTPlayer0x10 *player, NSDictionary * _Nonnull info) {
        __strongSelf__
        if (player != self.player) {
            return;
        }
        [self prepareRendererView];
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
    
#if TARGET_OS_IPHONE
    [self setupPixelFormats];
#else
    _pixelFormat = MR_PIX_FMT_MASK_BGRA;
#endif
    _renderingMode = MRRenderingModeScaleAspectFit;
}

#if TARGET_OS_IPHONE
- (void)setupPixelFormats
{
    NSArray *fmts = @[@"BGRA",@"BGR0",@"NV12",@"NV21",@"UYVY",@"YUYV",@"YUV420P"];
    NSArray *tags = @[@(MR_PIX_FMT_MASK_BGRA),@(MR_PIX_FMT_MASK_BGR0),@(MR_PIX_FMT_MASK_NV12),@(MR_PIX_FMT_MASK_NV21),@(MR_PIX_FMT_MASK_UYVY422),@(MR_PIX_FMT_MASK_YUYV422),@(MR_PIX_FMT_MASK_YUV420P)];
    [self.formatSegCtrl removeAllSegments];
    for (int i = 0; i < [fmts count]; i++) {
        NSString *title = fmts[i];
        [self.formatSegCtrl insertSegmentWithTitle:title atIndex:i animated:NO tag:[tags[i] intValue]];
    }
    self.formatSegCtrl.selectedSegmentIndex = 0;
    _pixelFormat = [[tags firstObject] intValue];
}

- (void)touchesBegan:(NSSet<UITouch *> *)touches withEvent:(UIEvent *)event
{
    UIView *ctrlPanel = self.formatSegCtrl.superview;
    ctrlPanel.hidden = !ctrlPanel.isHidden;
    self.hud.contentView.hidden = !ctrlPanel.isHidden;
}
#endif

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

- (IBAction)onSaveSnapshot:(NSButton *)sender
{
    if (!self.player) {
        return;
    }
    CGImageRef img = [self.videoRenderer snapshot];
    if (!img) {
        return;
    }
    NSString *videoName = [[NSURL URLWithString:self.player.contentPath] lastPathComponent];
    if ([videoName isEqualToString:@"/"]) {
        videoName = @"未知";
    }
    NSString *folder = [NSFileManager mr_DirWithType:NSCachesDirectory WithPathComponents:@[@"FFmpegTutorial",videoName]];
    if (folder) {
        long timestamp = [NSDate timeIntervalSinceReferenceDate] * 1000;
        NSString *filePath = [folder stringByAppendingPathComponent:[NSString stringWithFormat:@"%ld.jpg",timestamp]];
        [NSFileManager mr_saveImageToFile:img path:filePath];
        NSLog(@"img:%@",filePath);
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
    
    if (item.tag == 1) {
        _pixelFormat = MR_PIX_FMT_MASK_BGRA;
    } else if (item.tag == 2) {
        _pixelFormat = MR_PIX_FMT_MASK_NV12;
    } else if (item.tag == 3) {
        _pixelFormat = MR_PIX_FMT_MASK_NV21;
    } else if (item.tag == 4) {
        _pixelFormat = MR_PIX_FMT_MASK_YUV420P;
    } else if (item.tag == 5) {
        _pixelFormat = MR_PIX_FMT_MASK_UYVY422;
    } else if (item.tag == 6) {
        _pixelFormat = MR_PIX_FMT_MASK_YUYV422;
    }
    
    [self go:nil];
}

#else
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
