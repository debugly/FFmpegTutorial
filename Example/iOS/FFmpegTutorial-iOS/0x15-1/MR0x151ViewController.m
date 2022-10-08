//
//  MR0x151ViewController.m
//  FFmpegTutorial-iOS
//
//  Created by qianlongxu on 2022/9/11.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x151ViewController.h"
#import <FFmpegTutorial/FFTPlayer0x10.h>
#import <FFmpegTutorial/FFTDispatch.h>
#import <FFmpegTutorial/FFTConvertUtil.h>
#import <FFmpegTutorial/FFTHudControl.h>
#import <MRFFmpegPod/libavutil/frame.h>
#import "MR0x151VideoRenderer.h"
#import "MRRWeakProxy.h"

@interface MR0x151ViewController ()

@property (weak, nonatomic) IBOutlet MR0x151VideoRenderer *videoRenderer;
@property (weak, nonatomic) IBOutlet UITextField *input;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *indicator;
@property (weak, nonatomic) IBOutlet UILabel *audioPktLb;
@property (weak, nonatomic) IBOutlet UILabel *vidoePktLb;
@property (weak, nonatomic) IBOutlet UILabel *audioFrameLb;
@property (weak, nonatomic) IBOutlet UILabel *videoFrameLb;
@property (weak, nonatomic) IBOutlet UILabel *infoLb;

@property (strong) FFTPlayer0x10 *player;
@property (strong) FFTHudControl *hud;
@property (weak) NSTimer *timer;

@end

@implementation MR0x151ViewController

- (void)dealloc
{
    if (_timer) {
        [_timer invalidate];
        _timer = nil;
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
    [self.indicator stopAnimating];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%02d",self.player.audioFrameCount] forKey:@"a-frame"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%02d",self.player.videoFrameCount] forKey:@"v-frame"];
    
    [self.hud setHudValue:[NSString stringWithFormat:@"%02d",self.player.audioPktCount] forKey:@"a-pack"];

    [self.hud setHudValue:[NSString stringWithFormat:@"%02d",self.player.videoPktCount] forKey:@"v-pack"];
}

- (void)resetUI
{
    self.audioPktLb.text = nil;
    self.vidoePktLb.text = nil;
    self.audioFrameLb.text = nil;
    self.videoFrameLb.text = nil;
    self.infoLb.text = nil;
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view from its nib.
    self.input.text = KTestVideoURL1;
    [self resetUI];
    
    self.hud = [[FFTHudControl alloc] init];
    UIView *hudView = [self.hud contentView];
    
    [self.view addSubview:hudView];
    CGRect rect = self.view.bounds;
    CGFloat viewWidth = CGRectGetWidth(rect);
    CGFloat screenWidth = [[UIScreen mainScreen] bounds].size.width;
    rect.size.width = MIN(screenWidth / 5.0, 150);
    rect.origin.y = 120;
    rect.origin.x = viewWidth - rect.size.width;
    [hudView setFrame:rect];
    hudView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleHeight;
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
    [self.player asyncStop];
}

- (void)parseURL:(NSString *)url
{
    [self.indicator startAnimating];
    if (self.player) {
        [self.player asyncStop];
    }
    
    FFTPlayer0x10 *player = [[FFTPlayer0x10 alloc] init];
    player.contentPath = url;
    player.supportedPixelFormats = MR_PIX_FMT_MASK_NV12;
    
    __weakSelf__
    player.onError = ^(NSError *err){
        NSLog(@"%@",err);
        __strongSelf__
        mr_async_main_queue(^{
            [self.timer invalidate];
            self.timer = nil;
            [self.indicator stopAnimating];
            self.player = nil;
        });
    };
    
    player.onReadPkt = ^(int a,int v){
        __strongSelf__
        mr_async_main_queue(^{
            self.audioPktLb.text = [NSString stringWithFormat:@"%d",a];
            self.vidoePktLb.text = [NSString stringWithFormat:@"%d",v];
        });
    };
    
    player.onDecoderFrame = ^(int type,int serial,AVFrame *frame) {
        __strongSelf__
            //video
            if (type == 1) {
                CVPixelBufferRef pixelBuff = [FFTConvertUtil pixelBufferFromAVFrame:frame opt:NULL];
                CVPixelBufferRetain(pixelBuff);
                mr_msleep(40);
                mr_async_main_queue(^{
                    [self.videoRenderer displayPixelBuffer:pixelBuff];
                    CVPixelBufferRelease(pixelBuff);
                    self.videoFrameLb.text = [NSString stringWithFormat:@"%d",serial];
                    self.infoLb.text = [NSString stringWithFormat:@"%d,%lld",frame->format,frame->pts];
                });
            }
            //audio
            else if (type == 2) {
                mr_async_main_queue(^{
                    self.audioFrameLb.text = [NSString stringWithFormat:@"%d",serial];
                });
            }
    };

    [player prepareToPlay];
    [player play];
    self.player = player;
    [self prepareTickTimerIfNeed];
}

- (IBAction)go:(UIButton *)sender
{
    if (self.input.text.length > 0) {
        [self resetUI];
        [self parseURL:self.input.text];
    }
}

- (IBAction)onSelectedVideMode:(UISegmentedControl *)sender
{
    NSInteger idx = [sender selectedSegmentIndex];
    if (idx == 0) {
        [self.videoRenderer setContentMode:MRViewContentModeScaleToFill0x151];
    } else if (idx == 1) {
        [self.videoRenderer setContentMode:MRViewContentModeScaleAspectFill0x151];
    } else if (idx == 2) {
        [self.videoRenderer setContentMode:MRViewContentModeScaleAspectFit0x151];
    }
}

@end
