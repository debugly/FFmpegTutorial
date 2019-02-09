//
//  ViewController.m
//  FFmpeg006
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
#import <libavutil/opt.h>
#import <libswscale/swscale.h>

#import "MRVideoFrame.h"
#import "MRPacketQueue.h"
#import "MRConvertUtil.h"
#import "MRVideoRenderView.h"

#import <AVFoundation/AVFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>
#import <Accelerate/Accelerate.h>
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

const int  kMax_Frame_Size = 4096;
const int  kAudio_Channel = 2;
const int  kAudio_Frame_Buffer_Size = kMax_Frame_Size * kAudio_Channel;


#define USE_PIXEL_BUFFER_POLL 1
//将音频裸流PCM写入到文件
#define DEBUG_RECORD_PCM_TO_FILE 0

@interface ViewController ()
{
#if DEBUG_RECORD_PCM_TO_FILE
    FILE * file_pcm_l;
    FILE * file_pcm_r;
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
@property (nonatomic,assign) enum AVPixelFormat  target_pix_fmt;
//音频采样格式
@property (nonatomic,assign) enum AVSampleFormat target_sample_fmt;
//图像格式转换
@property (nonatomic,assign) uint8_t *out_buffer;
@property (nonatomic,assign) struct SwsContext * img_convert_ctx;
@property (nonatomic,assign) AVFrame *pFrameYUV;
//图像渲染view
@property (strong, nonatomic) MRVideoRenderView *renderView;
//PixelBuffer池可提升效率
@property (assign, nonatomic) CVPixelBufferPoolRef pixelBufferPool;
//采样率
@property (nonatomic,assign) double samplingRate;
//声音大小
@property (nonatomic,assign) float outputVolume;
//音频播放器
@property (nonatomic,assign) AudioUnit audioUnit;
//音频信息结构体
@property (nonatomic,assign) AudioStreamBasicDescription outputFormat;
@property (nonatomic,assign) NSInteger numOutputChannels;
//当前音频帧
@property (nonatomic,strong) MRAudioFrame *currentAudioFrame;
//音频重采样上下文
@property (nonatomic,assign) SwrContext  *audio_convert_ctx;
//音频重采样 packet 格式buffer
@property (nonatomic,assign) uint8_t     *audioBuffer4Packet;
@property (nonatomic,assign) NSUInteger  audioBuffer4PacketSize;
//音频重采样 planar 格式buffer
@property (nonatomic,assign) uint8_t     *audioBuffer4PlanarL;
@property (nonatomic,assign) uint8_t     *audioBuffer4PlanarR;
@property (nonatomic,assign) NSUInteger  audioBuffer4PlanarSize;

//Audio Unit 是否开始
@property (nonatomic,assign) BOOL isPalying;

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
    
    if (self.videoCodecCtx){
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
        av_free(self.out_buffer);
        self.out_buffer = NULL;
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
    
#if DEBUG_RECORD_PCM_TO_FILE
    fclose(file_pcm_l);
    fclose(file_pcm_r);
#endif
    
    if(_audioUnit){
        AudioComponentInstanceDispose(_audioUnit);
        _audioUnit = NULL;
    }
    
    if (_audioBuffer4Packet) {
        free(_audioBuffer4Packet);
    }
    
    if (_audioBuffer4PlanarL) {
        free(_audioBuffer4PlanarL);
        _audioBuffer4PlanarL = NULL;
    }
    
    if (_audioBuffer4PlanarR) {
        free(_audioBuffer4PlanarR);
        _audioBuffer4PlanarR = NULL;
    }
    
}

# pragma mark - Movie Play Path

- (NSString *)moviePath
{
    NSString *moviePath = nil;//[[NSBundle mainBundle]pathForResource:@"test" ofType:@"mp4"];
    ///该地址可以是网络的也可以是本地的；
    
    NSString *host = @"debugly.cn";
    host = @"192.168.3.2";
//    host = @"10.7.36.117:8080";
    
    NSArray *movies = @[@"repository/test.mp4",
                        @"ffmpeg-test/4K2160p.120fps.mkv",
                        @"ffmpeg-test/test.mp4",
                        @"ffmpeg-test/xp5.mp4",
                        @"ffmpeg-test/IMG_2879.mp4",
                        @"ffmpeg-test/IMG_2899.mp4",
                        @"ffmpeg-test/IMG_2914.mp4",
                        @"ffmpeg-test/IMG_3046.mov",
                        @"ffmpeg-test/IMG_3123.mov",
                        @"ffmpeg-test/IMG_3149.mov",
                        @"ffmpeg-test/IMG_3190.mp4",
                        @"ffmpeg-test/Opera.480p.x264.AAC.mp4",
                        @"ffmpeg-test/sintel.mp4",
                        ];
    NSString *movieName = [movies objectAtIndex:2];
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
    
    av_log_set_callback(fflog);//日志比较多，打开日志后会阻塞当前线程
    //av_log_set_flags(AV_LOG_SKIP_REPEATED);
    
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
    
    NSLog(@"load movie:%@",moviePath);
#if DEBUG_RECORD_PCM_TO_FILE
    if (file_pcm_l == NULL) {
        const char *l = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"L.pcm"]UTF8String];
        NSLog(@"%s",l);
        file_pcm_l = fopen(l, "wb+");
    }
    
    if (file_pcm_r == NULL) {
        const char *r = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"R.pcm"]UTF8String];
        file_pcm_r = fopen(r, "wb+");
    }
#endif
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
        return  (int)_samplingRate == audio->sample_rate &&
        _numOutputChannels == audio->channels;
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
    
    self.target_pix_fmt = PIX_FMT_NV12;
    
    self.img_convert_ctx = sws_getContext(self.vwidth, self.vheight, self.videoCodecCtx->pix_fmt, self.vwidth, self.vheight, self.target_pix_fmt, SWS_BICUBIC, NULL, NULL, NULL);
    self.pFrameYUV = av_frame_alloc();
    
    ///defaut: natural aligment
    self.aligned_width = self.vwidth;
    const int picSize = avpicture_get_size(self.target_pix_fmt, self.aligned_width, self.vheight);
    self.out_buffer = av_malloc(picSize*sizeof(uint8_t));
    avpicture_fill((AVPicture *)self.pFrameYUV, self.out_buffer, self.target_pix_fmt, self.aligned_width, self.vheight);
    
    _numOutputChannels = [[AVAudioSession sharedInstance]outputNumberOfChannels];
    _samplingRate = [[AVAudioSession sharedInstance]sampleRate];
    _outputVolume = [[AVAudioSession sharedInstance]outputVolume];
    
    {
        [[AVAudioSession sharedInstance]setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker error:nil];
        //        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(audioRouteChanged:) name:AVAudioSessionRouteChangeNotification object:nil];
        //        [[AVAudioSession sharedInstance]addObserver:self forKeyPath:@"outputVolume" options:NSKeyValueObservingOptionNew context:nil];
        
        [[AVAudioSession sharedInstance]setActive:YES error:nil];
    }
    
    {
        // ----- Audio Unit Setup -----
        
#define kOutputBus 0 //Bus 0 is used for the output side
#define kInputBus  1 //Bus 0 is used for the output side
        
        // Describe the output unit.
        
        AudioComponentDescription desc = {0};
        desc.componentType = kAudioUnitType_Output;
        desc.componentSubType = kAudioUnitSubType_RemoteIO;
        desc.componentManufacturer = kAudioUnitManufacturer_Apple;
        
        // Get component
        AudioComponent component = AudioComponentFindNext(NULL, &desc);
        OSStatus status = AudioComponentInstanceNew(component, &_audioUnit);
        NSAssert(noErr == status, @"AudioComponentInstanceNew");
        
        UInt32 size = sizeof(self.outputFormat);
        /// 获取默认的输入信息
        AudioUnitGetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, kOutputBus, &_outputFormat, &size);
        
        _samplingRate = _audioCodecCtx -> sample_rate;
        _outputFormat.mSampleRate = _samplingRate;
        _outputFormat.mChannelsPerFrame = _audioCodecCtx->channels;
        _outputFormat.mFormatID = kAudioFormatLinearPCM;
        
        bool isFloat = _audioCodecCtx->sample_fmt == AV_SAMPLE_FMT_FLT || _audioCodecCtx->sample_fmt == AV_SAMPLE_FMT_FLTP;
        bool isS16 = _audioCodecCtx->sample_fmt == AV_SAMPLE_FMT_S16 || _audioCodecCtx->sample_fmt == AV_SAMPLE_FMT_S16P;
        bool isPlanar = av_sample_fmt_is_planar((enum AVSampleFormat)_audioCodecCtx->sample_fmt);
        
        // 测试目标输出: S16P
//        isFloat = false; isS16 = true; isPlanar = true;
        // 测试目标输出: S16
//        isFloat = false; isS16 = true; isPlanar = false;
        // 测试目标输出: FLOAT
//        isFloat = true; isS16 = false; isPlanar = false;
        // 测试目标输出: FLOATP
//        isFloat = true; isS16 = false; isPlanar = true;
        
        if (isS16){
            _outputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger;
            _outputFormat.mFramesPerPacket = 1;
            _outputFormat.mBitsPerChannel = sizeof(SInt16) * 8;
        } else if (isFloat){
            _outputFormat.mFormatFlags = kAudioFormatFlagIsFloat;
            _outputFormat.mFramesPerPacket = 1;
            _outputFormat.mBitsPerChannel = sizeof(float) * 8;
        } else {
            isFloat = false;
            isS16 = YES;
            isPlanar = false;
            NSLog(@"其他格式，默认重采样为S16！");
        }
        
        if (isPlanar) {
            _outputFormat.mFormatFlags |= kAudioFormatFlagIsNonInterleaved;
            _outputFormat.mBytesPerFrame = _outputFormat.mBitsPerChannel / 8;
            _outputFormat.mBytesPerPacket = _outputFormat.mBytesPerFrame * _outputFormat.mFramesPerPacket;
            
            if (isFloat) {
                self.target_sample_fmt = AV_SAMPLE_FMT_FLTP;
            } else {
                self.target_sample_fmt = AV_SAMPLE_FMT_S16P;
            }
        } else {
            _outputFormat.mFormatFlags |= kAudioFormatFlagIsPacked;
            _outputFormat.mBytesPerFrame = (_outputFormat.mBitsPerChannel / 8) * _outputFormat.mChannelsPerFrame;
            _outputFormat.mBytesPerPacket = _outputFormat.mBytesPerFrame * _outputFormat.mFramesPerPacket;
            
            if (isFloat) {
                self.target_sample_fmt = AV_SAMPLE_FMT_FLT;
            } else {
                self.target_sample_fmt = AV_SAMPLE_FMT_S16;
            }
        }
        
        status = AudioUnitSetProperty(_audioUnit,
                             kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Input,
                             kOutputBus,
                             &_outputFormat, size);
        NSAssert(noErr == status, @"AudioUnitSetProperty");
        _numOutputChannels = _outputFormat.mChannelsPerFrame;
        
        UInt32 flag = 0;
        AudioUnitSetProperty(_audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, kInputBus, &flag, sizeof(flag));
        AudioUnitSetProperty(_audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, kInputBus, &flag, sizeof(flag));
        // Slap a render callback on the unit
        AURenderCallbackStruct callbackStruct;
        callbackStruct.inputProc = MRRenderCallback;
        callbackStruct.inputProcRefCon = (__bridge void *)(self);
        
        status = AudioUnitSetProperty(_audioUnit,
                             kAudioUnitProperty_SetRenderCallback,
                             kAudioUnitScope_Input,
                             kOutputBus,
                             &callbackStruct,
                             sizeof(callbackStruct));
        NSAssert(noErr == status, @"AudioUnitSetProperty");
        status = AudioUnitInitialize(_audioUnit);
        NSAssert(noErr == status, @"AudioUnitInitialize");
#undef kOutputBus
#undef kInputBus
    }
    
    if (![self audioCodecIsSupported:_audioCodecCtx]) {
        
        int64_t dst_ch_layout = av_get_default_channel_layout((int)_numOutputChannels);
        int64_t src_ch_layout = av_get_default_channel_layout(_audioCodecCtx->channels);
        
        int src_rate = _audioCodecCtx->sample_rate;
        enum AVSampleFormat src_sample_fmt = _audioCodecCtx->sample_fmt;
        
        enum AVSampleFormat dst_sample_fmt = self.target_sample_fmt;
        int dst_rate = _samplingRate;
        
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
        OSStatus status = AudioOutputUnitStart(_audioUnit);
        if(noErr == status){
            self.isPalying = YES;
        }
        NSAssert(noErr == status, @"AudioOutputUnitStart");
    }
}

- (void)pauseAudio
{
    if (self.isPalying) {
        AudioOutputUnitStop(_audioUnit);
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
                    
                    if (self.aligned_width != video_frame->linesize[0]) {
                        self.aligned_width = video_frame->linesize[0];
                        const int picSize = avpicture_get_size(self.target_pix_fmt, self.aligned_width, self.vheight);
                        self.out_buffer = av_realloc(self.out_buffer, picSize*sizeof(uint8_t));
                        avpicture_fill((AVPicture *)self.pFrameYUV, self.out_buffer, self.target_pix_fmt, self.aligned_width, self.vheight);
                    }
                    
                    // 根据配置把数据转换成 NV12 或者 RGB24
                    int pictRet = sws_scale(self.img_convert_ctx, (const uint8_t* const*)video_frame->data, video_frame->linesize, 0, self.vheight, self.pFrameYUV->data, self.pFrameYUV->linesize);
                    
                    if (pictRet <= 0) {
                        av_frame_free(&video_frame);
                        return ;
                    }
                    
                    CMSampleBufferRef sampleBuffer = [self sampleBufferFromAVFrame:self.pFrameYUV w:self.vwidth h:self.vheight];
                    
                    // 获取时长
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
                
                    MRAudioFrame *frame = [MRAudioFrame new];
                    
                    bool is_planar = av_sample_fmt_is_planar((enum AVSampleFormat)self.target_sample_fmt);
                    const NSUInteger numChannels = self.numOutputChannels;
                    
                    ///需要重采样
                    if (self.audio_convert_ctx) {
           
                        if (is_planar) {
                            int bufSize = av_samples_get_buffer_size(audio_frame->linesize, 1, audio_frame->nb_samples, self.target_sample_fmt, 1);
                            
                            if (!self.audioBuffer4PlanarL || !self.audioBuffer4PlanarR || self.audioBuffer4PlanarSize < bufSize) {
                                self.audioBuffer4PlanarSize = bufSize;
                                self.audioBuffer4PlanarL = realloc(self.audioBuffer4PlanarL, self.audioBuffer4PlanarSize);
                                self.audioBuffer4PlanarR = realloc(self.audioBuffer4PlanarR, self.audioBuffer4PlanarSize);
                            }
                            
                            uint8_t *outbuf[2] = { self.audioBuffer4PlanarL, self.audioBuffer4PlanarR };
                            NSInteger numFrames = swr_convert(self.audio_convert_ctx,
                                                    outbuf,
                                                    audio_frame->nb_samples,
                                                    (const uint8_t **)audio_frame->data,
                                                    audio_frame->nb_samples);
                            
                            if (numFrames < 0) {
                                NSLog(@"fail resample audio");
                                break;
                            }
                            
                            frame.left = [[NSData alloc]initWithBytes:self.audioBuffer4PlanarL length:bufSize];
                            frame.right = [[NSData alloc]initWithBytes:self.audioBuffer4PlanarR length:bufSize];
                            
                        } else {
                            const int bufSize = av_samples_get_buffer_size(NULL,
                                                                           (int)numChannels,
                                                                           audio_frame->nb_samples,
                                                                           self.target_sample_fmt,
                                                                           1);
    
                            if (!self.audioBuffer4Packet || self.audioBuffer4PacketSize < bufSize) {
                                self.audioBuffer4PacketSize = bufSize;
                                self.audioBuffer4Packet = realloc(self.audioBuffer4Packet, self.audioBuffer4PacketSize);
                            }
    
                            Byte *outbuf[2] = { self.audioBuffer4Packet, 0 };
    
                            NSInteger numFrames = swr_convert(self.audio_convert_ctx,
                                                    outbuf,
                                                    audio_frame->nb_samples,
                                                    (const uint8_t **)audio_frame->data,
                                                    audio_frame->nb_samples);
                            
                            const NSUInteger numElements = numFrames * numChannels;
                            UInt32 size4Packet = self.outputFormat.mBitsPerChannel / 8;
                            NSMutableData *data = [NSMutableData dataWithLength:numElements * size4Packet];
                            memcpy(data.mutableBytes, self.audioBuffer4Packet, numElements * size4Packet);
                            frame.samples = [data copy];
                        }
                    }
                    /// 不需要重采样
                    else {
                        
                        if (self.audioCodecCtx->sample_fmt != self.target_sample_fmt) {
                            NSAssert(false, @"bucheck, audio format is invalid");
                        }
                        
                        if (is_planar) {
                            int data_size = av_samples_get_buffer_size(audio_frame->linesize, 1, audio_frame->nb_samples, self.target_sample_fmt, 1);
                            
                            uint8_t *left = audio_frame->data[0];
                            uint8_t *right = audio_frame->data[1];
#if DEBUG_RECORD_PCM_TO_FILE
                            fwrite(left, 1, data_size, self->file_pcm_l);
                            fwrite(right, 1, data_size, self->file_pcm_r);
#endif
                            frame.left = [[NSData alloc]initWithBytes:left length:data_size];
                            frame.right = [[NSData alloc]initWithBytes:right length:data_size];
                        } else {
                            int data_size = audio_frame->linesize[0];
                            uint8_t *pcmData = audio_frame->data[0];
                            NSMutableData *data = [NSMutableData dataWithLength:data_size];
                            memcpy(data.mutableBytes, pcmData, data_size);
                            frame.samples = [data copy];
                        }
                    }
                    
                    frame.position = av_frame_get_best_effort_timestamp(audio_frame) * self.audioTimeBase;
                    frame.duration = av_frame_get_pkt_duration(audio_frame) * self.audioTimeBase;

                    if (frame.duration == 0) {
                        // sometimes ffmpeg can't determine the duration of audio frame
                        // especially of wma/wmv format
                        // so in this case must compute duration
                        frame.duration = frame.samples.length / (sizeof(float) * numChannels * self.samplingRate);
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
    return [self openAudioStream:stream];
}

- (BOOL)openAudioStream:(AVStream *)stream
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

- (bool) renderFrames: (UInt32) wantFrames
               ioData: (AudioBufferList *) ioData
{
    // 1. 将buffer数组全部置为0；
    for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
        AudioBuffer audioBuffer = ioData->mBuffers[iBuffer];
        bzero(audioBuffer.mData, audioBuffer.mDataByteSize);
    }
    
    ///目标是Packet类型
    if(self.target_sample_fmt == AV_SAMPLE_FMT_S16
       || self.target_sample_fmt == AV_SAMPLE_FMT_FLT){
    
        //    numFrames = 1115
        //    SInt16 = 2;
        //    mNumberChannels = 2;
        //    ioData->mBuffers[iBuffer].mDataByteSize = 4460
        // 4460 = numFrames x SInt16 * mNumberChannels = 1115 x 2 x 2;
        
        // 2. 获取 AudioUnit 的 Buffer
        int numberBuffers = ioData->mNumberBuffers;
        
        // AudioUnit 对于 packet 形式的PCM，只会提供一个 AudioBuffer
        if (numberBuffers >= 1) {
            
            AudioBuffer audioBuffer = ioData->mBuffers[0];
            //这个是 AudioUnit 给我们提供的用于存放采样点的buffer
            uint8_t *buffer = audioBuffer.mData;
            //                ///每个采样点占用的字节数:
            //                UInt32 bytesPrePack = self.outputFormat.mBitsPerChannel / 8;
            //                ///Audio的Frame是包括所有声道的，所以要乘以声道数；
            //                const NSUInteger frameSizeOf = 2 * bytesPrePack;
            //                ///向缓存的音频帧索要wantBytes个音频采样点: wantFrames x frameSizeOf
            //                NSUInteger bufferSize = wantFrames * frameSizeOf;
            const UInt32 bufferSize = audioBuffer.mDataByteSize;
            int thisNumChannels = audioBuffer.mNumberChannels;
            ///仅处理双声道
            if (thisNumChannels == 2) {
                /* 对于 AV_SAMPLE_FMT_S16 而言，采样点是这么分布的:
                 S16_L,S16_R,S16_L,S16_R,……
                 AudioBuffer 也需要这样的排列格式，因此直接copy即可；
                 同理，对于 FLOAT 也是如此左右交替！
                 */
                
                ///3. 获取 bufferSize 个字节，并塞到 buffer 里；
                [self fetchPCMPacketData:buffer wantBytes:bufferSize];
            } else {
                //即使 iPhone 上只有一个扬声器，也没有走这里，目前没遇到这种case！也有可能永远不会走，因为AudioUnit也不知道他的目标输出的设备支持几个声道！
                NSLog(@"what's wrong?");
            }
        } else {
            NSLog(@"what's wrong?");
        }
    }
    
    ///目标是Planar类型，Mac平台支持整形和浮点型，交错和二维平面
    else if (self.target_sample_fmt == AV_SAMPLE_FMT_FLTP || self.target_sample_fmt == AV_SAMPLE_FMT_S16P){
        
        //    numFrames = 558
        //    float = 4;
        //    ioData->mBuffers[iBuffer].mDataByteSize = 2232
        // 2232 = numFrames x float = 558 x 4;
        // FLTP = FLOAT + Planar;
        // FLOAT: 具体含义是使用 float 类型存储量化的采样点，比 SInt16 精度要高出很多！当然空间也大些！
        // Planar: 二维的，所以会把左右声道使用两个数组分开存储，每个数组里的元素是同一个声道的！
        
        //双声道
        if (ioData->mNumberBuffers == 2) {
            // 2. 向缓存的音频帧索要 ioData->mBuffers[0].mDataByteSize 个字节的数据
            /*
             Float_L,Float_L,Float_L,Float_L,……  -> mBuffers[0].mData
             Float_R,Float_R,Float_R,Float_R,……  -> mBuffers[1].mData
             左对左，右对右
             
             同理，对于 S16P 也是如此！一一对应！
             */
            //3. 获取左右声道数据
            [self fetchPCMPlanarLeft:ioData->mBuffers[0].mData sizeLeft:ioData->mBuffers[0].mDataByteSize right:ioData->mBuffers[1].mData sizeRight:ioData->mBuffers[1].mDataByteSize];
        }
        else {
            NSLog(@"what's wrong?");
        }
    }
    return noErr;
}

- (NSUInteger)fetchPCMPacketData:(void *)outData wantBytes:(const NSInteger) wantBytes
{
    NSUInteger giveBytes = 0;
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
                        _currentAudioFrame.offset = 0;
                    }
                }
            }
            
            if (_currentAudioFrame) {
                
                NSData *samples = _currentAudioFrame.samples;
                const void *from = (Byte *)samples.bytes + _currentAudioFrame.offset;
                NSUInteger bytesLeft = (samples.length - _currentAudioFrame.offset);
                ///根据剩余数据长度和需要数据长度算出应当copy的长度
                NSUInteger bytesToCopy = MIN(wantBytes - giveBytes, bytesLeft);
                memcpy(outData, from, bytesToCopy);
                giveBytes += bytesToCopy;
                outData = (void *)((char *)outData + bytesToCopy);
                
                if (bytesToCopy < bytesLeft){
                    //剩余的比copy走的多，则修改偏移量
                    _currentAudioFrame.offset += bytesToCopy;
                }else{
                    //读取完毕，则清空；读取下一个包
                    _currentAudioFrame = nil;
                    _currentAudioFrame.offset = 0;
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

- (void)fetchPCMPlanarLeft:(void*)leftBuffer sizeLeft:(UInt32)leftWantSize right:(void*)rightBuffer sizeRight:(UInt32)rightWantSize
{
    @autoreleasepool {
        
        while (leftWantSize > 0 || rightWantSize > 0) {
            
            if (!_currentAudioFrame) {
                
                @synchronized(self) {
                    
                    NSUInteger count = _audioFrames.count;
                    
                    if (count > 0) {
                        
                        MRAudioFrame *audioFrame = _audioFrames[0];
                        
                        [_audioFrames removeObjectAtIndex:0];
                        
                        _currentAudioFrame = audioFrame;
                    }
                }
            }
            
            if (_currentAudioFrame) {
                
                NSData *leftSamples = _currentAudioFrame.left;
                NSUInteger leftOffset = _currentAudioFrame.leftOffset;
                
                NSData *rightSamples = _currentAudioFrame.right;
                NSUInteger rightOffset = _currentAudioFrame.rightOffset;
                
                const void *leftFrom = (Byte *)leftSamples.bytes + leftOffset;
                NSUInteger leftBytesLeft = (leftSamples.length - leftOffset);
                
                const void *rightFrom = (Byte *)rightSamples.bytes + rightOffset;
                NSUInteger rightBytesLeft = (rightSamples.length - rightOffset);
                ///根据剩余数据长度和需要数据长度算出应当copy的长度
                NSUInteger leftBytesToCopy = MIN(leftWantSize, leftBytesLeft);
                NSUInteger rightBytesToCopy = MIN(rightWantSize, rightBytesLeft);
                
                memcpy(leftBuffer, leftFrom, leftBytesToCopy);
                leftBuffer = (void *)((char *)leftBuffer + leftBytesToCopy);
                leftWantSize -= leftBytesToCopy;
                _currentAudioFrame.leftOffset += leftBytesToCopy;
                
                memcpy(rightBuffer, rightFrom, rightBytesToCopy);
                rightBuffer = (void *)((char *)rightBuffer + rightBytesToCopy);
                rightWantSize -= rightBytesToCopy;
                _currentAudioFrame.rightOffset += rightBytesToCopy;
                
                if (leftBytesToCopy >= leftBytesLeft){
                    //读取完毕，则清空；读取下一个包
                    _currentAudioFrame = nil;
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

