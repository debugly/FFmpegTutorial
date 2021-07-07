//
//  MR0x32ViewController.m
//  FFmpegTutorial-iOS
//
//  Created by qianlongxu on 2020/8/4.
//  Copyright © 2020 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//
//

#import "MR0x32ViewController.h"
#import <FFmpegTutorial/FFPlayer0x32.h>
#import "MRRWeakProxy.h"
#import <GLKit/GLKit.h>
#import "MR0x32VideoRenderer.h"
#import "MR0x32AudioRenderer.h"

@interface MR0x32ViewController ()<UITextViewDelegate,FFPlayer0x32Delegate>

@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *indicatorView;
@property (assign, nonatomic) NSInteger ignoreScrollBottom;
@property (weak, nonatomic) NSTimer *timer;

@property (nonatomic, strong) FFPlayer0x32 *player;
@property (weak, nonatomic) IBOutlet MR0x32VideoRenderer *renderView;
@property (nonatomic, strong) MR0x32AudioRenderer *audioRender;
@property (nonatomic, assign) BOOL started;
@property (weak, nonatomic) IBOutlet UISlider *slider;
@property (weak, nonatomic) IBOutlet UILabel *durationLb;

@end

@implementation MR0x32ViewController

- (void)dealloc
{
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
    
    FFPlayer0x32 *player = [[FFPlayer0x32 alloc] init];
    player.contentPath = KTestVideoURL1;
    //player.contentPath = @"http://localhost:8080/ffmpeg-test/xp5.mp4";
    
    __weakSelf__
    [player onError:^{
        __strongSelf__
        [self.indicatorView stopAnimating];
        self.textView.text = [self.player.error localizedDescription];
        self.player = nil;
        [self.timer invalidate];
        self.timer = nil;
    }];
    
    [player onVideoEnds:^{
        __strongSelf__
        self.textView.text = @"Video Ends.";
        //fix position not end.
        [self updatePlayedTime];
        [self.player stop];
        self.player = nil;
        [self.timer invalidate];
        self.timer = nil;
    }];
    player.supportedPixelFormats  = MR_PIX_FMT_MASK_NV21;
    player.supportedSampleFormats = MR_SAMPLE_FMT_MASK_AUTO;
//    for test fmt.
//    player.supportedSampleFormats = MR_SAMPLE_FMT_MASK_S16 | MR_SAMPLE_FMT_MASK_FLT;
//    player.supportedSampleFormats = MR_SAMPLE_FMT_MASK_S16P;
//    player.supportedSampleFormats = MR_SAMPLE_FMT_MASK_FLTP;
    
    //设置采样率，如果播放之前知道音频的采样率，可以设置成实际的值，可避免播放器内部转换！
    int sampleRate = [MR0x32AudioRenderer setPreferredSampleRate:44100];
    player.supportedSampleRate = sampleRate;
    
    player.delegate = self;
    [player prepareToPlay];
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
        
        if (!self.started) {
            [self playAudio];
            self.started = true;
        }
    });
}

- (void)onInitAudioRender:(MRSampleFormat)fmt
{
    dispatch_sync(dispatch_get_main_queue(), ^{
        [self setupAudioRender:fmt];
    });
}

- (void)onDurationUpdate:(long)du
{
    dispatch_sync(dispatch_get_main_queue(), ^{
        [self updatePlayedTime];
    });
}

- (NSString *)formatToTime:(long)du
{
    long h = du / 3600;
    long m = (du - h * 3600) / 60;
    long s = du % 60;
    return [NSString stringWithFormat:@"%02ld:%02ld:%02ld",h,m,s];
}

- (void)updatePlayedTime
{
    long du = self.player.duration;
    if (du > 0) {
        NSString *played = [self formatToTime:(long)self.player.position];
        NSString *duration = [self formatToTime:self.player.duration];
        self.durationLb.text = [NSString stringWithFormat:@"%@/%@",played,duration];
        self.slider.value = self.player.position / self.player.duration;
    } else {
        self.durationLb.text = @"--:--:--/--:--:--";
        self.slider.value = 0.0;
    }
}

- (void)setupAudioRender:(MRSampleFormat)fmt
{
    self.audioRender = [MR0x32AudioRenderer new];
    [self.audioRender setPreferredAudioQueue:YES];
    [self.audioRender active];
    //播放器使用的采样率
    [self.audioRender setupWithFmt:fmt sampleRate:self.player.supportedSampleRate];
    __weakSelf__
    [self.audioRender onFetchPacketSample:^UInt32(uint8_t * _Nonnull buffer, UInt32 bufferSize) {
        __strongSelf__
        UInt32 filled = [self.player fetchPacketSample:buffer wantBytes:bufferSize];
        return filled;
    }];
    
    [self.audioRender onFetchPlanarSample:^UInt32(uint8_t * _Nonnull left, UInt32 leftSize, uint8_t * _Nonnull right, UInt32 rightSize) {
        __strongSelf__
        UInt32 filled = [self.player fetchPlanarSample:left leftSize:leftSize right:right rightSize:rightSize];
        return filled;
    }];
}

- (IBAction)onTogglePause:(UIButton *)sender
{
    [sender setSelected:!sender.isSelected];
    if (sender.isSelected) {
        [self.player pause];
        [self.audioRender pause];
    } else {
        [self.player play];
        [self.audioRender paly];
    }
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
    
    [self updatePlayedTime];
}

- (void)appendMsg:(NSString *)txt
{
    self.textView.text = txt;//[self.textView.text stringByAppendingFormat:@"\n%@",txt];
}

//滑动时就暂停自动滚到到底部
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView
{
    self.ignoreScrollBottom = NSIntegerMax;
}

//松开手了，不需要减速就当即设定5s后自动滚动
- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
    if (!decelerate) {
        self.ignoreScrollBottom = 5;
    }
}

//需要减速时，就在停下来之后设定5s后自动滚动
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView
{
    self.ignoreScrollBottom = 5;
}

@end
