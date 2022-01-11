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
@property (assign) MR_PACKET_SIZE pktSize;

@end

@implementation MR0x03ViewController

- (void)dealloc
{
    if (self.timer) {
        [self.timer invalidate];
        self.timer = nil;
    }
    
    if (self.player) {
        [self.player asyncStop];
        self.player = nil;
    }
}

- (void)prepareTickTimerIfNeed
{
    if (self.timer && ![self.timer isValid]) {
        return;
    }
    MRRWeakProxy *weakProxy = [MRRWeakProxy weakProxyWithTarget:self];
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:0.1 target:weakProxy selector:@selector(onTimer:) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    self.timer = timer;
}

- (void)onTimer:(NSTimer *)sender
{
    MR_PACKET_SIZE pktSize = [self.player peekPacketBufferStatus];
    if (0 == mr_packet_size_equal(self.pktSize, pktSize)) {
        return;
    }
    
    if ([self.indicatorView isAnimating]) {
        [self.indicatorView stopAnimating];
    }
    
    NSString *msg = nil;
    if (mr_packet_size_equal_zero(pktSize)) {
        msg = @"Packet Buffer is Empty";
    } else {
        msg = [NSString stringWithFormat:@"audio(%02d)，video(%02d)",pktSize.audio_pkt_size,pktSize.video_pkt_size];
    }
    self.pktSize = pktSize;
    [self appendMsg:msg];
    
    if (self.ignoreScrollBottom > 0) {
        self.ignoreScrollBottom --;
    } else {
        [self.textView scrollRangeToVisible:NSMakeRange(self.textView.text.length, 1)];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self.indicatorView startAnimating];
    self.textView.delegate = self;
    self.textView.layoutManager.allowsNonContiguousLayout = NO;
    
    FFPlayer0x03 *player = [[FFPlayer0x03 alloc] init];
#if DEBUG
    player.readPackDelay = 0.1;
#endif
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
    [self prepareTickTimerIfNeed];
}

- (IBAction)onConsumePackets:(id)sender
{
    if ([self.player consumePackets]) {
        [self appendMsg:@"Consume Packet Buffer"];
    }
    [self.timer setFireDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    [self onTimer:nil];
}

- (IBAction)onConsumeAllPackets:(id)sender
{
    [self.player consumeAllPackets];
    [self appendMsg:@"Consume All Packet Buffer"];
    [self.timer setFireDate:[NSDate dateWithTimeIntervalSinceNow:0.1]];
    [self onTimer:nil];
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
