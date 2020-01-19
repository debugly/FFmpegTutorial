//
//  ViewController.m
//  FFmpeg008
//
//  Created by Matt Reach on 2019/2/8.
//  Copyright © 2019年 Awesome FFmpeg Study Demo. All rights reserved.
//  开源地址: https://github.com/debugly/StudyFFmpeg

#import "ViewController.h"
#import <libavutil/log.h>
#import <libavformat/avformat.h>
#import <libavcodec/avcodec.h>
#import <libavutil/pixdesc.h>
#import <libavutil/samplefmt.h>
#import <libavutil/opt.h>
#import <libavutil/imgutils.h>
#import <libswscale/swscale.h>

#import "MRVideoFrame.h"
#import "MRPacketQueue.h"
#import "MRConvertUtil.h"
#import "MRVideoRenderView.h"

#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import "MRAudioFrame.h"
#import <libswresample/swresample.h>

#ifndef __weakSelf__
#define __weakSelf__     __weak   __typeof(self) $weakself = self;
#endif

#ifndef __strongSelf__
#define __strongSelf__   __strong __typeof($weakself) self = $weakself;
#endif

// 按照fps=24计算，缓存20s的视频包；缓存1s的解码帧;
static int kVideoPacketCacheCount = 24 * 20;
static int kVidoFrameCacheCount = 24 * 2;
// 按照每个声道包含1024个采样点，44.1KHz采样率计算，1s 需要 44100/1024 = 43个包; 缓存20s的视频包；缓存1s的解码帧;
static int kAudioPacketCacheCount = 43 * 20;
static int kAudioFrameCacheCount = 43 * 2;
/*
 音频包和视频包不是均匀的，所以读包线程会在把视频和音频包buffer都读满后停止；
 停止后可能音频包缓存数据已经大于设定的最大值了；
 也可能视频包缓存数据已经大于设定的最大值了；
 */

//缓存多久才能播？避免缓存一帧卡一帧的情况
static float kVideoMinBufferDuration = 1;
static float kAudioMinBufferDuration = 1;

const int  kMax_Frame_Size = 1024;
const int  kAudio_Channel = 2;
const int  kAudio_Frame_Buffer_Size = kMax_Frame_Size * kAudio_Channel;


#define USE_PIXEL_BUFFER_POLL 1

#define QUEUE_BUFFER_SIZE 3
#define MIN_SIZE_PER_FRAME 4096

//将音频裸流PCM写入到文件
#define DEBUG_RECORD_PCM_TO_FILE 1
    
@interface ViewController ()
{
    AudioQueueBufferRef audioQueueBuffers[QUEUE_BUFFER_SIZE];
    #if DEBUG_RECORD_PCM_TO_FILE
        FILE * file_pcm;
    #endif

}

@property (weak, nonatomic) UIActivityIndicatorView *indicatorView;

//解封装上下文
@property (assign, nonatomic) AVFormatContext *formatCtx;
//读包队列
@property (strong, nonatomic) dispatch_queue_t read_queue;
@property (nonatomic,assign,getter=isReading) BOOL reading;
//视频解码队列
@property (strong, nonatomic) dispatch_queue_t decode_queue_v;
@property (nonatomic,assign,getter=isDecoding_v) BOOL decoding_v;
//音频解码队列
@property (strong, nonatomic) dispatch_queue_t decode_queue_a;
@property (nonatomic,assign,getter=isDecoding_a) BOOL decoding_a;
//视频解码上下文
@property (nonatomic,assign) AVCodecContext *videoCodecCtx;
//音频解码上下文
@property (nonatomic,assign) AVCodecContext *audioCodecCtx;
//视频(未解码)包缓存
@property (nonatomic,assign) MRPacketQueue videoPacketQueue;
//音频(未解码)包缓存
@property (nonatomic,assign) MRPacketQueue audioPacketQueue;
//视频(已解码)帧缓存
@property (nonatomic,strong) NSMutableArray <MRVideoFrame *> *videoFrames;
//视频帧缓存装满标志位
@property (nonatomic,assign) BOOL videoBufferOk;
//音频(已解码)帧缓存
@property (strong, nonatomic) NSMutableArray<MRAudioFrame *> *audioFrames;
//音频帧缓存装满标志位
@property (nonatomic,assign) BOOL audioBufferOk;
//视频流索引
@property (nonatomic,assign) int stream_index_video;
//音频流索引
@property (nonatomic,assign) int stream_index_audio;
//视频时钟基
@property (nonatomic,assign) float videoTimeBase;
//音频时钟基
@property (nonatomic,assign) float audioTimeBase;
//读包到结束标志位
@property (nonatomic,assign) BOOL eof;
///画面原始宽高，单位像素
@property (nonatomic,assign) int vwidth;
@property (nonatomic,assign) int vheight;
///ffmpeg解码后会做字节对齐，这个是对齐后的画面宽度，单位像素
@property (nonatomic,assign) int aligned_width;
//视频目标像素格式
@property (nonatomic,assign) enum AVPixelFormat target_pix_fmt;
//音频采样格式
@property (nonatomic,assign) enum AVSampleFormat target_sample_fmt;
//图像格式转换
@property (nonatomic,assign) struct SwsContext * img_convert_ctx;
@property (nonatomic,assign) AVFrame *targetVideoFrame;
@property (nonatomic,assign) uint8_t *targetVideoFrameBuffer;
//图像渲染view
@property (strong, nonatomic) MRVideoRenderView *renderView;
//PixelBuffer池可提升效率
@property (assign, nonatomic) CVPixelBufferPoolRef pixelBufferPool;
//采样率
@property (nonatomic,assign) double targetSampleRate;
//声音大小
@property (nonatomic,assign) float outputVolume;
//音频播放器
@property (nonatomic,assign) AudioQueueRef audioQueue;
//音频信息结构体
@property (nonatomic,assign) AudioStreamBasicDescription outputFormat;
//当前音频帧
@property (nonatomic,strong) MRAudioFrame *currentAudioFrame;
//音频重采样上下文
@property (nonatomic,assign) SwrContext  *audio_convert_ctx;
@property (nonatomic,assign) uint8_t     *audioBuffer4Packet;
@property (nonatomic,assign) NSUInteger  audioBuffer4PacketSize;
//AudioQueue 是否开始
@property (nonatomic,assign) BOOL isPalying;

@end

@implementation ViewController

static void fflog(void *context, int level, const char *format, va_list args){
    if (level > AV_LOG_TRACE){
        return;
    } else {
        NSString* message = [[NSString alloc] initWithFormat: [NSString stringWithUTF8String: format] arguments: args];
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_LOW, 0), ^{
            NSLog(@"ffmpeg:[%d]%@",level,message);
        });
    }
}

- (void)dealloc
{
    if (self.formatCtx) {
        AVFormatContext *formatCtx = self.formatCtx;
        avformat_close_input(&formatCtx);
        self.formatCtx = NULL;
    }
    
    if (self.videoCodecCtx){
        avcodec_close(self.videoCodecCtx);
        self.videoCodecCtx = NULL;
    }
    
    if (self.img_convert_ctx) {
        sws_freeContext(self.img_convert_ctx);
    }
    
    if (self.targetVideoFrame) {
        av_frame_free(&self->_targetVideoFrame);
    }
    
    if(self.targetVideoFrameBuffer){
        av_free(self.targetVideoFrameBuffer);
        self.targetVideoFrameBuffer = NULL;
    }
    
    if (self.pixelBufferPool){
        CVPixelBufferPoolRelease(self.pixelBufferPool);
        self.pixelBufferPool = NULL;
    }
    
    if (self.audioCodecCtx) {
        avcodec_close(self.audioCodecCtx);
        self.audioCodecCtx = NULL;
    }
    
    if (self.audio_convert_ctx){
        swr_free(&_audio_convert_ctx);
    }
    
    if(_audioQueue){
        AudioQueueDispose(_audioQueue, YES);
        _audioQueue = NULL;
    }
    
    if (_audioBuffer4Packet) {
        free(_audioBuffer4Packet);
    }
}

# pragma mark - Movie Play Path

- (NSString *)moviePath
{
    NSString *moviePath = nil;//[[NSBundle mainBundle]pathForResource:@"test" ofType:@"mp4"];
    ///该地址可以是网络的也可以是本地的；
    
    NSString *host = @"debugly.cn";
//    host = @"192.168.3.2";
//    host = @"10.7.36.50:8080";
    host = @"localhost";
    
    NSArray *movies = @[@"repository/test.mp4",
                        @"ffmpeg-test/4K2160p.120fps.mkv",
                        @"ffmpeg-test/test.mp4",
                        @"ffmpeg-test/sintel.mp4",
                        @"ffmpeg-test/xp5.mp4",
                        @"ffmpeg-test/IMG_2879.mp4",
                        @"ffmpeg-test/IMG_2899.mp4",
                        @"ffmpeg-test/IMG_2914.mp4",
                        @"ffmpeg-test/IMG_3046.mov",
                        @"ffmpeg-test/IMG_3123.mov",
                        @"ffmpeg-test/IMG_3149.mov",
                        @"ffmpeg-test/IMG_3190.mp4",
                        @"ffmpeg-test/Opera.480p.x264.AAC.mp4"
                        ];
    NSString *movieName = [movies objectAtIndex:4];
    moviePath = [NSString stringWithFormat:@"http://%@/%@",host,movieName];
    return moviePath;
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
    _stream_index_audio = -1;
    
    _videoFrames = [NSMutableArray array];
    _audioFrames = [NSMutableArray array];
    
    //自定义日志输出，默认是 av_log_default_callback
    av_log_set_callback(fflog);
    av_log_set_flags(AV_LOG_SKIP_REPEATED);
    av_log_set_level(AV_LOG_TRACE);//只对av_log_default_callback有效
    printf("av_log_get_level:%d\n",av_log_get_level());
    
    ///初始化libavformat，注册所有文件格式，编解码库；这不是必须的，如果你能确定需要打开什么格式的文件，使用哪种编解码类型，也可以单独注册！
    av_register_all();
    
    NSString * moviePath = [self moviePath];
    
    static bool has_init_network = false;
    
    if ([moviePath hasPrefix:@"http"] && !has_init_network) {
        //Using network protocols without global network initialization. Please use avformat_network_init(), this will become mandatory later.
        //播放网络视频的时候，要首先初始化下网络模块。
        avformat_network_init();
        has_init_network = true;
    }
    #if DEBUG_RECORD_PCM_TO_FILE
    if (file_pcm == NULL) {
        const char *l = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"Packet.pcm"]UTF8String];
        NSLog(@"file_pcm:%s",l);
        file_pcm = fopen(l, "wb+");
    }
    #endif
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
                
                if (succ) {
                    
                    // 打开音频流
                    succ = [self openAudioStream];
                    
                    if (succ) {
                        dispatch_async(dispatch_get_main_queue(), ^{
                        
                            [self setUPAudioAndVideo];
                            // 启动视频渲染驱动
                            [self videoTick];
                            // 启动音频渲染驱动
                            [self audioTick];
                        });
                    } else {
                        NSLog(@"不支持的音频类型！");
                        dispatch_async(dispatch_get_main_queue(), ^{
                            [indicatorView stopAnimating];
                        });
                    }
                } else {
                    NSLog(@"不支持的视频类型！");
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [indicatorView stopAnimating];
                    });
                }
            } else {
                NSLog(@"不能打开流");
                dispatch_async(dispatch_get_main_queue(), ^{
                    [indicatorView stopAnimating];
                });
            }
        }];
    });
}

- (BOOL)audioCodecIsSupported:(AVCodecContext *)audio
{
    if (audio->sample_fmt == self.target_sample_fmt) {
        return  (int)self.targetSampleRate == audio->sample_rate &&
        (int)self.outputFormat.mChannelsPerFrame == audio->channels;
    }
    return NO;
}

- (void)setUPAudioAndVideo
{
    // 渲染Layer
    if(!self.renderView){
        self.renderView = [[MRVideoRenderView alloc] init];
        self.renderView.frame = self.view.bounds;
        self.renderView.contentMode = UIViewContentModeScaleAspectFit;
        self.renderView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        [self.view addSubview:self.renderView];
    }
    
    self.target_pix_fmt = AV_PIX_FMT_NV12;
    ///defaut: natural aligment
    self.aligned_width = self.vwidth;
    //需要格式转换
    if (self.videoCodecCtx->pix_fmt != self.target_pix_fmt) {
        self.img_convert_ctx = sws_getContext(self.vwidth, self.vheight, self.videoCodecCtx->pix_fmt, self.vwidth, self.vheight, self.target_pix_fmt, SWS_BICUBIC, NULL, NULL, NULL);
        self.targetVideoFrame = av_frame_alloc();
        const int picSize = av_image_get_buffer_size(self.target_pix_fmt, self.aligned_width, self.vheight, 1);
        self.targetVideoFrameBuffer = av_malloc(picSize*sizeof(uint8_t));
        avpicture_fill((AVPicture *)self.targetVideoFrame, self.targetVideoFrameBuffer, self.target_pix_fmt, self.aligned_width, self.vheight);
    }

    _targetSampleRate = [[AVAudioSession sharedInstance]sampleRate];
    _outputVolume = [[AVAudioSession sharedInstance]outputVolume];
    
    {
        [[AVAudioSession sharedInstance]setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker error:nil];
        //        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(audioRouteChanged:) name:AVAudioSessionRouteChangeNotification object:nil];
        //        [[AVAudioSession sharedInstance]addObserver:self forKeyPath:@"outputVolume" options:NSKeyValueObservingOptionNew context:nil];
        
        [[AVAudioSession sharedInstance]setActive:YES error:nil];
    }
    
    {
        // ----- Audio Queue Setup -----
    
        _outputFormat.mSampleRate = _targetSampleRate;
        /**不使用视频的原声道数_audioCodecCtx->channels;
         mChannelsPerFrame 这个值决定了后续AudioUnit索要数据时 ioData->mNumberBuffers 的值！
         如果写成1会影响Planar类型，就不会开两个buffer了！！因此这里写死为2！
         */
        _outputFormat.mChannelsPerFrame = 2;
        _outputFormat.mFormatID = kAudioFormatLinearPCM;
        _outputFormat.mReserved = 0;
        
        bool isFloat = _audioCodecCtx->sample_fmt == AV_SAMPLE_FMT_FLT || _audioCodecCtx->sample_fmt == AV_SAMPLE_FMT_FLTP;
        bool isS16 = _audioCodecCtx->sample_fmt == AV_SAMPLE_FMT_S16 || _audioCodecCtx->sample_fmt == AV_SAMPLE_FMT_S16P;
    
        // 测试目标输出: S16
//                isFloat = false; isS16 = true;
        // 测试目标输出: FLOAT
//                isFloat = true; isS16 = false;
        
        if (!isS16 && !isFloat){
            isFloat = false;
            isS16 = YES;
            NSLog(@"其他格式，默认重采样为S16！");
        }
        
        if (isS16){
            _outputFormat.mFormatFlags |= kAudioFormatFlagIsSignedInteger;
            _outputFormat.mFramesPerPacket = 1;
            _outputFormat.mBitsPerChannel = sizeof(SInt16) * 8;
            self.target_sample_fmt = AV_SAMPLE_FMT_S16;
        } else if (isFloat){
            _outputFormat.mFormatFlags = kAudioFormatFlagIsFloat;
            _outputFormat.mFramesPerPacket = 1;
            _outputFormat.mBitsPerChannel = sizeof(float) * 8;
            self.target_sample_fmt = AV_SAMPLE_FMT_FLT;
        }
        
        //packed only!
        _outputFormat.mFormatFlags |= kAudioFormatFlagIsPacked;
        _outputFormat.mBytesPerFrame = (_outputFormat.mBitsPerChannel / 8) * _outputFormat.mChannelsPerFrame;
        _outputFormat.mBytesPerPacket = _outputFormat.mBytesPerFrame * _outputFormat.mFramesPerPacket;
        
        OSStatus status = AudioQueueNewOutput(&self->_outputFormat, MRAudioQueueOutputCallback, (__bridge void *)self, CFRunLoopGetCurrent(), kCFRunLoopCommonModes, 0, &self->_audioQueue);
        
        NSAssert(noErr == status, @"AudioQueueNewOutput");
        
        // //初始化音频缓冲区--audioQueueBuffers为结构体数组
        for(int i = 0; i < QUEUE_BUFFER_SIZE;i++){
            int result = AudioQueueAllocateBuffer(self.audioQueue,MIN_SIZE_PER_FRAME, &self->audioQueueBuffers[i]);
            NSAssert(noErr == result, @"AudioQueueAllocateBuffer");
        }
    }
    
    if (![self audioCodecIsSupported:_audioCodecCtx]) {
        
        int64_t dst_ch_layout = av_get_default_channel_layout((int)self.outputFormat.mChannelsPerFrame);
        int64_t src_ch_layout = av_get_default_channel_layout(_audioCodecCtx->channels);
        
        int src_rate = _audioCodecCtx->sample_rate;
        enum AVSampleFormat src_sample_fmt = _audioCodecCtx->sample_fmt;
        
        enum AVSampleFormat dst_sample_fmt = self.target_sample_fmt;
        int dst_rate = _targetSampleRate;
        
        /* create resampler context */
        SwrContext *swr_ctx = swr_alloc();
        
        /* set options */
        av_opt_set_int(swr_ctx, "in_channel_layout",    src_ch_layout, 0);
        av_opt_set_int(swr_ctx, "in_sample_rate",       src_rate, 0);
        av_opt_set_sample_fmt(swr_ctx, "in_sample_fmt", src_sample_fmt, 0);
        
        av_opt_set_int(swr_ctx, "out_channel_layout",    dst_ch_layout, 0);
        av_opt_set_int(swr_ctx, "out_sample_rate",       dst_rate, 0);
        av_opt_set_sample_fmt(swr_ctx, "out_sample_fmt", dst_sample_fmt, 0);
        
//        SwrContext *swr_ctx = swr_alloc_set_opts(NULL,
//                                                 dst_ch_layout,dst_sample_fmt,dst_rate,
//                                                 src_ch_layout,src_sample_fmt,src_rate,
//                                                 0,
//                                                 NULL);
        
        swr_init(swr_ctx);
        self.audio_convert_ctx = swr_ctx;
    }
}

#pragma mark 检查缓存

- (BOOL)checkVideoBufferOK
{
    float buffedDuration = 0.0;
    //如果没有缓冲好，那么就每隔1s过来看下buffer
    for (MRVideoFrame *frame in self.videoFrames) {
        buffedDuration += frame.duration;
        if (buffedDuration >= kVideoMinBufferDuration) {
            break;
        }
    }
    
    return buffedDuration >= kVideoMinBufferDuration;
}

- (BOOL)checkAudioBufferOK
{
    float buffedDuration = 0.0;
    //如果没有缓冲好，那么就每隔1s过来看下buffer
    @synchronized(self) {
        for (MRAudioFrame *frame in self.audioFrames) {
            buffedDuration += frame.duration;
            if (buffedDuration >= kAudioMinBufferDuration) {
                break;
            }
        }
    }
    return buffedDuration >= kAudioMinBufferDuration;
}

- (bool)checkVideoPacketFull
{
    @synchronized(self) {
        
        int count = self.videoPacketQueue.nb_packets;
        
        if (count < kVideoPacketCacheCount){
            return false;
        }
        
        return true;
    }
}

- (bool)checkAudioPacketFull
{
    @synchronized(self) {
        
        int count = self.audioPacketQueue.nb_packets;
        
        if (count < kAudioPacketCacheCount){
            return false;
        }
        
        return true;
    }
}

- (bool)checkVideoFrameFull
{
    @synchronized(self) {
    
        NSUInteger count = [self.videoFrames count];
        NSLog(@"video frame:%lu",count);
        if (count < kVidoFrameCacheCount) {
            return false;
        } else {
            return true;
        }
    }
}

- (bool)checkAudioFrameFull
{
    @synchronized(self) {
        
        NSUInteger count = [self.audioFrames count];
        NSLog(@"audio frame:%lu",count);
        if (count < kAudioFrameCacheCount) {
            return false;
        } else {
            return true;
        }
    }
}

#pragma mark - 渲染驱动

- (void)videoTick
{
    if(self.eof){
        //包读完了，没有需要解码的包，处于不可播放状态时，强制改变为可播放
        if (!self.videoBufferOk && self.audioPacketQueue.nb_packets == 0) {
            //避免剩下几帧没播玩，除非 kVideoMinBufferDuration = 0
            self.videoBufferOk = YES;
        }
    }
    
    if (self.videoBufferOk) {
        
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
            [self.renderView cleanScreen];
            [_indicatorView stopAnimating];
            NSLog(@"视频播放结束");
            #if DEBUG_RECORD_PCM_TO_FILE
                fclose(file_pcm);
            #endif
        }else{
            NSLog(@"loading");
            ///播放势必要消耗帧，所以检查下是否需要解码更多帧
            [self notifiDecodeVideo];
            
            self.videoBufferOk = NO;
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
    [self.renderView enqueueSampleBuffer:frame.sampleBuffer];
}

- (void)playAudio
{
    if (!self.isPalying) {
        
        for(int i = 0; i < QUEUE_BUFFER_SIZE;i++){
            AudioQueueBufferRef ref = self->audioQueueBuffers[i];
            [self renderFramesToBuffer:ref];
        }
        
        OSStatus status = AudioQueueStart(self.audioQueue, NULL);
        if(noErr == status){
            self.isPalying = YES;
        }
        NSAssert(noErr == status, @"AudioOutputUnitStart");
    }
}

- (void)pauseAudio
{
    if (self.isPalying) {
        AudioQueueStop(self.audioQueue,YES);
        self.isPalying = NO;
    }
}

- (void)audioTick
{
    if (self.audioBufferOk) {
        [self playAudio];
    }else{
        if (self.eof && self.audioPacketQueue.nb_packets == 0) {
            [self pauseAudio];
        } else {
            [self notifiDecodeAudio];
            __weakSelf__
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                __strongSelf__
                [self audioTick];
            });
        }
    }
}

#pragma mark - 解码线程

- (void)notifiDecodeVideo
{
    bool full = [self checkVideoFrameFull];
    if (!full) {
        [self doDecodeVideoPacketToFrames];
    }
}

- (void)notifiDecodeAudio
{
    bool full = [self checkAudioFrameFull];
    if (!full) {
        [self doDecodeAudioPacketToFrames];
    }
}

- (CMSampleBufferRef)sampleBufferFromAVFrame:(AVFrame*)video_frame w:(int)w h:(int)h
{
#if USE_PIXEL_BUFFER_POLL
    CVReturn theError;
    if (!self.pixelBufferPool){
        int linesize = video_frame->linesize[0];
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
#endif
    
    CVPixelBufferRef pixelBuffer = [MRConvertUtil pixelBufferFromAVFrame:video_frame w:w h:h opt:self.pixelBufferPool];
    
    return [MRConvertUtil cmSampleBufferRefFromCVPixelBufferRef:pixelBuffer];
}

- (void)doDecodeVideoPacketToFrames
{
    if (!self.decode_queue_v) {
        dispatch_queue_t decode_queue = dispatch_queue_create("decode_queue_v", DISPATCH_QUEUE_SERIAL);
        self.decode_queue_v = decode_queue;
    }
    
    if (self.isDecoding_v) {
        return;
    }
    
    self.decoding_v = YES;
    
    __weakSelf__
    dispatch_async(self.decode_queue_v, ^{
        
        __strongSelf__
        
        while (![self checkVideoFrameFull]) {
            
            ///解码
            AVPacket pkt;
            bool ok = false;
            @synchronized(self) {
                ok = mr_packet_queue_get(&self->_videoPacketQueue, &pkt);
            }
            
            NSLog(@"get cache video packet:%@",ok?@"succ":@"failed");
            
            if (ok) {
                AVFrame *video_frame = [self decodeVideoPacket:&pkt];
                av_packet_unref(&pkt);
                NSLog(@"decode video packet:%@",video_frame!=NULL?@"succ":@"failed");
                if (video_frame) {
                    ///对齐宽度与视频宽度不等
                    if (self.aligned_width != video_frame->linesize[0]) {
                        self.aligned_width = video_frame->linesize[0];
                        const int picSize = av_image_get_buffer_size(self.target_pix_fmt, self.aligned_width, self.vheight, 1);
                        self.targetVideoFrameBuffer = av_realloc(self.targetVideoFrameBuffer, picSize*sizeof(uint8_t));
                        
                        
                        if(!self.img_convert_ctx){
                            self.img_convert_ctx = sws_getContext(self.vwidth, self.vheight, self.videoCodecCtx->pix_fmt, self.vwidth, self.vheight, self.target_pix_fmt, SWS_BICUBIC, NULL, NULL, NULL);
                        }
                        
                        if (!self.targetVideoFrame) {
                            self.targetVideoFrame = av_frame_alloc();
                        }
                        
                        avpicture_fill((AVPicture *)self.targetVideoFrame, self.targetVideoFrameBuffer, self.target_pix_fmt, self.aligned_width, self.vheight);
                    }
                    CMSampleBufferRef sampleBuffer = NULL;
                    /// 转换器存在则进行转换操作（根据配置把数据转换成 NV12 或者 RGB24等）
                    if (self.img_convert_ctx) {
                        int pictRet = sws_scale(self.img_convert_ctx, (const uint8_t* const*)video_frame->data, video_frame->linesize, 0, self.vheight, self.targetVideoFrame->data, self.targetVideoFrame->linesize);
                        
                        if (pictRet <= 0) {
                            av_frame_free(&video_frame);
                            return ;
                        }
                        //构造目标渲染buffer
                        sampleBuffer = [self sampleBufferFromAVFrame:self.targetVideoFrame w:self.vwidth h:self.vheight];
                    } else {
                        //构造目标渲染buffer
                        sampleBuffer = [self sampleBufferFromAVFrame:video_frame w:self.vwidth h:self.vheight];
                    }
                    
                    // 获取视频时长
                    const double frameDuration = av_frame_get_pkt_duration(video_frame) * self.videoTimeBase;
                    av_frame_free(&video_frame);
                    // 构造模型
                    MRVideoFrame *frame = [[MRVideoFrame alloc]init];
                    frame.duration = frameDuration;
                    frame.sampleBuffer = sampleBuffer;
                    // 存放到内存
                    @synchronized(self) {
                        [self.videoFrames addObject:frame];
                        if (!self.videoBufferOk) {
                            self.videoBufferOk = [self checkVideoBufferOK];
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
            if ([self checkVideoFrameFull]) {
                NSLog(@"frame cache full");
            }
            self.decoding_v = NO;
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

- (AVFrame *)decodeAudioPacket:(AVPacket *)packet
{
    int gotframe = 0;
    AVFrame *audio_frame = av_frame_alloc();//老版本是 avcodec_alloc_frame
    
    avcodec_decode_audio4(_audioCodecCtx, audio_frame, &gotframe, packet);
    
    if (gotframe <= 0) {
        NSLog(@"decode audio error, skip packet");
        av_frame_free(&audio_frame);
    }
    return audio_frame;
}

- (void)doDecodeAudioPacketToFrames
{
    if (!self.decode_queue_a) {
        dispatch_queue_t decode_queue = dispatch_queue_create("decode_queue_a", DISPATCH_QUEUE_SERIAL);
        self.decode_queue_a = decode_queue;
    }
    
    if (self.isDecoding_a) {
        return;
    }
    
    self.decoding_a = YES;
    
    __weakSelf__
    dispatch_async(self.decode_queue_a, ^{
        
        __strongSelf__
        
        while (![self checkAudioFrameFull]) {
            
            ///解码
            AVPacket pkt;
            bool ok = false;
            @synchronized(self) {
                ok = mr_packet_queue_get(&self->_audioPacketQueue, &pkt);
            }
            
            NSLog(@"get cache audio packet:%@",ok?@"succ":@"failed");
            
            if (ok) {
                AVFrame *audio_frame = [self decodeAudioPacket:&pkt];
                av_packet_unref(&pkt);
                NSLog(@"decode audio packet:%@",audio_frame!=NULL?@"succ":@"failed");
                if (audio_frame) {
                    
                    const int numChannels = (int)self.outputFormat.mChannelsPerFrame;
                    int numFrames = 0;
                    
                    MRAudioFrame *frame = [MRAudioFrame new];
                    
                    //需要重采样
                    if (self.audio_convert_ctx) {
                        
                        int src_nb_samples = audio_frame->nb_samples;
                        int dst_nb_channels = self.outputFormat.mChannelsPerFrame;
                        int dst_rate = (int)self.targetSampleRate;
                        int src_rate = audio_frame->sample_rate;
                        enum AVSampleFormat dst_sample_fmt = self.target_sample_fmt;
                        
                        int max_dst_nb_samples = (int)av_rescale_rnd(src_nb_samples, dst_rate, src_rate, AV_ROUND_UP);
                        
                        const int bufSize = av_samples_get_buffer_size(NULL, dst_nb_channels, max_dst_nb_samples, self.target_sample_fmt, 1);
                        
                        if (!self.audioBuffer4Packet || self.audioBuffer4PacketSize < bufSize) {
                            self.audioBuffer4PacketSize = bufSize;
                            self.audioBuffer4Packet = realloc(self.audioBuffer4Packet, self.audioBuffer4PacketSize);
                        }
                        
                        Byte *outbuf[2] = { self.audioBuffer4Packet, 0 };
                        
                        numFrames = swr_convert(self.audio_convert_ctx,
                                                outbuf,
                                                audio_frame->nb_samples,
                                                (const uint8_t **)audio_frame->data,
                                                audio_frame->nb_samples);
                        
                        if (numFrames < 0) {
                            NSLog(@"fail resample audio");
                            av_frame_free(&audio_frame);
                            break;
                        }
                        
                        int dst_bufsize = av_samples_get_buffer_size(NULL, dst_nb_channels,
                                                                     numFrames, dst_sample_fmt, 1);
                        //                            也可以这么计算得出：
                        //                            const NSUInteger numElements = numFrames * numChannels;
                        //                            UInt32 size4Packet = self.outputFormat.mBitsPerChannel / 8;
                        //                            int dst_bufsize = numElements * size4Packet;
                        
                        NSMutableData *data = [NSMutableData dataWithLength:dst_bufsize];
                        memcpy(data.mutableBytes, self.audioBuffer4Packet, dst_bufsize);
                        frame.samples4packet = [data copy];
                        
                    }
                    /// 不需要重采样
                    else {
                        
                        if (self.audioCodecCtx->sample_fmt != self.target_sample_fmt) {
                            NSAssert(false, @"bucheck, audio format is invalid");
                        }
                        ///FLOT or S16
                        int data_size = audio_frame->linesize[0];
                        uint8_t *pcmData = audio_frame->data[0];
                        NSMutableData *data = [NSMutableData dataWithLength:data_size];
                        memcpy(data.mutableBytes, pcmData, data_size);
                        frame.samples4packet = [data copy];
                    }
                    
                    frame.position = av_frame_get_best_effort_timestamp(audio_frame) * self.audioTimeBase;
                    frame.duration = av_frame_get_pkt_duration(audio_frame) * self.audioTimeBase;

                    if (frame.duration == 0) {
                        // sometimes ffmpeg can't determine the duration of audio frame
                        // especially of wma/wmv format
                        // so in this case must compute duration
                        frame.duration = frame.samples4packet.length / (sizeof(float) * numChannels * self.targetSampleRate);
                    }
                    
                    av_frame_free(&audio_frame);
                    
                    // 存放到内存
                    @synchronized(self) {
                        [self.audioFrames addObject:frame];
                        if (!self.audioBufferOk) {
                            self.audioBufferOk = [self checkAudioBufferOK];
                            NSLog(@"audioBufferOk?%d",self.audioBufferOk);
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
            if ([self checkAudioFrameFull]) {
                NSLog(@"audio frame cache full");
            }
            self.decoding_a = NO;
        });
    });
}
#pragma mark - 读包线程

- (void)cacheVideoPacket:(AVPacket *)packet
{
    @synchronized(self) {
        mr_packet_queue_put(&self->_videoPacketQueue, packet);
        NSLog(@"==cache video packet:%d",self.videoPacketQueue.nb_packets);
    }
}

- (void)cacheAudioPacket:(AVPacket *)packet
{
    @synchronized(self) {
        mr_packet_queue_put(&self->_audioPacketQueue, packet);
        NSLog(@"==cache audio packet:%d",self.audioPacketQueue.nb_packets);
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
        while (![self checkVideoPacketFull] || ![self checkAudioPacketFull]) {
            NSLog(@"read packet");
            AVPacket pkt1, *pkt = &pkt1;
            __strongSelf__
            // 读包
            if (av_read_frame(self->_formatCtx,pkt) >= 0) {
                ///处理视频流
                if (pkt1.stream_index == self.stream_index_video) {
                    [self cacheVideoPacket:pkt];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self notifiDecodeVideo];
                    });
                } else if(pkt1.stream_index == self.stream_index_audio){
                    [self cacheAudioPacket:pkt];
                    dispatch_async(dispatch_get_main_queue(), ^{
                        [self notifiDecodeAudio];
                    });
                }
                else {
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
    return [self doOpenVideoStream:stream];
}

- (BOOL)doOpenVideoStream:(AVStream *)stream
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
    
    ///画面宽度，单位像素
    self.vwidth = codecCtx->width;
    ///画面高度，单位像素
    self.vheight = codecCtx->height;
    
    float fps = 0;
    avStreamFPSTimeBase(stream, 0.04, &fps, &_videoTimeBase);
    return YES;
}

- (BOOL)openAudioStream
{
    AVStream *stream = _formatCtx->streams[_stream_index_audio];
    return [self doOpenAudioStream:stream];
}

- (BOOL)doOpenAudioStream:(AVStream *)stream
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
    
    _audioCodecCtx = codecCtx;
    
    avStreamFPSTimeBase(stream, 0.025, 0, &_audioTimeBase);
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
#ifdef DEBUG
            av_dump_format(formatCtx, 0, [moviePath.lastPathComponent cStringUsingEncoding: NSUTF8StringEncoding], 0);
#endif
            /*AVFormatContext 的 streams 变量是个数组，里面存放了 nb_streams 个元素，每个元素都是一个 AVStream */
 
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
                    ///音频流
                    case AVMEDIA_TYPE_AUDIO:
                    {
                        _stream_index_audio = i;
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

#pragma mark - 音频

///音频渲染回调；

static void MRAudioQueueOutputCallback(
                                 void * __nullable       inUserData,
                                 AudioQueueRef           inAQ,
                                 AudioQueueBufferRef     inBuffer)
{
    ViewController *am = (__bridge ViewController *)inUserData;
    [am renderFramesToBuffer:inBuffer];
}

- (UInt32)renderFramesToBuffer: (AudioQueueBufferRef) inBuffer
{
    //1、填充数据
    UInt32 gotBytes = [self fetchPCMPacketData:inBuffer->mAudioData wantBytes:inBuffer->mAudioDataBytesCapacity];
    inBuffer->mAudioDataByteSize = gotBytes;
    
    #if DEBUG_RECORD_PCM_TO_FILE

    if (gotBytes > 0) {
        fwrite(inBuffer->mAudioData, 1, gotBytes, file_pcm);
    }
    
    #endif
    
    // 2、通知 AudioQueue 有可以播放的 buffer 了
    AudioQueueEnqueueBuffer(self.audioQueue, inBuffer, 0, NULL);
    return gotBytes;
}

- (UInt32)fetchPCMPacketData:(void *)outData wantBytes:(const NSInteger) wantBytes
{
    UInt32 giveBytes = 0;
    @autoreleasepool {
        //没给够
        while (giveBytes < wantBytes) {
            
            if (!_currentAudioFrame) {
                
                @synchronized(self) {
                    
                    NSUInteger count = _audioFrames.count;
                    
                    if (count > 0) {
                        
                        MRAudioFrame *audioFrame = _audioFrames[0];
                        
                        [_audioFrames removeObjectAtIndex:0];
                        
                        _currentAudioFrame = audioFrame;
                        _currentAudioFrame.samplesOffset = 0;
                    }
                }
            }
            
            if (_currentAudioFrame) {
                
                NSData *samples = _currentAudioFrame.samples4packet;
                const void *from = (Byte *)samples.bytes + _currentAudioFrame.samplesOffset;
                NSUInteger bytesLeft = (samples.length - _currentAudioFrame.samplesOffset);
                ///根据剩余数据长度和需要数据长度算出应当copy的长度
                NSUInteger bytesToCopy = MIN(wantBytes - giveBytes, bytesLeft);
                memcpy(outData, from, bytesToCopy);
                giveBytes += bytesToCopy;
                outData = (void *)((char *)outData + bytesToCopy);
                
                if (bytesToCopy < bytesLeft){
                    //剩余的比copy走的多，则修改偏移量
                    _currentAudioFrame.samplesOffset += bytesToCopy;
                }else{
                    //读取完毕，则清空；读取下一个包
                    _currentAudioFrame = nil;
                    _currentAudioFrame.samplesOffset = 0;
                }
                
                __weakSelf__
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strongSelf__
                    [self notifiDecodeAudio];
                });
            } else {
                //没有缓存数据了，就不要读了；
                __weakSelf__
                dispatch_async(dispatch_get_main_queue(), ^{
                    __strongSelf__
                    ///包读完了，也没有需要解码的包，也没有解码帧
                    if (self.eof && self.audioPacketQueue.nb_packets == 0) {
                        NSLog(@"音频播放结束");
                        [self pauseAudio];
                    } else {
                        [self notifiDecodeAudio];
                    }
                });
                break;
            }
        }
    }
    return giveBytes;
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end

/**
 缓存20s的视频包；缓存2s的解码帧;
 
 USE_PIXEL_BUFFER_POLL 0
 
 60fps GPU 10% CPU 35% Memory 67M
 
 USE_PIXEL_BUFFER_POLL 1
 
 60fps GPU 大部分是0%，少数平均（15%） CPU 25% Memory 69M
 
 截止目前表现最好的！
 */

