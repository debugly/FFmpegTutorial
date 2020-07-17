//
//  MR0x22ViewController.m
//  FFmpegTutorial-iOS
//
//  Created by qianlongxu on 2020/7/16.
//  Copyright © 2020 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//
//

#import "MR0x22ViewController.h"
#import <FFmpegTutorial/FFPlayer0x22.h>
#import <FFmpegTutorial/MRRWeakProxy.h>
#import <GLKit/GLKit.h>
#import "MR0x22VideoRenderer.h"
#import "MR0x22AudioRenderer.h"

//将音频裸流PCM写入到文件
#define DEBUG_RECORD_PCM_TO_FILE 0

@interface MR0x22ViewController ()<UITextViewDelegate,FFPlayer0x22Delegate>
{
    #if DEBUG_RECORD_PCM_TO_FILE
        FILE * file_pcm_l;
    #endif
}

@property (nonatomic, strong) FFPlayer0x22 *player;
@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *indicatorView;
@property (weak, nonatomic) IBOutlet MR0x22VideoRenderer *renderView;

@property (assign, nonatomic) NSInteger ignoreScrollBottom;
@property (weak, nonatomic) NSTimer *timer;

//采样率
@property (nonatomic,assign) int targetSampleRate;

@property (nonatomic, strong) MR0x22AudioRenderer *audioRender;

@end

@implementation MR0x22ViewController

- (void)dealloc
{
    
    #if DEBUG_RECORD_PCM_TO_FILE
        fclose(file_pcm_l);
    #endif
    
    if (self.timer) {
        [self.timer invalidate];
        self.timer = nil;
    }
    
    if (self.player) {
        [self.player stop];
        self.player = nil;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self.indicatorView startAnimating];
    self.textView.delegate = self;
    self.textView.layoutManager.allowsNonContiguousLayout = NO;
    self.renderView.contentMode = UIViewContentModeScaleAspectFit;
#if DEBUG_RECORD_PCM_TO_FILE
    if (file_pcm_l == NULL) {
        const char *l = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"L.pcm"]UTF8String];
        NSLog(@"%s",l);
        file_pcm_l = fopen(l, "wb+");
    }
#endif
    
    FFPlayer0x22 *player = [[FFPlayer0x22 alloc] init];
    player.contentPath = @"http://data.vod.itc.cn/?new=/73/15/oFed4wzSTZe8HPqHZ8aF7J.mp4&vid=77972299&plat=14&mkey=XhSpuZUl_JtNVIuSKCB05MuFBiqUP7rB&ch=null&user=api&qd=8001&cv=3.13&uid=F45C89AE5BC3&ca=2&pg=5&pt=1&prod=ifox";
    
    __weakSelf__
    [player onError:^{
        __strongSelf__
        [self.indicatorView stopAnimating];
        self.textView.text = [self.player.error localizedDescription];
        self.player = nil;
        [self.timer invalidate];
        self.timer = nil;
    }];
    player.supportedPixelFormats  = MR_PIX_FMT_MASK_NV12;
    
    player.supportedSampleFormats = MR_SAMPLE_FMT_MASK_S16 | MR_SAMPLE_FMT_MASK_FLT;
//    not support planar fmt.
//    player.supportedSampleFormats = MR_SAMPLE_FMT_MASK_S16P;
//    player.supportedSampleFormats = MR_SAMPLE_FMT_MASK_FLTP;
    
    //设置采样率
    self.targetSampleRate = [MR0x22AudioRenderer setPreferredSampleRate:44100];
    player.supportedSampleRate = self.targetSampleRate;
    
    player.delegate = self;
    [player prepareToPlay];
    [player readPacket];
    self.player = player;
    
    MRRWeakProxy *weakProxy = [MRRWeakProxy weakProxyWithTarget:self];
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1 target:weakProxy selector:@selector(onTimer:) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    self.timer = timer;
}

- (void)playAudio
{
    [self.audioRender paly];
}

- (void)reveiveFrameToRenderer:(CVPixelBufferRef)img
{
    CVPixelBufferRetain(img);
    dispatch_sync(dispatch_get_main_queue(), ^{
        [self.renderView displayPixelBuffer:img];
        CVPixelBufferRelease(img);
        
        static bool started = false;
        if (!started) {
            [self playAudio];
            started = true;
        }
    });
}

- (void)onInitAudioRender:(MRSampleFormat)fmt
{
    dispatch_sync(dispatch_get_main_queue(), ^{
        [self setupAudioRender:fmt];
    });
}

- (void)setupAudioRender:(MRSampleFormat)fmt
{
    self.audioRender = [MR0x22AudioRenderer new];
    [self.audioRender setPreferredAudioQueue:YES];
    [self.audioRender active];
    [self.audioRender setupWithFmt:fmt sampleRate:self.targetSampleRate];
    __weakSelf__
    [self.audioRender onFetchPacketSample:^UInt32(uint8_t * _Nonnull buffer, UInt32 bufferSize) {
        __strongSelf__
        UInt32 filled = [self.player fetchPacketSample:buffer wantBytes:bufferSize];
        return filled;
    }];
}

- (void)onTimer:(NSTimer *)sender
{
    if ([self.indicatorView isAnimating]) {
        [self.indicatorView stopAnimating];
    }
    [self appendMsg:[self.player peekPacketBufferStatus]];
    if (self.ignoreScrollBottom > 0) {
        self.ignoreScrollBottom --;
    } else {
        [self.textView scrollRangeToVisible:NSMakeRange(self.textView.text.length, 1)];
    }
}

- (void)appendMsg:(NSString *)txt
{
    self.textView.text = txt;//[self.textView.text stringByAppendingFormat:@"\n%@",txt];
}

///滑动时就暂停自动滚到到底部
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    self.ignoreScrollBottom = NSIntegerMax;
}

///松开手了，不需要减速就当即设定5s后自动滚动
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (!decelerate) {
        self.ignoreScrollBottom = 5;
    }
}

///需要减速时，就在停下来之后设定5s后自动滚动
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    self.ignoreScrollBottom = 5;
}

@end