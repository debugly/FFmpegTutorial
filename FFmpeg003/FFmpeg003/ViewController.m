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
#import <libswscale/swscale.h>
#import "MRVideoFrame.h"

#ifndef __weakSelf__
#define __weakSelf__     __weak   __typeof(self) $weakself = self;
#endif

#ifndef __strongSelf__
#define __strongSelf__   __strong __typeof($weakself) self = $weakself;
#endif

#define USEBITMAP 1

@interface ViewController ()

@property (weak, nonatomic) UIActivityIndicatorView *indicatorView;
@property (assign, nonatomic) AVFormatContext *formatCtx;
@property (strong, nonatomic) dispatch_queue_t io_queue;
@property (nonatomic,strong) NSMutableArray *videoFrames;
@property (nonatomic,assign) AVCodecContext *videoCodecCtx;
@property (nonatomic,assign) unsigned int stream_index_video;
@property (weak, nonatomic) UIImageView *renderView;
@property (assign, nonatomic) float videoTimeBase;
@property (nonatomic,assign) BOOL bufferOk;
///画面高度，单位像素
@property (nonatomic,assign) int vwidth;
@property (nonatomic,assign) int vheight;
//视频像素格式
@property (nonatomic,assign) enum AVPixelFormat format;
@property (nonatomic,assign) uint8_t *out_buffer;
@property (nonatomic,assign) struct SwsContext * img_convert_ctx;
@property (nonatomic,assign) AVFrame *pFrameYUV;
@property (nonatomic,strong) NSNumber *lastPts;

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
    if (self.img_convert_ctx) {
        sws_freeContext(self.img_convert_ctx);
    }
    
    if (self.pFrameYUV) {
        av_frame_free(&self->_pFrameYUV);
    }
    
    if(self.out_buffer){
        free(self.out_buffer);
        self.out_buffer = NULL;
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
    //    moviePath = @"http://debugly.cn/repository/test.mp4";
    moviePath = @"http://localhost/ffmpeg-test/test.mp4";
    moviePath = @"http://localhost/root/mp4/test.mp4";
    if ([moviePath hasPrefix:@"http"]) {
        //Using network protocols without global network initialization. Please use avformat_network_init(), this will become mandatory later.
        //播放网络视频的时候，要首先初始化下网络模块。
        avformat_network_init();
    }
    
    NSLog(@"load movie:%@",moviePath);
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        // 打开文件
        [self openStreamWithPath:moviePath completion:^(AVFormatContext *formatCtx){
            
            if(formatCtx){
                
                self.formatCtx = formatCtx;
                // 打开视频流
                BOOL succ = [self openVideoStream];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    if (succ) {
                        
                        // 渲染View
                        if (!self.renderView) {
                            UIImageView *render = [[UIImageView alloc]initWithFrame:self.view.bounds];
                            [self.view addSubview:render];
                            render.contentMode = UIViewContentModeScaleAspectFit;
                            render.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
                            self.renderView = render;
                        }
#if USEBITMAP
                        enum AVPixelFormat pix_fmt = PIX_FMT_RGB24;
#else
                        enum AVPixelFormat pix_fmt = PIX_FMT_NV12;
#endif
                        const int picSize = avpicture_get_size(pix_fmt, self.vwidth, self.vheight);
                        
                        self.out_buffer = malloc(picSize);
                        self.img_convert_ctx = sws_getContext(self.vwidth, self.vheight, self.format, self.vwidth, self.vheight, pix_fmt, SWS_BICUBIC, NULL, NULL, NULL);
                        
                        self.pFrameYUV = av_frame_alloc();
                        avpicture_fill((AVPicture *)self.pFrameYUV, self.out_buffer, pix_fmt, self.vwidth, self.vheight);
                        
                        // 开始读包解码
                        [self startReadFrames];
                        // 播放驱动
                        [self videoTick];
                    }else{
                        NSLog(@"不支持的编码类型！");
                        [indicatorView stopAnimating];
                    }
                });
            }else{
                NSLog(@"不能打开流");
                dispatch_async(dispatch_get_main_queue(), ^{
                    [indicatorView stopAnimating];
                });
            }
        }];
    });
}

- (BOOL)checkIsBufferOK
{
    float buffedDuration = 0.0;
    static float kMinBufferDuration = 1;
    
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
            [_indicatorView stopAnimating];
            
            if (videoFrame.eof) {
                NSLog(@"视频播放结束");
            }else{
                [self displayVideoFrame:videoFrame];
                
                float interval = videoFrame.duration;
                NSTimeInterval time = MAX(interval, 0.01);
                dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, time * NSEC_PER_SEC);
                dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                    [self videoTick];
                });
            }
            return;
        }else{
            NSLog(@"what?");
        }
    }
    
    {
        self.bufferOk = NO;
        [self.view bringSubviewToFront:_indicatorView];
        [_indicatorView startAnimating];
        __weakSelf__
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strongSelf__
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
    
    __weakSelf__
    dispatch_async(self.io_queue, ^{
        
        while (1) {
            AVPacket pkt;
            __strongSelf__
            // 读包
            if (av_read_frame(self->_formatCtx,&pkt) >= 0) {
                
                // 只处理视频
                if (pkt.stream_index == self.stream_index_video) {
                    
                    __weakSelf__
                    // 解码
                    [self handleVideoPacket:&pkt completion:^(AVFrame *video_frame) {
                        __strongSelf__
                        // 根据配置把数据转换成 NV12 或者 RGB24
                        int pictRet = sws_scale(self.img_convert_ctx, (const uint8_t* const*)video_frame->data, video_frame->linesize, 0, self.vheight, self.pFrameYUV->data, self.pFrameYUV->linesize);
                        if (pictRet <= 0) {
                            return ;
                        }
                        UIImage *img = [self imageFromAVFrame:self.pFrameYUV width:self.vwidth height:self.vheight];
                        
                        if (img) {
                            // 获取时长
                            const double frameDuration = av_frame_get_pkt_duration(video_frame) * self.videoTimeBase;
                            
                            // 构造模型
                            MRVideoFrame *frame = [[MRVideoFrame alloc]init];
                            frame.duration = frameDuration;
                            frame.image = img;
                            // 存放到内存
                            @synchronized(self) {
                                [self.videoFrames addObject:frame];
                                if (!self.bufferOk) {
                                    self.bufferOk = [self checkIsBufferOK];
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

#if USEBITMAP

- (UIImage *)imageFromAVFrame:(AVFrame*)video_frame width:(int)width height:(int)height
{
    const UInt8 *rgb = video_frame->data[0];
    size_t bytesPerRow = video_frame->linesize[0];
    CFIndex length = bytesPerRow*height;
    
    CGBitmapInfo bitmapInfo = kCGBitmapByteOrderDefault;
    ///需要copy！因为video_frame是重复利用的；里面的数据会变化！
    CFDataRef data = CFDataCreate(kCFAllocatorDefault, rgb, length);
    CGDataProviderRef provider = CGDataProviderCreateWithCFData(data);
    CGColorSpaceRef colorSpace = CGColorSpaceCreateDeviceRGB();
    
    CGImageRef cgImage = CGImageCreate(width,
                                       height,
                                       8,
                                       24,
                                       bytesPerRow,
                                       colorSpace,
                                       bitmapInfo,
                                       provider,
                                       NULL,
                                       NO,
                                       kCGRenderingIntentDefault);
    CGColorSpaceRelease(colorSpace);
    
    UIImage *image = [UIImage imageWithCGImage:cgImage];
    CGImageRelease(cgImage);
    CGDataProviderRelease(provider);
    CFRelease(data);
    
    return image;
}

#else

#pragma mark - YUV(NV12)-->CIImage--->UIImage

//性能是很差,平均需要 0.3s，很不适合用来渲染视频 ！！！
- (UIImage *)cvPixelBufferReftoUIImage:(CVPixelBufferRef)pixelBuffer w:(int)w h:(int)h
{
    // CIImage Conversion
    CIImage *coreImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    CIContext *context = [CIContext contextWithOptions:nil];
    ///引发内存泄露? https://stackoverflow.com/questions/32520082/why-is-cicontext-createcgimage-causing-a-memory-leak
    NSTimeInterval begin = CFAbsoluteTimeGetCurrent();
    CGImageRef cgImage = [context createCGImage:coreImage
                                       fromRect:CGRectMake(0, 0, w, h)];
    NSTimeInterval end = CFAbsoluteTimeGetCurrent();
    // UIImage Conversion
    UIImage *uiImage = [[UIImage alloc] initWithCGImage:cgImage
                                                  scale:1.0
                                            orientation:UIImageOrientationUp];
    
    NSLog(@"decode an image cost :%g",end-begin);
    CVPixelBufferRelease(pixelBuffer);
    CGImageRelease(cgImage);
    return uiImage;
}

//https://stackoverflow.com/questions/25659671/how-to-convert-from-yuv-to-ciimage-for-ios
- (UIImage *)imageFromAVFrame:(AVFrame *)pFrame width:(int)width height:(int)height
{
    // NV12数据转成 UIImage
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
    
    unsigned char *y_ch0 = pFrame->data[0];
    unsigned char *y_ch1 = pFrame->data[1];
    
    memcpy(yDestPlane, y_ch0, w * h);
    unsigned char *uvDestPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
    
    // Here y_ch1 is UV-Plane of YUV(NV12) data.
    memcpy(uvDestPlane, y_ch1, w * h / 2.0);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    if (result != kCVReturnSuccess) {
        NSLog(@"Unable to create cvpixelbuffer %d", result);
    }
    
    UIImage *image = [self cvPixelBufferReftoUIImage:pixelBuffer w:w h:h];
    return image;
}

#endif

- (BOOL)openVideoStream
{
    AVStream *stream = _formatCtx->streams[_stream_index_video];
    return [self openVideoStream:stream];
}

- (BOOL)openVideoStream:(AVStream *)stream
{
    AVCodecContext *codecCtx = stream->codec;
    // find the decoder for the video stream
    AVCodec *codec = avcodec_find_decoder(codecCtx->codec_id);
    if (!codec){
        return NO;
    }
    
    // open codec
    if (avcodec_open2(codecCtx, codec, NULL) < 0){
        return NO;
    }
    
    _videoCodecCtx = codecCtx;

    float fps = 0;
    avStreamFPSTimeBase(stream, 0.04, &fps, &_videoTimeBase);
    return YES;
}

static void avStreamFPSTimeBase(AVStream *st, float defaultTimeBase, float *pFPS, float *pTimeBase)
{
    CGFloat fps, timebase;
    
    if (st->time_base.den && st->time_base.num)
        timebase = av_q2d(st->time_base);
    else if(st->codec->time_base.den && st->codec->time_base.num)
        timebase = av_q2d(st->codec->time_base);
    else
        timebase = defaultTimeBase;
    
    if (st->codec->ticks_per_frame != 1) {
        
        timebase *= st->codec->ticks_per_frame;
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
                        ///画面宽度，单位像素
                        self.vwidth = codec->width;
                        ///画面高度，单位像素
                        self.vheight = codec->height;
                        //视频像素格式
                        self.format  = codec->pix_fmt;
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
