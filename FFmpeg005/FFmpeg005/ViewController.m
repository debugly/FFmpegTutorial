//
//  ViewController.m
//  FFmpeg005
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
#import "MRPacketQueue.h"
#import "MRConvertUtil.h"
#import <GLKit/GLKit.h>

#ifndef __weakSelf__
#define __weakSelf__     __weak   __typeof(self) $weakself = self;
#endif

#ifndef __strongSelf__
#define __strongSelf__   __strong __typeof($weakself) self = $weakself;
#endif

// 按照fps=24计算，缓存20s的视频包；缓存2s的解码帧;
static int kPacketCacheCount = 24 * 20;
static float kMinBufferDuration = 2;
static int kFrameCacheCount = 24 * 2;

@interface ViewController ()

@property (weak, nonatomic) UIActivityIndicatorView *indicatorView;

@property (assign, nonatomic) AVFormatContext *formatCtx;
@property (strong, nonatomic) dispatch_queue_t read_queue;
@property (nonatomic,assign,getter=isReading) BOOL reading;

@property (strong, nonatomic) dispatch_queue_t decode_queue;
@property (nonatomic,assign,getter=isDecoding) BOOL decoding;

@property (nonatomic,strong) NSMutableArray *videoFrames;
@property (nonatomic,assign) AVCodecContext *videoCodecCtx;
@property (nonatomic,assign) MRPacketQueue packetQueue;

@property (nonatomic,assign) int stream_index_video;

@property (assign, nonatomic) float videoTimeBase;
@property (nonatomic,assign) BOOL bufferOk;
@property (nonatomic,assign) BOOL eof;

///画面高度，单位像素
@property (nonatomic,assign) int vwidth;
@property (nonatomic,assign) int vheight;
//视频像素格式
@property (nonatomic,assign) enum AVPixelFormat format;
//格式转换
@property (nonatomic,assign) uint8_t *out_buffer;
@property (nonatomic,assign) struct SwsContext * img_convert_ctx;
@property (nonatomic,assign) AVFrame *pFrameYUV;

@property (nonatomic, strong) EAGLContext *glContext;
@property (nonatomic, strong) GLKView *glView;
@property (nonatomic, strong) CIContext *ciContext;

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
        self.formatCtx = NULL;
    }
    
    if(self.videoCodecCtx){
        avcodec_close(self.videoCodecCtx);
        self.videoCodecCtx = NULL;
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
    //moviePath = @"http://localhost/ffmpeg-test/test.mp4";
    moviePath = @"http://10.7.36.117/root/mp4/test.mp4";
    if ([moviePath hasPrefix:@"http"]) {
        //Using network protocols without global network initialization. Please use avformat_network_init(), this will become mandatory later.
        //播放网络视频的时候，要首先初始化下网络模块。
        avformat_network_init();
    }
    
    NSLog(@"load movie:%@",moviePath);
    
    __weakSelf__
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        __strongSelf__
        // 打开文件
        [self openStreamWithPath:moviePath completion:^(AVFormatContext *formatCtx){
            __strongSelf__
            if(formatCtx){
                
                self.formatCtx = formatCtx;
                // 打开视频流
                BOOL succ = [self openVideoStream];
                
                dispatch_async(dispatch_get_main_queue(), ^{
                    
                    if (succ) {
                        
                        // 渲染View
                        if(!self.glContext){
                            self.glContext = [[EAGLContext alloc] initWithAPI:kEAGLRenderingAPIOpenGLES3];
                            self.ciContext = [CIContext contextWithEAGLContext:self.glContext];
                            
                            CGSize vSize = self.view.bounds.size;
                            CGFloat vh = vSize.width * self.vheight / self.vwidth;
                            CGRect rect = CGRectMake(0, (vSize.height-vh)/2, vSize.width , vh);
                            self.glView = [[GLKView alloc] initWithFrame:rect context:self.glContext];
                            [self.view addSubview:self.glView];
                        }

                        enum AVPixelFormat pix_fmt = PIX_FMT_NV12;
                        const int picSize = avpicture_get_size(pix_fmt, self.vwidth, self.vheight);
                        
                        self.out_buffer = malloc(picSize);
                        self.img_convert_ctx = sws_getContext(self.vwidth, self.vheight, self.format, self.vwidth, self.vheight, pix_fmt, SWS_BICUBIC, NULL, NULL, NULL);
                        
                        self.pFrameYUV = av_frame_alloc();
                        avpicture_fill((AVPicture *)self.pFrameYUV, self.out_buffer, pix_fmt, self.vwidth, self.vheight);
                        
                        // 启动渲染驱动
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

#pragma mark 检查缓存

- (BOOL)checkIsBufferOK
{
    float buffedDuration = 0.0;
    //如果没有缓冲好，那么就每隔1s过来看下buffer
    for (MRVideoFrame *frame in self.videoFrames) {
        buffedDuration += frame.duration;
        if (buffedDuration >= kMinBufferDuration) {
            break;
        }
    }
    
    return buffedDuration >= kMinBufferDuration;
}

- (bool)checkPacketFull
{
    @synchronized(self) {
        
        int count = self.packetQueue.nb_packets;
        
        if (count < kPacketCacheCount){
            return false;
        }
        
        return true;
    }
}

- (bool)checkFrameFull
{
    @synchronized(self) {
        
        if (!self.videoFrames) {
            return false;
        }
        
        NSUInteger count = [self.videoFrames count];
        if (count < kFrameCacheCount) {
            return false;
        } else {
            return true;
        }
    }
}

#pragma mark - 渲染驱动

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
            
            [self displayVideoFrame:videoFrame];
            
            float interval = videoFrame.duration;
            NSTimeInterval time = MAX(interval, 0.01);
            NSLog(@"display:%g",interval);
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, time * NSEC_PER_SEC);
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [self videoTick];
            });
            
            ///播放势必要消耗帧，所以检查下是否需要解码更多帧
            [self notifiDecodeVideo];
            
            return;
        }
    }
    
    {
        if (self.eof) {
            [_indicatorView stopAnimating];
            NSLog(@"视频播放结束");
        }else{
            NSLog(@"loading");
            ///播放势必要消耗帧，所以检查下是否需要解码更多帧
            [self notifiDecodeVideo];
            
            self.bufferOk = NO;
            [self.view bringSubviewToFront:_indicatorView];
            [_indicatorView startAnimating];
            __weakSelf__
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                __strongSelf__
                [self videoTick];
            });
        }
    }
}

- (void)displayVideoFrame:(MRVideoFrame *)frame
{
    CIImage *ciimage = frame.ciImage;
    if (_glContext != [EAGLContext currentContext]){
        [EAGLContext setCurrentContext:_glContext];
    }
    [_glView bindDrawable];
    CGFloat scale = [[UIScreen mainScreen]scale];
    
    [_ciContext drawImage:ciimage inRect:CGRectMake(0, 0, _glView.bounds.size.width*scale, _glView.bounds.size.height*scale) fromRect:ciimage.extent];
    
    [_glView display];
}

#pragma mark - 解码线程

- (void)notifiDecodeVideo
{
    bool full = [self checkFrameFull];
    if (!full) {
        [self startDecodePacketToFrames];
    }
}

- (CIImage *)imageFromAVFrame:(AVFrame*)video_frame w:(int)w h:(int)h
{
    CVPixelBufferRef pixelBuffer = [MRConvertUtil pixelBufferFromAVFrame:video_frame w:self.vwidth h:self.vheight];
    CIImage *ciImage = nil;
    if (pixelBuffer) {
        ciImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    }
    return ciImage;
}

- (void)startDecodePacketToFrames
{
    if (!self.decode_queue) {
        dispatch_queue_t decode_queue = dispatch_queue_create("decode_queue", DISPATCH_QUEUE_SERIAL);
        self.decode_queue = decode_queue;
    }
    
    if (self.isDecoding) {
        return;
    }
    
    self.decoding = YES;
    
    __weakSelf__
    dispatch_async(self.decode_queue, ^{
        
        __strongSelf__
        
        while (![self checkFrameFull]) {
            
            ///解码
            AVPacket pkt;
            bool ok = false;
            @synchronized(self) {
                ok = mr_packet_queue_get(&self->_packetQueue, &pkt);
            }
            
            NSLog(@"get cache packet:%@",ok?@"succ":@"failed");
            
            if (ok) {
                AVFrame *video_frame = [self decodeVideoPacket:&pkt];
                av_packet_unref(&pkt);
                NSLog(@"decode packet:%@",video_frame!=NULL?@"succ":@"failed");
                if (video_frame) {
                    
                    // 根据配置把数据转换成 NV12 或者 RGB24
                    int pictRet = sws_scale(self.img_convert_ctx, (const uint8_t* const*)video_frame->data, video_frame->linesize, 0, self.vheight, self.pFrameYUV->data, self.pFrameYUV->linesize);
                    
                    if (pictRet <= 0) {
                        av_frame_free(&video_frame);
                        return ;
                    }
                    
                    CIImage *img = [self imageFromAVFrame:self.pFrameYUV w:self.vwidth h:self.vheight];
                    
                    // 获取时长
                    const double frameDuration = av_frame_get_pkt_duration(video_frame) * self.videoTimeBase;
                    av_frame_free(&video_frame);
                    // 构造模型
                    MRVideoFrame *frame = [[MRVideoFrame alloc]init];
                    frame.duration = frameDuration;
                    frame.ciImage = img;
                    // 存放到内存
                    @synchronized(self) {
                        [self.videoFrames addObject:frame];
                        if (!self.bufferOk) {
                            self.bufferOk = [self checkIsBufferOK];
                        }
                    }
                }
                ///缓存消耗了就去读包
                dispatch_async(dispatch_get_main_queue(), ^{
                    [self notifiReadPacket];
                });
            } else {
                if (!self.eof) {
                    ///缓存消耗了就去读包
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self notifiReadPacket];
                    });
                }
                ///缓存里没了就停止解码
                break;
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            if ([self checkFrameFull]) {
                NSLog(@"frame cache full");
            }
            self.decoding = NO;
        });
    });
}

- (AVFrame *)decodeVideoPacket:(AVPacket *)packet
{
    int gotframe = 0;
    AVFrame *video_frame = av_frame_alloc();//老版本是 avcodec_alloc_frame
    
    avcodec_decode_video2(_videoCodecCtx, video_frame, &gotframe, packet);
    
    if (gotframe <= 0) {
        NSLog(@"decode video error, skip packet");
        av_frame_free(&video_frame);
    }
    return video_frame;
}


#pragma mark - 读包线程

- (void)cacheAVPacket:(AVPacket *)packet
{
    @synchronized(self) {
        mr_packet_queue_put(&self->_packetQueue, packet);
    }
}

- (void)notifiReadPacket
{
    if (!self.read_queue) {
        dispatch_queue_t read_queue = dispatch_queue_create("read_queue", DISPATCH_QUEUE_SERIAL);
        self.read_queue = read_queue;
    }
    
    if (self.eof) {
        return;
    }
    
    if (self.isReading) {
        return;
    }
    
    self.reading = YES;
    
    __weakSelf__
    dispatch_async(self.read_queue, ^{
        
        /// buffer 不够？继续读取！
        while (![self checkPacketFull]) {
            NSLog(@"read packet");
            AVPacket pkt1, *pkt = &pkt1;
            __strongSelf__
            // 读包
            if (av_read_frame(self->_formatCtx,pkt) >= 0) {
                ///处理视频流
                if (pkt1.stream_index == self.stream_index_video) {
                    NSLog(@"cache packet");
                    [self cacheAVPacket:pkt];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self notifiDecodeVideo];
                    });
                } else {
                    NSLog(@"ignore packet");
                }
                av_packet_unref(pkt);
            }else{
                NSLog(@"eof,stop read more packet!");
                dispatch_sync(dispatch_get_main_queue(), ^{
                    self.eof = YES;
                });
                break;
            }
        }
        
        dispatch_async(dispatch_get_main_queue(), ^{
            NSLog(@"packet cache full");
            self.reading = NO;
        });
        
    });
}

#pragma mark - 打开流

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

/**
 缓存20s的视频包；缓存2s的解码帧;
 
 19fps GPU 10% CPU 35% Memory 70M
 
 fps低分析：CPU任务重
 */

