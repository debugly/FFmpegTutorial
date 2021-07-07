//
//  MR0x03ViewController.m
//  FFmpegTutorial-iOS
//
//  Created by qianlongxu on 2020/4/27.
//  Copyright © 2020 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x03ViewController.h"
#import <FFmpegTutorial/FFPlayer0x03.h>
#import "MRRWeakProxy.h"

@interface MR0x03ViewController ()<UITextViewDelegate>

@property (nonatomic, strong) FFPlayer0x03 *player;
@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *indicatorView;
@property (assign, nonatomic) NSInteger ignoreScrollBottom;
@property (weak, nonatomic) NSTimer *timer;

@end

@implementation MR0x03ViewController

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
    
    MRRWeakProxy *weakProxy = [MRRWeakProxy weakProxyWithTarget:self];
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1 target:weakProxy selector:@selector(onTimer:) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    self.timer = timer;
    
    FFPlayer0x03 *player = [[FFPlayer0x03 alloc] init];
    player.contentPath = KTestVideoURL1;
    __weakSelf__
    [player onError:^{
        __strongSelf__
        [self.indicatorView stopAnimating];
        self.textView.text = [self.player.error localizedDescription];
        self.player = nil;
        [self.timer invalidate];
        self.timer = nil;
    }];
    
    [player prepareToPlay];
    [player play];
    self.player = player;
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

- (IBAction)onConsumePackets:(id)sender {
    [self.player consumePackets];
    [self appendMsg:[self.player peekPacketBufferStatus]];
}

- (IBAction)onConsumeAllPackets:(id)sender {
    [self.player consumeAllPackets];
    [self appendMsg:[self.player peekPacketBufferStatus]];
}

- (void)appendMsg:(NSString *)txt
{
    self.textView.text = [self.textView.text stringByAppendingFormat:@"\n%@",txt];
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
