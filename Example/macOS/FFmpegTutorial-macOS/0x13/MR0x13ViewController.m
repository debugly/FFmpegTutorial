//
//  MR0x13ViewController.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/7/11.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x13ViewController.h"
#import <FFmpegTutorial/FFPlayer0x13.h>
#import "MRRWeakProxy.h"
#import "MR0x13VideoRenderer.h"
#import <AVFoundation/AVCaptureVideoDataOutput.h>

@interface MR0x13ViewController ()<FFPlayer0x13Delegate>

@property (strong) FFPlayer0x13 *player;
@property (weak) IBOutlet NSTextField *inputField;
@property (assign) IBOutlet NSTextView *textView;
@property (weak) IBOutlet NSProgressIndicator *indicatorView;
@property (weak) IBOutlet MR0x13VideoRenderer *videoRenderer;

@property (assign) NSInteger ignoreScrollBottom;
@property (weak) NSTimer *timer;
@property (assign) BOOL scrolling;

@end

@implementation MR0x13ViewController

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

- (void)reveiveFrameToRenderer:(CMSampleBufferRef)sampleBuffer
{
    CFRetain(sampleBuffer);
    dispatch_sync(dispatch_get_main_queue(), ^{
        [self.videoRenderer enqueueSampleBuffer:sampleBuffer];
        CFRelease(sampleBuffer);
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
    
    FFPlayer0x13 *player = [[FFPlayer0x13 alloc] init];
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
    
    player.supportedPixelFormats = MR_PIX_FMT_MASK_NV12 | MR_PIX_FMT_MASK_BGR0 | MR_PIX_FMT_MASK_BGRA | MR_PIX_FMT_MASK_0RGB | MR_PIX_FMT_MASK_ARGB;
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
    
    AVCaptureVideoDataOutput *videoOutput = [[AVCaptureVideoDataOutput alloc] init];

    NSDictionary *formats = [NSDictionary dictionaryWithObjectsAndKeys:
           @"kCVPixelFormatType_1Monochrome", [NSNumber numberWithInt:kCVPixelFormatType_1Monochrome],
           @"kCVPixelFormatType_2Indexed", [NSNumber numberWithInt:kCVPixelFormatType_2Indexed],
           @"kCVPixelFormatType_4Indexed", [NSNumber numberWithInt:kCVPixelFormatType_4Indexed],
           @"kCVPixelFormatType_8Indexed", [NSNumber numberWithInt:kCVPixelFormatType_8Indexed],
           @"kCVPixelFormatType_1IndexedGray_WhiteIsZero", [NSNumber numberWithInt:kCVPixelFormatType_1IndexedGray_WhiteIsZero],
           @"kCVPixelFormatType_2IndexedGray_WhiteIsZero", [NSNumber numberWithInt:kCVPixelFormatType_2IndexedGray_WhiteIsZero],
           @"kCVPixelFormatType_4IndexedGray_WhiteIsZero", [NSNumber numberWithInt:kCVPixelFormatType_4IndexedGray_WhiteIsZero],
           @"kCVPixelFormatType_8IndexedGray_WhiteIsZero", [NSNumber numberWithInt:kCVPixelFormatType_8IndexedGray_WhiteIsZero],
           @"kCVPixelFormatType_16BE555", [NSNumber numberWithInt:kCVPixelFormatType_16BE555],
           @"kCVPixelFormatType_16LE555", [NSNumber numberWithInt:kCVPixelFormatType_16LE555],
           @"kCVPixelFormatType_16LE5551", [NSNumber numberWithInt:kCVPixelFormatType_16LE5551],
           @"kCVPixelFormatType_16BE565", [NSNumber numberWithInt:kCVPixelFormatType_16BE565],
           @"kCVPixelFormatType_16LE565", [NSNumber numberWithInt:kCVPixelFormatType_16LE565],
           @"kCVPixelFormatType_24RGB", [NSNumber numberWithInt:kCVPixelFormatType_24RGB],
           @"kCVPixelFormatType_24BGR", [NSNumber numberWithInt:kCVPixelFormatType_24BGR],
           @"kCVPixelFormatType_32ARGB", [NSNumber numberWithInt:kCVPixelFormatType_32ARGB],
           @"kCVPixelFormatType_32BGRA", [NSNumber numberWithInt:kCVPixelFormatType_32BGRA],
           @"kCVPixelFormatType_32ABGR", [NSNumber numberWithInt:kCVPixelFormatType_32ABGR],
           @"kCVPixelFormatType_32RGBA", [NSNumber numberWithInt:kCVPixelFormatType_32RGBA],
           @"kCVPixelFormatType_64ARGB", [NSNumber numberWithInt:kCVPixelFormatType_64ARGB],
           @"kCVPixelFormatType_48RGB", [NSNumber numberWithInt:kCVPixelFormatType_48RGB],
           @"kCVPixelFormatType_32AlphaGray", [NSNumber numberWithInt:kCVPixelFormatType_32AlphaGray],
           @"kCVPixelFormatType_16Gray", [NSNumber numberWithInt:kCVPixelFormatType_16Gray],
           @"kCVPixelFormatType_422YpCbCr8", [NSNumber numberWithInt:kCVPixelFormatType_422YpCbCr8],
           @"kCVPixelFormatType_4444YpCbCrA8", [NSNumber numberWithInt:kCVPixelFormatType_4444YpCbCrA8],
           @"kCVPixelFormatType_4444YpCbCrA8R", [NSNumber numberWithInt:kCVPixelFormatType_4444YpCbCrA8R],
           @"kCVPixelFormatType_444YpCbCr8", [NSNumber numberWithInt:kCVPixelFormatType_444YpCbCr8],
           @"kCVPixelFormatType_422YpCbCr16", [NSNumber numberWithInt:kCVPixelFormatType_422YpCbCr16],
           @"kCVPixelFormatType_422YpCbCr10", [NSNumber numberWithInt:kCVPixelFormatType_422YpCbCr10],
           @"kCVPixelFormatType_444YpCbCr10", [NSNumber numberWithInt:kCVPixelFormatType_444YpCbCr10],
           @"kCVPixelFormatType_420YpCbCr8Planar", [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8Planar],
           @"kCVPixelFormatType_420YpCbCr8PlanarFullRange", [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8PlanarFullRange],
           @"kCVPixelFormatType_422YpCbCr_4A_8BiPlanar", [NSNumber numberWithInt:kCVPixelFormatType_422YpCbCr_4A_8BiPlanar],
           @"kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange", [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarVideoRange],
           @"kCVPixelFormatType_420YpCbCr8BiPlanarFullRange", [NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange],
           @"kCVPixelFormatType_422YpCbCr8_yuvs", [NSNumber numberWithInt:kCVPixelFormatType_422YpCbCr8_yuvs],
           @"kCVPixelFormatType_422YpCbCr8FullRange", [NSNumber numberWithInt:kCVPixelFormatType_422YpCbCr8FullRange],
        nil];

    for (NSNumber *fmt in [videoOutput availableVideoCVPixelFormatTypes]) {
        NSLog(@"CVPixelFormatType:%@", [formats objectForKey:fmt]);
    }
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

- (IBAction)onSelectedVideMode:(NSPopUpButton *)sender
{
    NSMenuItem *item = [sender selectedItem];
    
    if (item.tag == 1) {
        [self.videoRenderer setContentMode:MRViewContentModeScaleToFill];
    } else if (item.tag == 2) {
        [self.videoRenderer setContentMode:MRViewContentModeScaleAspectFill];
    } else if (item.tag == 3) {
        [self.videoRenderer setContentMode:MRViewContentModeScaleAspectFit];
    }
}

@end
