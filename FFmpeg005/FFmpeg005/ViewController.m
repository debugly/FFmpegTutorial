//
//  ViewController.m
//  FFmpeg002
//
//  Created by 许乾隆 on 2017/9/18.
//  Copyright © 2017年 Awesome FFmpeg Study Demo. All rights reserved.
//  开源地址: https://github.com/debugly/StudyFFmpeg

#import "ViewController.h"
#import <libavutil/log.h>
#import <libavformat/avformat.h>
#import <libavcodec/avcodec.h>
#import <libavutil/pixdesc.h>
#import <libavutil/pixfmt.h>
#import <libavutil/samplefmt.h>
#import <libavutil/imgutils.h>

#import <AVFoundation/AVSampleBufferDisplayLayer.h>
#import "OpenGLView20.h"
#import "NSTimer+Util.h"

#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>
#import <Accelerate/Accelerate.h>
#import <libswresample/swresample.h>
#import "MRAudioFrame.h"
#import "MRAudioManager.h"

#ifndef _weakSelf_SL
#define _weakSelf_SL     __weak   __typeof(self) $weakself = self;
#endif

#ifndef _strongSelf_SL
#define _strongSelf_SL   __strong __typeof($weakself) self = $weakself;
#endif

#define usev3 0

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UITextView *tv;

@property (assign, nonatomic) AVFormatContext *formatCtx;
@property (assign, nonatomic) AVCodecContext *vidoeCodecCtx;
@property (assign, nonatomic) AVFrame *pFrame;

@property (assign, nonatomic) enum AVCodecID codecId_video;
@property (assign, nonatomic) unsigned int stream_index_video;
@property (assign, nonatomic) enum AVPixelFormat pix_fmt;
@property (weak, nonatomic) IBOutlet UIImageView *render;
@property (strong, nonatomic) dispatch_queue_t io_queue;
@property (assign, nonatomic) CVPixelBufferPoolRef pixelBufferPool;
@property (strong, nonatomic) AVSampleBufferDisplayLayer *sampleBufferDisplayLayer;
@property (weak, nonatomic) OpenGLView20 *glView;
@property (assign, nonatomic) CGFloat videoTimeBase;
@property (assign, nonatomic) CGFloat fps;
@property (weak, nonatomic) NSTimer *readFramesTimer;


@property (assign, nonatomic) unsigned int stream_index_audio;
@property (nonatomic,copy) NSString *audioRoute;
@property (nonatomic,assign) Float64  samplingRate;
@property (nonatomic,assign) UInt32   numBytesPerSample;
//@property (nonatomic,assign) Float32  outputVolume;

@property (nonatomic,assign) AudioUnit audioUnit;
@property (nonatomic,assign) AudioStreamBasicDescription outputFormat;
@property (nonatomic,assign) UInt32   numOutputChannels;
@property (nonatomic,assign) float    *outData;

@property (nonatomic,strong) NSMutableArray *audioFrames;
@property (nonatomic,assign) AVCodecContext *audioCodecCtx;
#if usev3
@property (nonatomic,assign) enum AVCodecID codecId_audio;
#endif
@property (nonatomic,assign) SwrContext  *swrContext;
@property (nonatomic,assign) void        *swrBuffer;
@property (nonatomic,assign) NSUInteger  swrBufferSize;
@property (nonatomic,assign) CGFloat     audioTimeBase;
@property (nonatomic,assign) CGFloat     currentPlayPosition;
@property (atomic,assign) BOOL     canGiveFrame;
@property (nonatomic,strong) MRAudioFrame *currentAudioFrame;
@property (nonatomic,assign) NSUInteger    currentAudioFramePos;

@end

@implementation ViewController

static void fflog(void *context, int level, const char *format, va_list args){
    @autoreleasepool {
        NSString* message = [[NSString alloc] initWithFormat: [NSString stringWithUTF8String: format] arguments: args];
        
        NSLog(@"ff:%d%@",level,message);
    }
}

- (void)dealloc
{
    if (NULL != _formatCtx) {
        avformat_close_input(&_formatCtx);
    }
    if (self.readFramesTimer) {
        [self.readFramesTimer invalidate];
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    NSLog(@"************************************");
    NSLog(@"【v%d】\n%s",avcodec_version(),avcodec_configuration());
    NSLog(@"************************************");
    self.sampleBufferDisplayLayer = [[AVSampleBufferDisplayLayer alloc] init];
    self.sampleBufferDisplayLayer.frame = self.view.bounds;
    self.sampleBufferDisplayLayer.position = CGPointMake(CGRectGetMidX(self.view.bounds), CGRectGetMidY(self.view.bounds));
    self.sampleBufferDisplayLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    self.sampleBufferDisplayLayer.opaque = YES;
    [self.view.layer addSublayer:self.sampleBufferDisplayLayer];
    
    OpenGLView20 *glView = [[OpenGLView20 alloc]initWithFrame:self.view.bounds];
    [self.view addSubview:glView];
    self.glView = glView;
    
    [[MRAudioManager audioManager]activateAudioSession];
    
    _samplingRate = [[MRAudioManager audioManager]samplingRate];
    _numBytesPerSample = [[MRAudioManager audioManager]numBytesPerSample];
    _numOutputChannels = [[MRAudioManager audioManager]numOutputChannels];
    
}

- (AVFormatContext *)openInput:(NSString *)moviePath {
    
    AVFormatContext *formatCtx = NULL;
    /*
     打开输入流，读取文件头信息，不会打开解码器；
     */
    ///低版本是 av_open_input_file 方法
    if (0 != avformat_open_input(&formatCtx, [moviePath cStringUsingEncoding:NSUTF8StringEncoding], NULL, NULL)) {
        ///关闭，释放内存，置空
        avformat_close_input(&formatCtx);
    }
    
    /* 刚才只是打开了文件，检测了下文件头而已，并没有去找流信息；因此开始读包以获取流信息*/
    if (0 != avformat_find_stream_info(formatCtx, NULL)) {
        avformat_close_input(&formatCtx);
    }
    
    ///用于查看详细信息，调试的时候打出来看下很有必要
    av_dump_format(formatCtx, 0, [moviePath.lastPathComponent cStringUsingEncoding: NSUTF8StringEncoding], false);
    
    return formatCtx;
}

- (void)openAudioStream:(AVStream *)stream
{
#if usev3
    //取出来流信息结构体
    AVCodecParameters *codecpar = stream->codecpar;
    //采样率
    int sample_rate = codecpar->sample_rate;
    //声道数
    int channels = codecpar->channels;
    //比特率
    int64_t brate = codecpar->bit_rate;
    //时长
    // int64_t duration = stream->duration;
    //解码器id
    _codecId_audio = codecpar->codec_id;
    //根据解码器id找到对应名称
    const char *codecDesc = avcodec_get_name(_codecId_audio);
    //音频采样格式
    enum AVSampleFormat format = codecpar->format;
    //获取音频采样格式名称
    const char * formatDesc = av_get_sample_fmt_name(format);
    
    [text appendFormat:@"\n\nAudio\n%d Kbps，%.1f KHz， %d channels，%s，%s",(int)(brate/1000.0),sample_rate/1000.0,channels,codecDesc,formatDesc];
    
    const AVCodec *pCodec = NULL;
    //根据编码id找到编码器
    pCodec = avcodec_find_decoder(_codecId_audio);
    if (pCodec == NULL) {
        NSLog(@"不支持的编码格式！");
        return ;
    }
    
    const AVCodecParameters * codecpar = _formatCtx->streams[_stream_index_audio]->codecpar;
    
    _audioCodecCtx = avcodec_alloc_context3(pCodec);
    
    avcodec_parameters_to_context(_audioCodecCtx, codecpar);
    
    //打开吧！
    if (F_OK != avcodec_open2(_audioCodecCtx, pCodec, NULL)) {
        ///打开失败？释放下内存
        avcodec_free_context(&_audioCodecCtx);
        NSLog(@"无法打开流！");
        return ;
    }
#else
    {
        AVCodecContext *codecCtx = stream->codec;
        
        // find the decoder for the video stream
        AVCodec *codec = avcodec_find_decoder(codecCtx->codec_id);
        if (!codec)
            return;
        
        // open codec
        if (avcodec_open2(codecCtx, codec, NULL) < 0)
            return;
        
        _audioCodecCtx = codecCtx;
    }
#endif
    
    if (![self audioCodecIsSupported:_audioCodecCtx]) {
        
        id<MRAudioManager> audioManager = [MRAudioManager audioManager];
        
        int64_t out_ch_layout = av_get_default_channel_layout(_audioCodecCtx->channels);
        int64_t in_ch_layout = av_get_default_channel_layout(audioManager.numOutputChannels);
        
        SwrContext  *swrContext = swr_alloc_set_opts(NULL,
                                                     in_ch_layout,
                                                     AV_SAMPLE_FMT_S16,
                                                     audioManager.samplingRate,
                                                     out_ch_layout,
                                                     _audioCodecCtx->sample_fmt,
                                                     _audioCodecCtx->sample_rate,
                                                     0,
                                                     NULL);
        
        int result = 0;
        
        if (!swrContext || (result = swr_init(swrContext))) {
            
            if (swrContext)
                swr_free(&swrContext);
            
            avcodec_close(_audioCodecCtx);
            NSLog(@"创建swrContext失败！");
            return;
        }
        
        _swrContext = swrContext;
    }
    
    avStreamFPSTimeBase(stream, 0.025, 0, &_audioTimeBase);
}

- (void)openVideoStream:(AVStream *)stream
{
#if usev3
    //取出来流信息结构体
    AVCodecParameters *codecpar = stream->codecpar;
    ///画面宽度，单位像素
    int vwidth = codecpar->width;
    ///画面高度，单位像素
    int vheight = codecpar->height;
    //比特率
    int64_t brate = codecpar->bit_rate;
    //解码器id
    _codecId_video = codecpar->codec_id;
    //根据解码器id找到对应名称
    const char *codecDesc = avcodec_get_name(_codecId_video);
    //视频像素格式
    enum AVPixelFormat format = codecpar->format;
    //获取视频像素格式名称
    const char * formatDesc = av_get_pix_fmt_name(format);
    ///帧率
    CGFloat fps, timebase = 0.04;
    if (stream->time_base.den && stream->time_base.num) {
        timebase = av_q2d(stream->time_base);
    }
    
    if (stream->avg_frame_rate.den && stream->avg_frame_rate.num) {
        fps = av_q2d(stream->avg_frame_rate);
    }else if (stream->r_frame_rate.den && stream->r_frame_rate.num){
        fps = av_q2d(stream->r_frame_rate);
    }else{
        fps = 1.0 / timebase;
    }
    _pix_fmt = format;
    
    const AVCodec *pCodec = NULL;
    //根据编码id找到编码器
    pCodec = avcodec_find_decoder(_codecId_video);
    if (pCodec == NULL) {
        NSLog(@"不支持的编码格式！");
        return ;
    }
    
    const AVCodecParameters * codecpar = _formatCtx->streams[_stream_index_video]->codecpar;
    
    _vidoeCodecCtx = avcodec_alloc_context3(pCodec);
    
    avcodec_parameters_to_context(_vidoeCodecCtx, codecpar);
    
    //打开吧！
    if (F_OK != avcodec_open2(_vidoeCodecCtx, pCodec, NULL)) {
        ///打开失败？释放下内存
        avcodec_free_context(&_vidoeCodecCtx);
        NSLog(@"无法打开流！");
        return ;
    }
    
    int width = codecpar->width;
    int height = codecpar->height;
#else
    AVCodecContext *vidoeCodecCtx = _formatCtx->streams[_stream_index_video]->codec;
    
    // find the decoder for the video stream
    AVCodec *codec = avcodec_find_decoder(vidoeCodecCtx->codec_id);
    if (!codec)
        return;
    
    // open codec
    if (avcodec_open2(vidoeCodecCtx, codec, NULL) < 0)
        return;
    
    int width = vidoeCodecCtx->width;
    int height = vidoeCodecCtx->height;
    
    _vidoeCodecCtx = vidoeCodecCtx;
    _pix_fmt = vidoeCodecCtx->pix_fmt;
#endif
    
    avStreamFPSTimeBase(stream, 0.04, &_fps, &_videoTimeBase);
    
    NSLog(@"video codec size: %d:%d fps: %.3f tb: %f",
          width,
          height,
          _fps,
          _videoTimeBase);
    
    NSLog(@"video start time %f", stream->start_time * _videoTimeBase);
    NSLog(@"video disposition %d", stream->disposition);
    
    CGSize vSize = self.view.bounds.size;
    CGFloat vh = vSize.width * height / width;
    self.glView.frame = CGRectMake(0, (vSize.height-vh)/2, vSize.width , vh);
    
}

- (void)resetStatus
{
    _stream_index_video = -1;
    _stream_index_audio = -1;
    _audioFrames = [NSMutableArray array];
}

- (BOOL)videoStreamValidate
{
    return _stream_index_video != -1;
}

- (BOOL)audioStreamValidate
{
    return _stream_index_audio != -1;
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
    
    [self resetStatus];
    
    _weakSelf_SL
    [MRAudioManager audioManager].outputBlock = ^(float *outData, UInt32 numFrames, UInt32 numChannels) {
        _strongSelf_SL
        [self fetchData:outData numFrames:numFrames numChannels:numChannels];
        //        [self audioCallbackFillData: outData numFrames:numFrames numChannels:numChannels];
    };
    
    av_log_set_callback(fflog);//日志比较多，打开日志后会阻塞当前线程
    av_log_set_flags(AV_LOG_PANIC);
    
    ///初始化libavformat，注册所有文件格式，编解码库；这不是必须的，如果你能确定需要打开什么格式的文件，使用哪种编解码类型，也可以单独注册！
    av_register_all();
    
    ///使用本地server地址
    NSString *moviePath = @"http://localhost/ffmpeg-test/123.mp3";
    
    if ([moviePath hasPrefix:@"http"]) {
        //Using network protocols without global network initialization. Please use avformat_network_init(), this will become mandatory later.
        //播放网络视频的时候，要首先初始化下网络模块。
        avformat_network_init();
    }
    
    AVFormatContext * formatCtx = [self openInput:moviePath];
    
    _formatCtx = formatCtx;
    
    /* 接下来，尝试找到我们关系的信息*/
    
    NSMutableString *text = [[NSMutableString alloc]init];
    
    /*AVFormatContext 的 streams 变量是个数组，里面存放了 nb_streams 个元素，每个元素都是一个 AVStream */
    [text appendFormat:@"共%u个流，%llds",formatCtx->nb_streams,formatCtx->duration/AV_TIME_BASE];
    
    
    ///初始化音频配置
    //[self activateAudioSession];
    
    
    //遍历所有的流
    for (unsigned int i = 0; i < formatCtx->nb_streams; i++) {
        
        AVStream *stream = formatCtx->streams[i];
#if usev3
        enum AVMediaType codec_type = stream->codecpar->codec_type;
#else
        enum AVMediaType codec_type = stream->codec->codec_type;
#endif
        switch (codec_type) {
                ///音频流
            case AVMEDIA_TYPE_AUDIO:
            {
                //保存音频strema index.
                _stream_index_audio = i;
                [self openAudioStream:stream];
            }
                break;
                ///视频流
            case AVMEDIA_TYPE_VIDEO:
            {
                //保存视频strema index.
                _stream_index_video = i;
                [self openVideoStream:stream];
            }
                break;
            case AVMEDIA_TYPE_ATTACHMENT:
            {
                NSLog(@"附加信息流:%ld",i);
            }
                break;
            default:
            {
                NSLog(@"其他流:%ld",i);
            }
                break;
        }
    }
    
    ///这里简单一些，没隔 0.02s 读取一次，没有 buffer，读取一次渲染一次，所以基本上就是 0.02 更新一次画面
    self.readFramesTimer = [NSTimer mr_scheduledWithTimeInterval:0.01 repeats:YES block:^{
        _strongSelf_SL
        [self readFrame];
    }];
    
    [self tick];
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

#pragma mark - read frame loop

- (void)readFrame
{
    if (!self.io_queue) {
        dispatch_queue_t io_queue = dispatch_queue_create("read-io", DISPATCH_QUEUE_SERIAL);
        self.io_queue = io_queue;
    }
    
    BOOL notNeedRead = NO;
    @synchronized(_audioFrames) {
        if (self.audioFrames.count > 10) {
            notNeedRead = YES;
        }
    }
    
    if (notNeedRead) {
        return;
    }
    
    _weakSelf_SL
    dispatch_async(self.io_queue, ^{
        
        AVPacket pkt;
        _strongSelf_SL
        if (av_read_frame(_formatCtx,&pkt) >= 0) {
            if (pkt.stream_index == _stream_index_video) {
                
                _weakSelf_SL
                [self handleVideoPacket:&pkt completion:^(AVFrame *video_frame) {
                    _strongSelf_SL
                    [self displayVideoFrame:video_frame];
                }];
            }else if(pkt.stream_index == _stream_index_audio){
                [self decodeAudioPacket:&pkt];
            }
        }else{
            NSLog(@"eof,stop read more frame!");
            if (self.readFramesTimer) {
                [self.readFramesTimer invalidate];
            }
        }
        ///释放内存
        av_packet_unref(&pkt);
    });
}

#pragma mark - decode video packet

- (void)handleVideoPacket:(AVPacket *)packet completion:(void(^)(AVFrame *video_frame))completion
{
    if (!completion) {
        return;
    }
    
    //是否使用ffmpeg3新的解密函数
#define use_v3 0
    
#if use_v3
    int ret = avcodec_send_packet(_vidoeCodecCtx, packet);
    if (ret != 0) {
        printf("avcodec_send_packet failed.\n");
    }
    AVFrame *video_frame = av_frame_alloc();//老版本是 avcodec_alloc_frame
    
    ret = avcodec_receive_frame(_vidoeCodecCtx, video_frame);
    switch (ret) {
        case 0:
            while (ret==0) {
                completion(video_frame);
                ret = avcodec_receive_frame(_vidoeCodecCtx, video_frame);
            }
            break;
        case AVERROR(EAGAIN):
            printf("Resource temporarily unavailable\n");
            break;
        case AVERROR_EOF:
            printf("End of file\n");
            break;
        default:
            printf("other error.. code: %d\n", AVERROR(ret));
            break;
    }
    av_frame_free(&video_frame);
    video_frame = NULL;
#else
    int gotframe = 0;
    AVFrame *video_frame = av_frame_alloc();//老版本是 avcodec_alloc_frame
    
    int len = avcodec_decode_video2(_vidoeCodecCtx, video_frame, &gotframe, packet);
    if (len < 0) {
        NSLog(@"decode video error, skip packet");
    }
    if (gotframe) {
        completion(video_frame);
    }
    //用完后记得释放掉
    av_frame_unref(video_frame);
#endif
}

#pragma mark - display video frame

- (void)displayVideoFrame:(AVFrame *)video_frame
{
#define OPENGL 1
#define IMAGE  2
#define LAYER  3
    
#define TARGET LAYER
    
#if TARGET == OPENGL
    [self displayUseOpenGL:video_frame];
#endif
    
#if TARGET == IMAGE
    [self displayUseImage:video_frame];
#endif
    
#if TARGET == LAYER
    [self displayUseCVPixelBuffer:video_frame];
#endif
    
}

- (void)displayUseOpenGL:(AVFrame *)video_frame
{
    dispatch_sync(dispatch_get_main_queue(), ^{
        [self.glView displayYUV420pData:video_frame];
    });
}

- (void)displayUseImage:(AVFrame *)video_frame
{
    if (video_frame->format == AV_PIX_FMT_YUV420P || video_frame->format == AV_PIX_FMT_YUVJ420P) {
        unsigned char *nv12 = NULL;
        int nv12Size = AVFrameConvertToNV12Buffer(video_frame,&nv12);
        //        int nv12Size = AVFrameConvertTo420pBuffer(video_frame, &nv12);
        if (nv12Size > 0){
            
            UIImage *image = [self NV12toUIImage:_vidoeCodecCtx->width h:_vidoeCodecCtx->height buffer:nv12];
            dispatch_sync(dispatch_get_main_queue(), ^{
                [self.render setImage:image];
            });
            
            free(nv12);
            nv12 = NULL;
        }
    }
}

- (void)displayUseCVPixelBuffer:(AVFrame *)video_frame
{
    if (video_frame->format == AV_PIX_FMT_YUV420P || video_frame->format == AV_PIX_FMT_YUVJ420P) {
        unsigned char *nv12 = NULL;
        int nv12Size = AVFrameConvertToNV12Buffer(video_frame,&nv12);
        if (nv12Size > 0){
            [self useCVPixelBufferRefRender:_vidoeCodecCtx->width h:_vidoeCodecCtx->height linesize:video_frame->linesize[0] buffer:nv12 size:nv12Size];
            free(nv12);
            nv12 = NULL;
        }
    }
}

- (void)useCVPixelBufferRefRender:(int)w h:(int)h linesize:(int)linesize buffer:(unsigned char *)buffer size:(int)nv12Size
{
    CVReturn theError;
    if (!self.pixelBufferPool){
        NSMutableDictionary* attributes = [NSMutableDictionary dictionary];
        [attributes setObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(NSString*)kCVPixelBufferPixelFormatTypeKey];
        [attributes setObject:[NSNumber numberWithInt:w] forKey: (NSString*)kCVPixelBufferWidthKey];
        [attributes setObject:[NSNumber numberWithInt:h] forKey: (NSString*)kCVPixelBufferHeightKey];
        [attributes setObject:@(linesize) forKey:(NSString*)kCVPixelBufferBytesPerRowAlignmentKey];
        [attributes setObject:[NSDictionary dictionary] forKey:(NSString*)kCVPixelBufferIOSurfacePropertiesKey];
        
        theError = CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL, (__bridge CFDictionaryRef) attributes, &_pixelBufferPool);
        if (theError != kCVReturnSuccess){
            NSLog(@"CVPixelBufferPoolCreate Failed");
        }
    }
    
    CVPixelBufferRef pixelBuffer = nil;
    theError = CVPixelBufferPoolCreatePixelBuffer(NULL, self.pixelBufferPool, &pixelBuffer);
    if(theError != kCVReturnSuccess){
        NSLog(@"CVPixelBufferPoolCreatePixelBuffer Failed");
    }
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    void* base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    memcpy(base, buffer, nv12Size);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    //不设置具体时间信息
    CMSampleTimingInfo timing = {kCMTimeInvalid, kCMTimeInvalid, kCMTimeInvalid};
    //获取视频信息
    CMVideoFormatDescriptionRef videoInfo = NULL;
    OSStatus result = CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBuffer, &videoInfo);
    NSParameterAssert(result == 0 && videoInfo != NULL);
    
    CMSampleBufferRef sampleBuffer = NULL;
    result = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault,pixelBuffer, true, NULL, NULL, videoInfo, &timing, &sampleBuffer);
    NSParameterAssert(result == 0 && sampleBuffer != NULL);
    CFRelease(pixelBuffer);
    CFRelease(videoInfo);
    
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, YES);
    CFMutableDictionaryRef dict = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
    CFDictionarySetValue(dict, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.sampleBufferDisplayLayer enqueueSampleBuffer:sampleBuffer];
        CFRelease(sampleBuffer);
    });
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

#pragma mark - avframe to 420p

//yyyy yyyy
//uu
//vv
//https://www.cnblogs.com/lidabo/p/3326502.html
int AVFrameConvertTo420pBuffer(AVFrame *pFrame,unsigned char **yuv420p)
{
    if ((pFrame->format == AV_PIX_FMT_YUV420P) || (pFrame->format == AV_PIX_FMT_NV12) || (pFrame->format == AV_PIX_FMT_NV21) || (pFrame->format == AV_PIX_FMT_YUVJ420P)){
        
        int height = pFrame->height;
        int width = pFrame->width;
        //计算需要分配的内存大小
        int needSize = height * width * 1.5;
        
        if (*yuv420p == NULL) {
            //申请内存
            *yuv420p = malloc(needSize);
        }
        unsigned char *buf = *yuv420p;
        
        unsigned char *y = pFrame->data[0];
        unsigned char *u = pFrame->data[1];
        unsigned char *v = pFrame->data[2];
        
        unsigned int ys = pFrame->linesize[0];
        unsigned int us = pFrame->linesize[1];
        unsigned int vs = pFrame->linesize[2];
        
        //先写入Y（height * width 个 Y 数据）
        int offset=0;
        for (int i=0; i < height; i++)
        {
            memcpy(buf+offset,y + i * ys, width);
            offset+=width;
        }
        
        int uOffset = offset;
        int vOffset = offset + height/2 * width/2;
        
        int width_2 = width/2;
        
        ///按行写 U 和 V，写次写半行，V 从 5/4 处开始写
        for (int i = 0; i < height/2; i++)
        {
            ///由于对齐原因，有可能 us 比 width/2大，大的话就丢弃不要了
            memcpy(buf + uOffset,u + i * us, width_2);
            uOffset += width_2;
            
            memcpy(buf + vOffset,v + i * vs, width_2);
            vOffset += width_2;
        }
        
        return needSize;
    }
    
    return -1;
}


#pragma mark - yuv420p to yuv420sp

//http://blog.csdn.net/subfate/article/details/47305391

/**
 yyyy yyyy
 uu
 vv
 ->
 yyyy yyyy
 uv    uv
 */
void yuv420p_to_yuv420sp(unsigned char* yuv420p, unsigned char* yuv420sp, int width, int height)
{
    int i, j;
    int y_size = width * height;
    
    unsigned char* y = yuv420p;
    unsigned char* u = yuv420p + y_size;
    unsigned char* v = yuv420p + y_size * 5 / 4;
    
    unsigned char* y_tmp = yuv420sp;
    unsigned char* uv_tmp = yuv420sp + y_size;
    
    // y
    memcpy(y_tmp, y, y_size);
    
    // u
    for (j = 0, i = 0; j < y_size/2; j+=2, i++)
    {
        // 此处可调整U、V的位置，变成NV12或NV21
#if 01
        uv_tmp[j] = u[i];
        uv_tmp[j+1] = v[i];
#else
        uv_tmp[j] = v[i];
        uv_tmp[j+1] = u[i];
#endif
    }
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
    
    // CIImage Conversion
    CIImage *coreImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    
    CIContext *context = [CIContext contextWithOptions:nil];
    
    
    ///引发内存泄露? https://stackoverflow.com/questions/32520082/why-is-cicontext-createcgimage-causing-a-memory-leak
    CGImageRef cgImage = [context createCGImage:coreImage
                                       fromRect:CGRectMake(0, 0, w, h)];
    
    // UIImage Conversion
    UIImage *uiImage = [[UIImage alloc] initWithCGImage:cgImage
                                                  scale:1.0
                                            orientation:UIImageOrientationUp];
    
    CVPixelBufferRelease(pixelBuffer);
    CGImageRelease(cgImage);
    
    return uiImage;
}

#pragma mark - Audio

- (void) pauseAudio
{
    if (s_palying) {
        AudioOutputUnitStop(_audioUnit);
        s_palying = NO;
    }
}

static BOOL s_palying = NO;

- (void) playAudio
{
    if (!s_palying) {
        AudioOutputUnitStart(_audioUnit);
        s_palying = YES;
    }
}

static inline void MRAudioSessionInterruptionListener(void *inClientData, UInt32 inInterruption)
{
    ViewController *am = (__bridge ViewController *)inClientData;
    
    if (inInterruption == kAudioSessionBeginInterruption) {
        
    } else if (inInterruption == kAudioSessionEndInterruption) {
        
    }
}

static inline void MRSessionPropertyListener(void * inClientData,
                                             AudioSessionPropertyID inID,
                                             UInt32 inDataSize,
                                             const void * inData)
{
    ViewController *am = (__bridge ViewController *)inClientData;
    if (inID == kAudioSessionProperty_AudioRouteChange) {
        
    }else if (inID == kAudioSessionProperty_CurrentHardwareOutputVolume){
        
    }
}

///音频渲染回调；
static inline OSStatus MRRenderCallback(void *inRefCon,
                                        AudioUnitRenderActionFlags    * ioActionFlags,
                                        const AudioTimeStamp          * inTimeStamp,
                                        UInt32                        inOutputBusNumber,
                                        UInt32                        inNumberFrames,
                                        AudioBufferList                * ioData)
{
    ViewController *am = (__bridge ViewController *)inRefCon;
    
    return [am renderFrames:inNumberFrames ioData:ioData];
}

//- (void)activateAudioSession
//{
//#define kMax_Frame_Size     4096
//#define kMax_Chan           2
//#define kMax_Sample_Dumped  5
//
//    _outData = (float *)calloc(kMax_Frame_Size * kMax_Chan, sizeof(float));
//
//    //initialize audio session
//    AudioSessionInitialize(NULL, kCFRunLoopDefaultMode, MRAudioSessionInterruptionListener, (__bridge void *)(self));
//
//    UInt32 propertySize = sizeof(CFStringRef);
//    CFStringRef route;
//    AudioSessionGetProperty(kAudioSessionProperty_AudioRoute, &propertySize, &route);
//    _audioRoute = CFBridgingRelease(route);
//
//    //Setup Audio Session
//    UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
//    AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(sessionCategory), &sessionCategory);
//
//    AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange,
//                                    MRSessionPropertyListener,
//                                    (__bridge void*)(self));
//
//    AudioSessionAddPropertyListener(kAudioSessionProperty_CurrentHardwareOutputVolume,
//                                    MRSessionPropertyListener,
//                                    (__bridge void*)(self));
//
//#if !TARGET_IPHONE_SIMULATOR
//    Float32 preferredBufferSize = 0.0232;
//    AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareIOBufferDuration,
//                            sizeof(preferredBufferSize),
//                            &preferredBufferSize);
//#endif
//
//    AudioSessionSetActive(YES);
//
//    {
//        // Check the number of output channels.
//        UInt32 newNumChannels;
//        UInt32 size = sizeof(newNumChannels);
//
//        AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareOutputNumberChannels,
//                                &size,
//                                &newNumChannels);
//        // Get the hardware sampling rate. This is settable, but here we're only reading.
//        size = sizeof(_samplingRate);
//        AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate,
//                                &size,
//                                &_samplingRate);
//        size = sizeof(_outputVolume);
//        AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareOutputVolume,
//                                &size,
//                                &_outputVolume);
//    }
//
//    {
//        // ----- Audio Unit Setup -----
//
//        // Describe the output unit.
//
//        AudioComponentDescription desc = {0};
//        desc.componentType = kAudioUnitType_Output;
//        desc.componentSubType = kAudioUnitSubType_RemoteIO;
//        desc.componentManufacturer = kAudioUnitManufacturer_Apple;
//
//        // Get component
//        AudioComponent component = AudioComponentFindNext(NULL, &desc);
//        AudioComponentInstanceNew(component, &_audioUnit);
//        UInt32 size;
//
//        // Check the output stream format
//        size = sizeof(AudioStreamBasicDescription);
//
//        AudioUnitGetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &_outputFormat, &size);
//        _outputFormat.mSampleRate = _samplingRate;
//
//        AudioUnitSetProperty(_audioUnit,
//                             kAudioUnitProperty_StreamFormat,
//                             kAudioUnitScope_Input,
//                             0,
//                             &_outputFormat, size);
//
//        _numBytesPerSample = _outputFormat.mBitsPerChannel / 8;
//        _numOutputChannels  = _outputFormat.mChannelsPerFrame;
//
//        // Slap a render callback on the unit
//        AURenderCallbackStruct callbackStruct;
//        callbackStruct.inputProc = MRRenderCallback;
//        callbackStruct.inputProcRefCon = (__bridge void *)(self);
//
//        AudioUnitSetProperty(_audioUnit,
//                             kAudioUnitProperty_SetRenderCallback,
//                             kAudioUnitScope_Input,
//                             0,
//                             &callbackStruct,
//                             sizeof(callbackStruct));
//
//        AudioUnitInitialize(_audioUnit);
//    }
//}

- (BOOL)audioCodecIsSupported:(AVCodecContext *)audio
{
    if (audio->sample_fmt == AV_SAMPLE_FMT_S16) {
        
        return  (int)_samplingRate == audio->sample_rate &&
        _numOutputChannels == audio->channels;
    }
    return NO;
}

- (void)fetchData:(float *)outData numFrames:(UInt32) numFrames numChannels:(UInt32) numChannels
{
    @autoreleasepool {
        
        while (numFrames > 0) {
            
            if (!_currentAudioFrame) {
                
                @synchronized(_audioFrames) {
                    
                    NSUInteger count = _audioFrames.count;
                    
                    if (count > 0) {
                        
                        MRAudioFrame *audioFrame = _audioFrames[0];
                        
                        [_audioFrames removeObjectAtIndex:0];
                        
                        _currentAudioFrame = audioFrame;
                        _currentAudioFramePos = 0;
                    }
                }
            }
            
            if (_currentAudioFrame) {
                
                NSData *samples = _currentAudioFrame.samples;
                const void *from = (Byte *)samples.bytes + _currentAudioFramePos;
                const NSUInteger bytesLeft = (samples.length - _currentAudioFramePos);
                const NSUInteger frameSizeOf = numChannels * sizeof(float);
                const NSUInteger bytesToCopy = MIN(numFrames * frameSizeOf, bytesLeft);
                const NSUInteger framesToCopy = bytesToCopy / frameSizeOf;
                
                memcpy(outData, from, bytesToCopy);
                numFrames -= framesToCopy;
                outData += framesToCopy * numChannels;
                
                if (bytesToCopy < bytesLeft){
                    _currentAudioFramePos += bytesToCopy;
                }else{
                    _currentAudioFrame = nil;
                    _currentAudioFramePos = 0;
                }
            } else {
                
                memset(outData, 0, numFrames * numChannels * sizeof(float));
                //LoggerStream(1, @"silence audio");
                break;
            }
        }
    }
}

- (bool) renderFrames: (UInt32) numFrames
               ioData: (AudioBufferList *) ioData
{
    //   1. 将buffer数组全部置为0；清理现场
    for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
        memset(ioData->mBuffers[iBuffer].mData, 0, ioData->mBuffers[iBuffer].mDataByteSize);
    }
    //获取需要render的data；
    [self fetchData:_outData numFrames:numFrames numChannels:_numOutputChannels];
    
    // Put the rendered data into the output buffer
    if (_numBytesPerSample == 4) // then we've already got floats
    {
        float zero = 0.0;
        
        for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
            
            int thisNumChannels = ioData->mBuffers[iBuffer].mNumberChannels;
            
            for (int iChannel = 0; iChannel < thisNumChannels; ++iChannel) {
                vDSP_vsadd(_outData+iChannel, _numOutputChannels, &zero, (float *)ioData->mBuffers[iBuffer].mData, thisNumChannels, numFrames);
            }
        }
    }
    else if (_numBytesPerSample == 2) // then we need to convert SInt16 -> Float (and also scale)
    {
        
        float scale = (float)INT16_MAX;
        //            加速的，叠加算法；
        //        https://developer.apple.com/library/ios/documentation/Performance/Conceptual/vDSP_Programming_Guide/About_vDSP/About_vDSP.html#//apple_ref/doc/uid/TP40005147-CH201-SW1
        
        vDSP_vsmul(_outData, 1, &scale, _outData, 1, numFrames*_numOutputChannels);
        
        for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
            
            int thisNumChannels = ioData->mBuffers[iBuffer].mNumberChannels;
            
            for (int iChannel = 0; iChannel < thisNumChannels; ++iChannel) {
                vDSP_vfix16(_outData+iChannel, _numOutputChannels, (SInt16 *)ioData->mBuffers[iBuffer].mData+iChannel, thisNumChannels, numFrames);
            }
        }
        
    }
    
    return noErr;
}

- (void)decodeAudioPacket:(AVPacket *)packet
{
    int pktSize = (*packet).size;
    
    AVFrame *audio_Frame = av_frame_alloc();//老版本是 avcodec_alloc_frame
    
    while (pktSize > 0) {
        
        int gotframe = 0;
        int len = avcodec_decode_audio4(_audioCodecCtx,
                                        audio_Frame,
                                        &gotframe,
                                        packet);
        
        if (len < 0) {
            NSLog(@"decode audio error, skip packet");
            break;
        }
        
        if (gotframe) {
            
            MRAudioFrame *frame = [self handleAudioFrame:audio_Frame];
            if (frame) {
                
                @synchronized(_audioFrames) {
                    
                    [_audioFrames addObject:frame];
                    
                    NSLog(@"audio buffer frame:%d",[_audioFrames count]);
                    
                    if ([_audioFrames count] > 10) {
                        [self playAudio];
                    }else{
                        [self pauseAudio];
                    }
                }
            }
        }
        
        if (0 == len)
            break;
        
        pktSize -= len;
    }
    
    av_frame_free(&audio_Frame);
    audio_Frame = NULL;
}

- (MRAudioFrame *)handleAudioFrame:(AVFrame *)audio_Frame
{
    if (!audio_Frame->data[0])
        return nil;
    
    const NSUInteger numChannels = _numOutputChannels;
    NSInteger numFrames = 0;
    
    void * audioData;
    
    if (_swrContext) {
        
        const NSUInteger ratio = MAX(1, _samplingRate / _audioCodecCtx->sample_rate) *
        MAX(1, _numOutputChannels / _audioCodecCtx->channels) * 2;
        
        const int bufSize = av_samples_get_buffer_size(NULL,
                                                       _numOutputChannels,
                                                       audio_Frame->nb_samples * ratio,
                                                       AV_SAMPLE_FMT_S16,
                                                       1);
        
        if (!_swrBuffer || _swrBufferSize < bufSize) {
            _swrBufferSize = bufSize;
            _swrBuffer = realloc(_swrBuffer, _swrBufferSize);
        }
        
        Byte *outbuf[2] = { _swrBuffer, 0 };
        
        numFrames = swr_convert(_swrContext,
                                outbuf,
                                audio_Frame->nb_samples * ratio,
                                (const uint8_t **)audio_Frame->data,
                                audio_Frame->nb_samples);
        
        if (numFrames < 0) {
            NSLog(@"fail resample audio");
            return nil;
        }
        
        //int64_t delay = swr_get_delay(_swrContext, audioManager.samplingRate);
        //if (delay > 0)
        //    LoggerAudio(0, @"resample delay %lld", delay);
        
        audioData = _swrBuffer;
        
    } else {
        
        if (_audioCodecCtx->sample_fmt != AV_SAMPLE_FMT_S16) {
            NSAssert(false, @"bucheck, audio format is invalid");
            return nil;
        }
        
        audioData = audio_Frame->data[0];
        numFrames = audio_Frame->nb_samples;
    }
    
    const NSUInteger numElements = numFrames * numChannels;
    NSMutableData *data = [NSMutableData dataWithLength:numElements * sizeof(float)];
    
    float scale = 1.0 / (float)INT16_MAX ;
    vDSP_vflt16((SInt16 *)audioData, 1, data.mutableBytes, 1, numElements);
    vDSP_vsmul(data.mutableBytes, 1, &scale, data.mutableBytes, 1, numElements);
    
    MRAudioFrame *frame = [MRAudioFrame new];
    
    frame.position = av_frame_get_best_effort_timestamp(audio_Frame) * _audioTimeBase;
    frame.duration = av_frame_get_pkt_duration(audio_Frame) * _audioTimeBase;
    frame.samples = [data copy];
    
    if (frame.duration == 0) {
        // sometimes ffmpeg can't determine the duration of audio frame
        // especially of wma/wmv format
        // so in this case must compute duration
        frame.duration = frame.samples.length / (sizeof(float) * numChannels * _samplingRate);
    }
    
    return frame;
}

# pragma mark - 播放速度控制

- (void)tick
{
    //如果没有缓冲好，那么就每隔0.1s过来看下buffer
    if ([self.audioFrames count] < 3) {
        _weakSelf_SL
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            _strongSelf_SL
            [self tick];
        });
        return;
    }
    MRAudioFrame *frame = [self.audioFrames firstObject];
    float interval = frame.duration;
    
    _currentPlayPosition = frame.position;
    
    ///设置下标志位，音频那边就可以取数据了；
    self.canGiveFrame = YES;
    [[MRAudioManager audioManager]play];
    const NSTimeInterval time = MAX(interval, 0.01);
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, time * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self tick];
    });
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end

