//
//  MR0x40ViewController.m
//  FFmpegTutorial-macOS
//
//  Created by Matt Reach on 2020/11/18.
//

#import "MR0x40ViewController.h"
#import <FFmpegTutorial/MRVideoToPicture.h>
#import <ImageIO/ImageIO.h>

#ifndef __MRWS__
#define __MRWS__

#ifndef __weakSelf__
#define __weakSelf__  __weak    typeof(self)weakSelf = self;
#endif

#ifndef __strongSelf__
#define __strongSelf__ __strong typeof(weakSelf)self = weakSelf;
#endif

#define __weakObj(obj)   __weak   typeof(obj)weak##obj = obj;
#define __strongObj(obj) __strong typeof(weak##obj)obj = weak##obj;

#endif

@interface MR0x40ViewController ()<MRVideoToPictureDelegate>

@property (nonatomic, strong) MRVideoToPicture *vtp;
@property (nonatomic, assign) int maxCost;
@property (nonatomic, assign) NSTimeInterval begin;

@end

@implementation MR0x40ViewController

- (void)dealloc
{
    if (self.vtp) {
        self.vtp.delegate = nil;
        [self.vtp stop];
        self.vtp = nil;
    }
}

//-[NSNib _initWithNibNamed:bundle:options:] could not load the nibName: MR0x40ViewController in bundle (null).
- (void)loadView
{
    self.view = [[NSView alloc] initWithFrame:NSMakeRect(0, 0, 300, 300)];
}

- (void)viewDidLoad {
    [super viewDidLoad];
    MRVideoToPicture *vtp = [[MRVideoToPicture alloc] init];
    vtp.contentPath =
        @"http://data.vod.itc.cn/?new=/73/15/oFed4wzSTZe8HPqHZ8aF7J.mp4&vid=77972299&plat=14&mkey=XhSpuZUl_JtNVIuSKCB05MuFBiqUP7rB&ch=null&user=api&qd=8001&cv=3.13&uid=F45C89AE5BC3&ca=2&pg=5&pt=1&prod=ifox";
//    @"http://localhost/ffmpeg-test/%E9%98%B3%E5%85%89%E7%94%B5%E5%BD%B1www.ygdy8.com.%E5%A4%8D%E4%BB%87%E8%80%85%E8%81%94%E7%9B%9F4%EF%BC%9A%E7%BB%88%E5%B1%80%E4%B9%8B%E6%88%98.BD.720p.%E5%9B%BD%E8%8B%B1%E5%8F%8C%E8%AF%AD%E5%8F%8C%E5%AD%97.mkv";

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

- (void)vtp:(MRVideoToPicture *)vtp convertAnImage:(CGImageRef)img
{
    if (self.vtp == vtp) {
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
            NSLog(@"save image max cost:%dms", _maxCost);
            NSTimeInterval end = CFAbsoluteTimeGetCurrent();
            float cost = end - self.begin;
            NSLog(@"finished convet %d pic,cost:%0.2fs!",vtp.frameCount,cost);
        }
    }
}

@end
