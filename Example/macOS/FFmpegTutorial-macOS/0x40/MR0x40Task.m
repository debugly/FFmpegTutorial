//
//  MR0x40Task.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2020/12/2.
//

#import "MR0x40Task.h"
#import <FFmpegTutorial/MRVideoToPicture.h>
#import <ImageIO/ImageIO.h>

static const int kMinPictureCount = 8;
static const int kMaxPictureCount = 30;

@interface MR0x40Task ()<MRVideoToPictureDelegate>

@property (nonatomic, strong) NSURL *url;
@property (nonatomic, copy) void(^completion)(void);
@property (nonatomic, strong) MRVideoToPicture *vtp;
@property (nonatomic, assign) NSTimeInterval begin;
@property (nonatomic, assign, readwrite) NSTimeInterval cost;
@property (nonatomic, assign, readwrite) int duration;
@property (nonatomic, assign, readwrite) int frameCount;
@property (nonatomic, copy, readwrite) NSString *videoName;

@end

@implementation MR0x40Task

- (void)dealloc
{
    if (self.vtp) {
        self.vtp.delegate = nil;
        [self.vtp stop];
        self.vtp = nil;
    }
}

- (instancetype)initWithURL:(NSURL *)url
{
    self = [super init];
    if (self) {
        self.url = url;
        self.videoName = [url lastPathComponent];
    }
    return self;
}

- (void)start:(void(^)(void))completion
{
    self.completion = completion;
    self.begin = CFAbsoluteTimeGetCurrent();
    [self startVtp];
}

- (void)startVtp
{
    MRVideoToPicture *vtp = [[MRVideoToPicture alloc] init];
    vtp.contentPath = [self.url path];
    vtp.supportedPixelFormats = MR_PIX_FMT_MASK_0RGB;
        // MR_PIX_FMT_MASK_ARGB;// MR_PIX_FMT_MASK_RGBA;
        //MR_PIX_FMT_MASK_0RGB; //MR_PIX_FMT_MASK_RGB24;
        //MR_PIX_FMT_MASK_RGB555LE MR_PIX_FMT_MASK_RGB555BE;
    //每隔10s保存一帧关键帧图片
    vtp.perferInterval = 10;
    vtp.maxCount = self.maxCount;
    vtp.delegate = self;
    [vtp prepareToPlay];
    [vtp readPacket];
    self.vtp = vtp;
}

- (void)vtp:(MRVideoToPicture *)vtp videoOpened:(NSDictionary<NSString *,id> *)info
{
    int duration = [info[kMRMovieDuration] intValue];
    if (duration > 0) {
        self.duration = duration;
    }
    if (duration == 0) {
        self.vtp.perferInterval = 1;
    } else {
        //小于40分钟
        if(duration < 2400)
        {
            self.vtp.perferInterval = duration / kMinPictureCount;
            if(self.vtp.perferInterval < 1)
            {
                self.vtp.perferInterval = 1;
            }
        } else {
            self.vtp.perferInterval = duration / kMaxPictureCount;;
        }
    }
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

- (NSString *)picSaveDir
{
    if (!_picSaveDir) {
        _picSaveDir = NSTemporaryDirectory();
    }
    return _picSaveDir;
}

- (void)vtp:(MRVideoToPicture *)vtp convertAnImage:(CGImageRef)img
{
    if (self.vtp == vtp) {
        int64_t time = [[NSDate date] timeIntervalSince1970] * 10000;
        NSString *path = [self.picSaveDir stringByAppendingFormat:@"%lld.jpg",time];
        [self saveAsJpeg:img path:path];
    }
}

- (void)vtp:(MRVideoToPicture *)vtp convertFinished:(NSError *)err
{
    if (self.vtp == vtp) {
        
        NSTimeInterval end = CFAbsoluteTimeGetCurrent();
        self.cost = end - self.begin;
        self.frameCount = vtp.frameCount;
        
        if (err) {
            [self.vtp stop];
            self.vtp = nil;
            NSLog(@"convert faild:%@",err);
        } else {
            [self.vtp stop];
            self.vtp = nil;
        }
        
        if (self.completion) {
            self.completion();
        }
    }
}

@end
