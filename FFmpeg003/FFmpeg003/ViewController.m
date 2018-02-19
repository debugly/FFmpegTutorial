//
//  ViewController.m
//  FFmpeg003
//
//  Created by Matt Reach on 2017/10/20.
//  Copyright © 2017年 Awesome FFmpeg Study Demo. All rights reserved.
//  开源地址: https://github.com/debugly/StudyFFmpeg

#import "ViewController.h"
#import <libavutil/log.h>
#import <libavformat/avformat.h>
#import <libavcodec/avcodec.h>
#import <libavutil/pixdesc.h>
#import <libavutil/samplefmt.h>
#import "NSTimer+Util.h"
#import "MRVideoFrame.h"

#ifndef _weakSelf_SL
#define _weakSelf_SL     __weak   __typeof(self) $weakself = self;
#endif

#ifndef _strongSelf_SL
#define _strongSelf_SL   __strong __typeof($weakself) self = $weakself;
#endif

@interface ViewController ()

@property (weak, nonatomic) UIActivityIndicatorView *indicatorView;
@property (assign, nonatomic) AVFormatContext *formatCtx;
@property (strong, nonatomic) dispatch_queue_t io_queue;
@property (nonatomic,strong) NSMutableArray *videoFrames;
@property (nonatomic,assign) AVCodecContext *videoCodecCtx;
@property (nonatomic,assign) unsigned int stream_index_video;
@property (weak, nonatomic) UIImageView *renderView;
@property (nonatomic,assign) unsigned int width;
@property (nonatomic,assign) unsigned int height;
@property (assign, nonatomic) CGFloat videoTimeBase;
@property (nonatomic,assign) BOOL bufferOk;

@end

@implementation ViewController

static void fflog(void *context, int level, const char *format, va_list args){
//    @autoreleasepool {
//        NSString* message = [[NSString alloc] initWithFormat: [NSString stringWithUTF8String: format] arguments: args];
//
//        NSLog(@"ff:%d%@",level,message);
//    }
}

- (void)dealloc
{
    if (self.formatCtx) {
        AVFormatContext *formatCtx = self.formatCtx;
        avformat_close_input(&formatCtx);
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIActivityIndicatorView *indicatorView = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [self.view addSubview:indicatorView];
    indicatorView.center = self.view.center;
    indicatorView.hidesWhenStopped = YES;
    [indicatorView sizeToFit];
    _indicatorView = indicatorView;
    
    [indicatorView startAnimating];
    
    _stream_index_video = -1;
    _videoFrames = [NSMutableArray array];
    
    av_log_set_callback(fflog);//日志比较多，打开日志后会阻塞当前线程
    //av_log_set_flags(AV_LOG_SKIP_REPEATED);
    
    ///初始化libavformat，注册所有文件格式，编解码库；这不是必须的，如果你能确定需要打开什么格式的文件，使用哪种编解码类型，也可以单独注册！
    av_register_all();
    
    NSString *moviePath = nil;//[[NSBundle mainBundle]pathForResource:@"test" ofType:@"mp4"];
    ///该地址可以是网络的也可以是本地的；
    moviePath = @"http://debugly.cn/repository/test.mp4";
//    moviePath = @"http://localhost/ffmpeg-test/test.mp4";
    if ([moviePath hasPrefix:@"http"]) {
        //Using network protocols without global network initialization. Please use avformat_network_init(), this will become mandatory later.
        //播放网络视频的时候，要首先初始化下网络模块。
        avformat_network_init();
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self openStreamWithPath:moviePath completion:^(AVFormatContext *formatCtx){
            
            if(formatCtx){
                dispatch_async(dispatch_get_main_queue(), ^{
                    self.formatCtx = formatCtx;
                    
                    [self openVideoStream];
                    
                    [self startReadFrames];
                    
                    [self videoTick];
                });
            }else{
                NSLog(@"不能打开流");
            }
        }];
    });
}

- (BOOL)checkIsBufferOK
{
    float buffedDuration = 0.0;
    static float kMinBufferDuration = 3;
    
    //如果没有缓冲好，那么就每隔0.1s过来看下buffer
    for (MRVideoFrame *frame in self.videoFrames) {
        buffedDuration += frame.duration;
        if (buffedDuration >= kMinBufferDuration) {
            break;
        }
    }
    
    return buffedDuration >= kMinBufferDuration;
}

- (void)videoTick
{
    if (self.bufferOk) {
        MRVideoFrame *videoFrame = nil;
        @synchronized(self) {
            videoFrame = [self.videoFrames firstObject];
            if (videoFrame) {
                [self.videoFrames removeObjectAtIndex:0];
            }
        }
        if (videoFrame) {
            if (videoFrame.eof) {
                NSLog(@"视频播放结束");
            }else{
                [_indicatorView stopAnimating];
                float interval = videoFrame.duration;
                [self displayVideoFrame:videoFrame];
                const NSTimeInterval time = MAX(interval, 0.01);
                NSLog(@"after %fs tick",time);
                
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, time * NSEC_PER_SEC);
                dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                    [self videoTick];
                });
            }
            return;
        }
    }
    
    {
        self.bufferOk = NO;
        [self.view bringSubviewToFront:_indicatorView];
        [_indicatorView startAnimating];
        _weakSelf_SL
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            _strongSelf_SL
            [self videoTick];
        });
    }
}
#pragma mark - read frame loop

- (void)startReadFrames
{
    if (!self.io_queue) {
        dispatch_queue_t io_queue = dispatch_queue_create("read-io", DISPATCH_QUEUE_SERIAL);
        self.io_queue = io_queue;
    }
    
    _weakSelf_SL
    dispatch_async(self.io_queue, ^{
        
        while (1) {
           
            AVPacket pkt;
            _strongSelf_SL
            if (av_read_frame(_formatCtx,&pkt) >= 0) {
                if (pkt.stream_index == self.stream_index_video) {
                    
                    _weakSelf_SL
                    [self handleVideoPacket:&pkt completion:^(AVFrame *video_frame) {
                        _strongSelf_SL
                        
                        
                        if (video_frame->format == AV_PIX_FMT_YUV420P || video_frame->format == AV_PIX_FMT_YUVJ420P) {
                            unsigned char *nv12 = NULL;
                            
                            int nv12Size = AVFrameConvertToNV12Buffer(video_frame,&nv12);
                            if (nv12Size > 0){
                                
                                UIImage *image = [self NV12toUIImage:self.width h:self.height buffer:nv12];
                                
                                free(nv12);
                                nv12 = NULL;
                                const double frameDuration = av_frame_get_pkt_duration(video_frame) * self.videoTimeBase;
                                MRVideoFrame *frame = [[MRVideoFrame alloc]init];
                                frame.duration = frameDuration;
                                frame.image = image;
                                
                                @synchronized(self) {
                                    [self.videoFrames addObject:frame];
                                    if (!self.bufferOk) {
                                        self.bufferOk = [self checkIsBufferOK];
                                    }
                                }
                            }
                        }
                    }];
                }
            }else{
                NSLog(@"eof,stop read more frame!");
                MRVideoFrame *frame = [[MRVideoFrame alloc]init];
                frame.eof = YES;
                @synchronized(self) {
                    [self.videoFrames addObject:frame];
                    if (!self.bufferOk) {
                        self.bufferOk = [self checkIsBufferOK];
                    }
                }
                break;
            }
            ///释放内存
            av_packet_unref(&pkt);
        }
    });
}

#pragma mark - decode video packet

- (void)handleVideoPacket:(AVPacket *)packet completion:(void(^)(AVFrame *video_frame))completion
{
    if (!completion) {
        return;
    }
    
    int gotframe = 0;
    AVFrame *video_frame = av_frame_alloc();//老版本是 avcodec_alloc_frame
    
    int len = avcodec_decode_video2(_videoCodecCtx, video_frame, &gotframe, packet);
    if (len < 0) {
        NSLog(@"decode video error, skip packet");
    }
    if (gotframe) {
        completion(video_frame);
    }
    //用完后记得释放掉
    av_frame_free(&video_frame);
}

#pragma mark - display video frame

- (void)displayVideoFrame:(MRVideoFrame *)frame
{
    UIImage *image = frame.image;
    [self.renderView setImage:image];
}

#pragma mark - avframe to nv12

int AVFrameConvertToNV12Buffer(AVFrame *pFrame,unsigned char **nv12)
{
    if ((pFrame->format == AV_PIX_FMT_YUV420P) || (pFrame->format == AV_PIX_FMT_NV12) || (pFrame->format == AV_PIX_FMT_NV21) || (pFrame->format == AV_PIX_FMT_YUVJ420P)){
        
        int height = pFrame->height;
        int width = pFrame->width;
        //计算需要分配的内存大小
        int needSize = height * width * 1.5;
        
        if (*nv12 == NULL) {
            //申请内存
            *nv12 = malloc(needSize);
        }
        unsigned char *buf = *nv12;
        unsigned char *y = pFrame->data[0];
        unsigned char *u = pFrame->data[1];
        unsigned char *v = pFrame->data[2];
        
        unsigned int ys = pFrame->linesize[0];
        
        //先写入Y（height * width 个 Y 数据）
        int offset=0;
        for (int i=0; i < height; i++)
        {
            memcpy(buf+offset,y + i * ys, width);
            offset+=width;
        }
        
        ///一个U一个V交替着排列（一共有 width * height / 4 个 [U + V] ）
        for (int i = 0; i < width * height / 4; i++)
        {
            memcpy(buf+offset,u + i, 1);
            offset++;
            memcpy(buf+offset,v + i, 1);
            offset++;
        }
        return needSize;
    }
    
    return -1;
}
#pragma mark - YUV(NV12)-->CIImage--->UIImage
//https://stackoverflow.com/questions/25659671/how-to-convert-from-yuv-to-ciimage-for-ios
-(UIImage *)NV12toUIImage:(int)w h:(int)h buffer:(unsigned char *)buffer
{
    //YUV(NV12)-->CIImage--->UIImage Conversion
    NSDictionary *pixelAttributes = @{(NSString*)kCVPixelBufferIOSurfacePropertiesKey:@{}};
    
    CVPixelBufferRef pixelBuffer = NULL;
    
    CVReturn result = CVPixelBufferCreate(kCFAllocatorDefault,
                                          w,
                                          h,
                                          kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                                          (__bridge CFDictionaryRef)(pixelAttributes),
                                          &pixelBuffer);
    
    CVPixelBufferLockBaseAddress(pixelBuffer,0);
    unsigned char *yDestPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    
    // Here y_ch0 is Y-Plane of YUV(NV12) data.
    unsigned char *y_ch0 = buffer;
    unsigned char *y_ch1 = buffer + w * h;
    memcpy(yDestPlane, y_ch0, w * h);
    unsigned char *uvDestPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
    
    // Here y_ch1 is UV-Plane of YUV(NV12) data.
    memcpy(uvDestPlane, y_ch1, w * h/2);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    if (result != kCVReturnSuccess) {
        NSLog(@"Unable to create cvpixelbuffer %d", result);
    }
    
    UIImage *image = [self cvPixelBufferReftoUIImage:pixelBuffer w:w h:h];
    return image;
}

//性能是很差,平均需要 0.3s，很不适合用来渲染视频 ！！！
- (UIImage *)cvPixelBufferReftoUIImage:(CVPixelBufferRef)pixelBuffer w:(int)w h:(int)h
{
    // CIImage Conversion
    CIImage *coreImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    NSTimeInterval begin = CFAbsoluteTimeGetCurrent();
    
    CIContext *context = [CIContext contextWithOptions:nil];
    
    ///引发内存泄露? https://stackoverflow.com/questions/32520082/why-is-cicontext-createcgimage-causing-a-memory-leak
    CGImageRef cgImage = [context createCGImage:coreImage
                                       fromRect:CGRectMake(0, 0, w, h)];
    
    // UIImage Conversion
    UIImage *uiImage = [[UIImage alloc] initWithCGImage:cgImage
                                                  scale:1.0
                                            orientation:UIImageOrientationUp];
    NSTimeInterval end = CFAbsoluteTimeGetCurrent();
    NSLog(@"decode an image cost :%g",end-begin);
    CVPixelBufferRelease(pixelBuffer);
    CGImageRelease(cgImage);
    
    return uiImage;
}

- (void)openVideoStream
{
    AVStream *stream = _formatCtx->streams[_stream_index_video];
    [self openVideoStream:stream];
}

- (void)openVideoStream:(AVStream *)stream
{
    AVCodecContext *codecCtx = stream->codec;
    // find the decoder for the video stream
    AVCodec *codec = avcodec_find_decoder(codecCtx->codec_id);
    if (!codec)
        return;
    // open codec
    if (avcodec_open2(codecCtx, codec, NULL) < 0)
        return;
    
    _videoCodecCtx = codecCtx;
    
    self.width = codecCtx->width;
    self.height = codecCtx->height;
    float fps = 0;
    avStreamFPSTimeBase(stream, 0.04, &fps, &_videoTimeBase);
    if (!self.renderView) {
        UIImageView *render = [[UIImageView alloc]initWithFrame:self.view.bounds];
        [self.view addSubview:render];
        render.contentMode = UIViewContentModeScaleAspectFit;
        render.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        self.renderView = render;
    }
}

static void avStreamFPSTimeBase(AVStream *st, CGFloat defaultTimeBase, CGFloat *pFPS, CGFloat *pTimeBase)
{
    CGFloat fps, timebase;
    
    if (st->time_base.den && st->time_base.num)
        timebase = av_q2d(st->time_base);
    else if(st->codec->time_base.den && st->codec->time_base.num)
        timebase = av_q2d(st->codec->time_base);
    else
        timebase = defaultTimeBase;
    
    if (st->codec->ticks_per_frame != 1) {
        
        //timebase *= st->codec->ticks_per_frame;
    }
    
    if (st->avg_frame_rate.den && st->avg_frame_rate.num)
        fps = av_q2d(st->avg_frame_rate);
    else if (st->r_frame_rate.den && st->r_frame_rate.num)
        fps = av_q2d(st->r_frame_rate);
    else
        fps = 1.0 / timebase;
    
    if (pFPS)
        *pFPS = fps;
    if (pTimeBase)
        *pTimeBase = timebase;
}

/**
 avformat_open_input 是个耗时操作因此放在异步线程里完成
 
 @param moviePath 视频地址
 @param completion open之后获取信息，然后回调
 */
- (void)openStreamWithPath:(NSString *)moviePath completion:(void(^)(AVFormatContext *formatCtx))completion
{
    AVFormatContext *formatCtx = NULL;
    
    /*
     打开输入流，读取文件头信息，不会打开解码器；
     */
    ///低版本是 av_open_input_file 方法
    if (0 != avformat_open_input(&formatCtx, [moviePath cStringUsingEncoding:NSUTF8StringEncoding], NULL, NULL)) {
        ///关闭，释放内存，置空
        avformat_close_input(&formatCtx);
        if (completion) {
            completion(NULL);
        }
    }else{
        /* 刚才只是打开了文件，检测了下文件头而已，并没有去找流信息；因此开始读包以获取流信息*/
        if (0 != avformat_find_stream_info(formatCtx, NULL)) {
            avformat_close_input(&formatCtx);
            if (completion) {
                completion(NULL);
            }
        }else{
            ///用于查看详细信息，调试的时候打出来看下很有必要
            av_dump_format(formatCtx, 0, [moviePath.lastPathComponent cStringUsingEncoding: NSUTF8StringEncoding], false);
            
            /* 接下来，尝试找到我们关心的信息*/
            
            NSMutableString *text = [[NSMutableString alloc]init];
            
            /*AVFormatContext 的 streams 变量是个数组，里面存放了 nb_streams 个元素，每个元素都是一个 AVStream */
            [text appendFormat:@"共%u个流，%llds",formatCtx->nb_streams,formatCtx->duration/AV_TIME_BASE];
            //遍历所有的流
            for (unsigned int  i = 0; i < formatCtx->nb_streams; i++) {
                
                AVStream *stream = formatCtx->streams[i];
                AVCodecContext *codec = stream->codec;
                
                switch (codec->codec_type) {
                        ///视频流
                    case AVMEDIA_TYPE_VIDEO:
                    {
                        _stream_index_video = i;
                    }
                        break;
                    default:
                    {
                        
                    }
                        break;
                }
            }
            
            if (completion) {
                completion(formatCtx);
            }
        }
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end

