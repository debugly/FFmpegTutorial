//
//  MR0x12ViewController.m
//  FFmpegTutorial-iOS
//
//  Created by qianlongxu on 2020/6/6.
//  Copyright © 2020 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x12ViewController.h"
#import <FFmpegTutorial/FFPlayer0x12.h>
#import "MRRWeakProxy.h"
#import <GLKit/GLKit.h>
#import <AVFoundation/AVCaptureVideoDataOutput.h>

@interface MR0x12ViewController ()<UITextViewDelegate,FFPlayer0x12Delegate>

@property (nonatomic, strong) FFPlayer0x12 *player;
@property (weak, nonatomic) IBOutlet UITextView *textView;
@property (weak, nonatomic) IBOutlet UIActivityIndicatorView *indicatorView;

@property (weak, nonatomic) IBOutlet GLKView *glView;
@property (nonatomic, strong) EAGLContext *glContext;
@property (nonatomic, strong) CIContext *ciContext;
@property (nonatomic, strong) CIFilter *ciFilter;
@property (assign, nonatomic) NSInteger ignoreScrollBottom;
@property (weak, nonatomic) NSTimer *timer;
@property (assign) MR_PACKET_SIZE pktSize;

@end

@implementation MR0x12ViewController

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

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view.
    [self.indicatorView startAnimating];
    self.textView.delegate = self;
    self.textView.layoutManager.allowsNonContiguousLayout = NO;
    
    FFPlayer0x12 *player = [[FFPlayer0x12 alloc] init];
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
    
    player.supportedPixelFormats = MR_PIX_FMT_MASK_NV12;
    
    //MR_PIX_FMT_MASK_RGBA;//MR_PIX_FMT_MASK_NV12; //MR_PIX_FMT_MASK_RGB24;//MR_PIX_FMT_MASK_0RGB;// MR_PIX_FMT_MASK_RGB555BE;//MR_PIX_FMT_MASK_RGB24;//MR_PIX_FMT_MASK_RGB555LE | MR_PIX_FMT_MASK_RGB555BE | MR_PIX_FMT_MASK_RGBA;MR_PIX_FMT_MASK_NV12;
    player.delegate = self;
    [player prepareToPlay];
    [player play];
    self.player = player;
    [self prepareTickTimerIfNeed];
    
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

- (void)reveiveFrameToRenderer:(CIImage *)ciImage
{
    dispatch_async(dispatch_get_main_queue(), ^{
        
        if (!self.glContext) {
            self.glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
            //important! use GPU
//            @{kCIContextCacheIntermediates:@NO,
//              kCIContextWorkingFormat:@"RGBA8",
//              kCIContextOutputPremultiplied:@NO,
//              kCIImageColorSpace:[NSNull null]
//            }
            self.ciContext = [CIContext contextWithEAGLContext:self.glContext options:
                              nil];
            [self.glView setContext:self.glContext];
        }
        
        if (self.glContext != [EAGLContext currentContext]){
            [EAGLContext setCurrentContext:self.glContext];
        }
        
//        // 2. 创建滤镜
//        self.ciFilter = [CIFilter filterWithName:@"CIMotionBlur" keysAndValues:kCIInputImageKey, ciImage, nil];
//        // 设置相关参数
//        [self.ciFilter setValue:@(10.f) forKey:@"inputRadius"];
//
//        // 3. 渲染并输出CIImage
//        CIImage *outputImage = [self.ciFilter outputImage];
        CIImage *outputImage = ciImage;
        CGFloat scale = [[UIScreen mainScreen]scale];
        CGSize aspectRatio = ciImage.extent.size;
            
        CGFloat maxWidth  = CGRectGetWidth(self.glView.bounds);
        CGFloat maxHeight = CGRectGetHeight(self.glView.bounds);
        
        maxWidth  *= scale;
        maxHeight *= scale;
        
        CGFloat aspectWidth = maxHeight / aspectRatio.height * aspectRatio.width;
        CGFloat aspectHeight = maxWidth / aspectRatio.width * aspectRatio.height;
        
        CGFloat width,height = 0;
        
        if (aspectWidth < maxWidth) {
            width = aspectWidth;
            height = maxHeight;
        } else {
            width = maxWidth;
            height = aspectHeight;
        }
        
        CGRect inRect = CGRectMake((maxWidth-width)/2.0, (maxHeight-height)/2.0,width, height);
        
        //        inRect = CGRectMake(0, 0, maxWidth, maxHeight);
        //        inRect = CGRectMake(0, 0, self.glView.bounds.size.width*scale, self.glView.bounds.size.height*scale);
        
        @autoreleasepool {
            [self.glView bindDrawable];
            [self.ciContext drawImage:outputImage
                               inRect:inRect
                             fromRect:outputImage.extent];
            [self.glView display];
        }
    });
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
    
    NSString *frmMsg = [NSString stringWithFormat:@"[Frame] audio(%002d)，video(%002d)",self.player.audioFrameCount,self.player.videoFrameCount];
    
    NSString *pktMsg = nil;
    if (mr_packet_size_equal_zero(pktSize)) {
        pktMsg = @"Packet Buffer is Empty";
    } else {
        pktMsg = [NSString stringWithFormat:@" [Packet] audio(%02d)，video(%02d)",pktSize.audio_pkt_size,pktSize.video_pkt_size];
    }
    self.pktSize = pktSize;
    [self appendMsg:[frmMsg stringByAppendingString:pktMsg]];
    
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
