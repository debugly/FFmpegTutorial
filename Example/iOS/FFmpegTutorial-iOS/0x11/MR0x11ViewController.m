//
//  MR0x11ViewController.m
//  FFmpegTutorial-iOS
//
//  Created by qianlongxu on 2020/6/5.
//  Copyright © 2020 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x11ViewController.h"
#import <FFmpegTutorial/FFPlayer0x11.h>
#import "MRRWeakProxy.h"

@interface MR0x11ViewController ()<UITextViewDelegate,FFPlayer0x11Delegate>

@property (nonatomic, strong) FFPlayer0x11 *player;
@property (assign, nonatomic) NSInteger ignoreScrollBottom;
@property (weak, nonatomic) NSTimer *timer;

@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *indicatorView;
@property (weak, nonatomic) IBOutlet UIImageView *imgView;


@end

#define USE_CoreAnimation_DISPLAY 1

@implementation MR0x11ViewController

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
    
    FFPlayer0x11 *player = [[FFPlayer0x11 alloc] init];
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
    
    player.supportedPixelFormats = MR_PIX_FMT_MASK_0RGB;// MR_PIX_FMT_MASK_RGB555BE;//MR_PIX_FMT_MASK_RGB24;//MR_PIX_FMT_MASK_RGB555LE | MR_PIX_FMT_MASK_RGB555BE | MR_PIX_FMT_MASK_RGBA;

    player.delegate = self;
    [player prepareToPlay];
    [player play];
    self.player = player;
    
    MRRWeakProxy *weakProxy = [MRRWeakProxy weakProxyWithTarget:self];
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1 target:weakProxy selector:@selector(onTimer:) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    self.timer = timer;
}

- (void)reveiveFrameToRenderer:(CGImageRef)cgImage
{
    UIImage *image = [UIImage imageWithCGImage:cgImage];

    dispatch_sync(dispatch_get_main_queue(), ^{
        self.imgView.image = image;
    });
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
