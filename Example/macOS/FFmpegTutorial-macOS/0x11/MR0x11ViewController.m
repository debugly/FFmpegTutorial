//
//  MR0x11ViewController.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/7/9.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x11ViewController.h"
#import <FFmpegTutorial/FFPlayer0x11.h>
#import "MRRWeakProxy.h"
#import "MR0x11VideoRenderer.h"

@interface MR0x11ViewController ()<FFPlayer0x11Delegate>

@property (strong) FFPlayer0x11 *player;
@property (weak) IBOutlet NSTextField *inputField;
@property (assign) IBOutlet NSTextView *textView;
@property (weak) IBOutlet NSProgressIndicator *indicatorView;
@property (weak) IBOutlet MR0x11VideoRenderer *videoRenderer;

@property (assign) NSInteger ignoreScrollBottom;
@property (weak) NSTimer *timer;
@property (assign) BOOL scrolling;

@end

@implementation MR0x11ViewController

- (void)dealloc
{
    if (_timer) {
        [_timer invalidate];
        _timer = nil;
    }
    
    if (_player) {
        [_player stop];
        _player = nil;
    }
    
    _textView.delegate = nil;
    _textView = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)appendMsg:(NSString *)txt
{
    self.textView.string = [self.textView.string stringByAppendingFormat:@"\n%@",txt];
    if (self.scrolling) {
        return;
    }
    [self.textView scrollToEndOfDocument:nil];
}

- (void)prepareTickTimerIfNeed
{
    if ([self.timer isValid]) {
        return;
    }
    MRRWeakProxy *weakProxy = [MRRWeakProxy weakProxyWithTarget:self];
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1 target:weakProxy selector:@selector(onTimer:) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    self.timer = timer;
}

- (void)reveiveFrameToRenderer:(CGImageRef)cgImage
{
    size_t width = CGImageGetWidth(cgImage);
    size_t height = CGImageGetHeight(cgImage);
    
    NSImage *img = [[NSImage alloc] initWithCGImage:cgImage size:CGSizeMake(width, height)];
    dispatch_sync(dispatch_get_main_queue(), ^{
        self.videoRenderer.image = img;
    });
}

- (void)onTimer:(NSTimer *)sender
{
    [self appendMsg:[self.player peekPacketBufferStatus]];
}

- (void)parseURL:(NSString *)url
{
    if (self.player) {
        [self.player stop];
        self.player = nil;
        [self.timer invalidate];
        self.timer = nil;
    }
    
    FFPlayer0x11 *player = [[FFPlayer0x11 alloc] init];
    player.contentPath = url;
    
    [self.indicatorView startAnimation:nil];
    __weakSelf__
    [player onError:^{
        __strongSelf__
        [self.indicatorView stopAnimation:nil];
        self.textView.string = [self.player.error localizedDescription];
        self.player = nil;
        [self.timer invalidate];
        self.timer = nil;
    }];
    
    [player onPacketBufferFull:^{
        __strongSelf__
        MR_sync_main_queue(^{
            [self.indicatorView stopAnimation:nil];
            [self prepareTickTimerIfNeed];
        });
    }];
    
    [player onPacketBufferEmpty:^{
        MR_sync_main_queue(^{
            __strongSelf__
            [self.timer setFireDate:[NSDate dateWithTimeIntervalSinceNow:0.5]];
            [self appendMsg:[self.player peekPacketBufferStatus]];
        });
    }];
    
    player.supportedPixelFormats = MR_PIX_FMT_MASK_RGBA;
        // MR_PIX_FMT_MASK_ARGB;// MR_PIX_FMT_MASK_RGBA;
        //MR_PIX_FMT_MASK_0RGB; //MR_PIX_FMT_MASK_RGB24;
        //MR_PIX_FMT_MASK_RGB555LE MR_PIX_FMT_MASK_RGB555BE;
    player.delegate = self;
    [player prepareToPlay];
    [player play];
    self.player = player;
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    self.inputField.stringValue = KTestVideoURL1;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(willStartScroll:) name:NSScrollViewWillStartLiveScrollNotification object:self.textView.enclosingScrollView];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(didEndScroll:) name:NSScrollViewDidEndLiveScrollNotification object:self.textView.enclosingScrollView];
    [self.videoRenderer setWantsLayer:YES];
    self.videoRenderer.layer.backgroundColor = [[NSColor redColor]CGColor];
}

- (void)willStartScroll:(NSScrollView *)sender
{
    self.scrolling = YES;
}

- (void)didEndScroll:(NSScrollView *)sender
{
    if ([self.timer isValid]) {
        [self.timer setFireDate:[NSDate dateWithTimeIntervalSinceNow:1]];
    }
    self.scrolling = NO;
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

- (IBAction)onConsumePackets:(id)sender
{
    if (!self.player) {
        [self appendMsg:@"请先点击查看！"];
        return;
    }
    [self appendMsg:[self.player peekPacketBufferStatus]];
}

- (IBAction)onConsumeAllPackets:(id)sender
{
    if (!self.player) {
        [self appendMsg:@"请先点击查看！"];
        return;
    }
    [self appendMsg:[self.player peekPacketBufferStatus]];
}

@end
