//
//  MR0x40ViewController.m
//  FFmpegTutorial-iOS
//
//  Created by qianlongxu on 2020/6/2.
//  Copyright © 2020 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x40ViewController.h"
#import <FFmpegTutorial/MRRWeakProxy.h>
#import <FFmpegTutorial/MRVideoToPicture.h>
#import <ImageIO/ImageIO.h>
#import <MobileCoreServices/MobileCoreServices.h>
#import "MR0x40VideoRenderer.h"

@interface MR0x40ViewController ()<UITextViewDelegate,MRVideoToPictureDelegate>

@property (assign, nonatomic) NSInteger ignoreScrollBottom;
@property (weak, nonatomic) NSTimer *timer;

@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *indicatorView;
@property (weak, nonatomic) IBOutlet MR0x40VideoRenderer *videoRenderer;
@property (nonatomic, strong) MRVideoToPicture *vtp;
@property (nonatomic, assign) int maxCost;
@property (nonatomic, assign) int frameCount;
@property (nonatomic, assign) NSTimeInterval begin;

@end

@implementation MR0x40ViewController

- (void)dealloc
{
    if (self.timer) {
        [self.timer invalidate];
        self.timer = nil;
    }
    
    if (self.vtp) {
        self.vtp.delegate = nil;
        [self.vtp stop];
        self.vtp = nil;
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self.indicatorView startAnimating];
    self.textView.delegate = self;
    self.textView.layoutManager.allowsNonContiguousLayout = NO;
    
    MRVideoToPicture *vtp = [[MRVideoToPicture alloc] init];
    vtp.contentPath =
        @"http://data.vod.itc.cn/?new=/73/15/oFed4wzSTZe8HPqHZ8aF7J.mp4&vid=77972299&plat=14&mkey=XhSpuZUl_JtNVIuSKCB05MuFBiqUP7rB&ch=null&user=api&qd=8001&cv=3.13&uid=F45C89AE5BC3&ca=2&pg=5&pt=1&prod=ifox";


    vtp.supportedPixelFormats = MR_PIX_FMT_MASK_0RGB;
        // MR_PIX_FMT_MASK_ARGB;// MR_PIX_FMT_MASK_RGBA;
        //MR_PIX_FMT_MASK_0RGB; //MR_PIX_FMT_MASK_RGB24;
        //MR_PIX_FMT_MASK_RGB555LE MR_PIX_FMT_MASK_RGB555BE;
    //每隔10s保存一帧关键帧图片
    vtp.frameInterval = 10;
    vtp.delegate = self;
    [vtp prepareToPlay];
    [vtp readPacket];
    self.vtp = vtp;
    self.begin = CFAbsoluteTimeGetCurrent();

    MRRWeakProxy *weakProxy = [MRRWeakProxy weakProxyWithTarget:self];
    NSTimer *timer = [NSTimer scheduledTimerWithTimeInterval:1 target:weakProxy selector:@selector(onTimer:) userInfo:nil repeats:YES];
    [[NSRunLoop currentRunLoop] addTimer:timer forMode:NSRunLoopCommonModes];
    self.timer = timer;
}

- (void)saveAsJpeg:(CGImageRef _Nonnull)img path:(NSString *)path
{
    CFStringRef imageUTType = kUTTypeJPEG;
    NSURL *fileUrl = [NSURL fileURLWithPath:path];
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef) fileUrl, imageUTType, 1, NULL);
    CGImageDestinationAddImage(destination, img, NULL);
    CGImageDestinationFinalize(destination);
    CFRelease(destination);
}

- (void)saveImage:(CGImageRef _Nonnull)img
{
    int64_t time = [[NSDate date] timeIntervalSince1970] * 10000;
    NSString *path = [NSTemporaryDirectory() stringByAppendingFormat:@"%lld.jpg",time];
    [self saveAsJpeg:img path:path];
}

- (void)display:(CGImageRef)cgImage
{
    CFRetain(cgImage);
    dispatch_sync(dispatch_get_main_queue(), ^{
        [self.videoRenderer dispalyCGImage:cgImage];
        CFRelease(cgImage);
    });
}

- (void)vtp:(MRVideoToPicture *)vtp convertAnImage:(CGImageRef)img
{
    if (self.vtp == vtp) {
        self.frameCount = vtp.frameCount;
        [self display:img];
        NSTimeInterval begin = CFAbsoluteTimeGetCurrent();
        [self saveImage:img];
        NSTimeInterval end = CFAbsoluteTimeGetCurrent();
        int cost = (end - begin) * 1000;
        if (cost > _maxCost) {
            _maxCost = cost;
        }
    }
}

- (void)vtp:(MRVideoToPicture *)vtp convertFinished:(NSError *)err
{
    if (self.vtp == vtp) {
        if (err) {
            [self.vtp stop];
            self.vtp = nil;
            NSLog(@"convert faild:%@",err);
        } else {
            [self.vtp stop];
            self.vtp = nil;
            NSTimeInterval end = CFAbsoluteTimeGetCurrent();
            float cost = end - self.begin;
            NSLog(@"finished convet %d pic,cost:%0.2fs!",vtp.frameCount,cost);
        }
    }
}

- (void)onTimer:(NSTimer *)sender
{
    if ([self.indicatorView isAnimating]) {
        [self.indicatorView stopAnimating];
    }
    [self updateMessage];
    if (self.ignoreScrollBottom > 0) {
        self.ignoreScrollBottom --;
    } else {
        [self.textView scrollRangeToVisible:NSMakeRange(self.textView.text.length, 1)];
    }
}

- (void)updateMessage
{
    self.textView.text = [NSString stringWithFormat:@"generate:%d,MaxCost:%dms",self.frameCount,self.maxCost];
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
