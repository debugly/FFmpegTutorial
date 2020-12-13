//
//  MR0x40Task.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2020/12/2.
//

#import "MR0x40Task.h"
#import <FFmpegTutorial/MRVideoToPicture.h>

static const int kMinPictureCount = 8;
static const int kMaxPictureCount = 30;

@interface MR0x40Task ()<MRVideoToPictureDelegate>

@property (nonatomic, strong, readwrite) NSURL *fileURL;
@property (nonatomic, copy) void(^completion)(void);
@property (nonatomic, strong) MRVideoToPicture *vtp;
@property (nonatomic, assign) NSTimeInterval begin;
@property (nonatomic, assign, readwrite) NSTimeInterval cost;
@property (nonatomic, assign, readwrite) int duration;
@property (nonatomic, assign, readwrite) int frameCount;
@property (nonatomic, copy, readwrite) NSString *videoName;
@property (nonatomic, assign, readwrite) CGSize dimension;
@property (nonatomic, copy, readwrite) NSString *containerFmt;
@property (nonatomic, copy, readwrite) NSString *audioFmt;
@property (nonatomic, copy, readwrite) NSString *videoFmt;

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
        self.fileURL = url;
        self.videoName = [url lastPathComponent];
    }
    return self;
}

- (void)start:(void(^)(void))completion
{
    self.completion = completion;
    self.begin = CFAbsoluteTimeGetCurrent();
    //remove old pics
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [[NSFileManager defaultManager] removeItemAtPath:[self saveDir] error:nil];
        dispatch_async(dispatch_get_main_queue(), ^{
            [self startVtp];
        });
    });
}

- (NSString *)saveDir
{
    NSParameterAssert(self.fileURL);
    NSString *dirName = [[[self.fileURL path] lastPathComponent] stringByDeletingPathExtension];
    NSString *fullPath = [NSTemporaryDirectory() stringByAppendingPathComponent:dirName];
    [[NSFileManager defaultManager] createDirectoryAtPath:fullPath withIntermediateDirectories:YES attributes:nil error:nil];
    return fullPath;
}

- (void)startVtp
{
    MRVideoToPicture *vtp = [[MRVideoToPicture alloc] init];
    vtp.contentPath = [self.fileURL path];
    vtp.supportedPixelFormats = MR_PIX_FMT_MASK_0RGB;
        // MR_PIX_FMT_MASK_ARGB;// MR_PIX_FMT_MASK_RGBA;
        //MR_PIX_FMT_MASK_0RGB; //MR_PIX_FMT_MASK_RGB24;
        //MR_PIX_FMT_MASK_RGB555LE MR_PIX_FMT_MASK_RGB555BE;
    vtp.delegate = self;
    vtp.picSaveDir = [self saveDir];
    vtp.maxCount = 30;
    [vtp prepareToPlay];
    [vtp startConvert];
    self.vtp = vtp;
}

- (void)vtp:(MRVideoToPicture *)vtp videoOpened:(NSDictionary<NSString *,id> *)info
{
    NSLog(@"=====video Opened=====%@",info);
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
    int videoWidth = [info[kMRMovieWidth] intValue];
    int videoHeight = [info[kMRMovieHeight] intValue];
    self.dimension = CGSizeMake(videoWidth, videoHeight);
    self.containerFmt = info[kMRMovieContainerFmt];
    self.audioFmt = info[kMRMovieAudioFmt];
    self.videoFmt = info[kMRMovieVideoFmt]; 
}

- (void)vtp:(MRVideoToPicture *)vtp convertAnImage:(NSString *)imgPath
{
    if (self.vtp == vtp) {
        NSLog(@"image path:%@",imgPath);
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
