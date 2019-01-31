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

// 按照fps=24计算，缓存20s的视频包；缓存2s的解码帧;
static int kPacketCacheCount = 24 * 20;
static float kVideoMinBufferDuration = 1;
static int kVidoFrameCacheCount = 24 * 2;

static float kAudioMinBufferDuration = 1;
static int kAudioFrameCacheCount = 24 * 60;

#define USE_PIXEL_BUFFER_POLL 1

@interface ViewController ()
{
    FILE * file_pcm_l;
    FILE * file_pcm_r;
}
@property (weak, nonatomic) UIActivityIndicatorView *indicatorView;

@property (assign, nonatomic) AVFormatContext *formatCtx;
@property (strong, nonatomic) dispatch_queue_t read_queue;
@property (nonatomic,assign,getter=isReading) BOOL reading;

@property (strong, nonatomic) dispatch_queue_t decode_queue_v;
@property (nonatomic,assign,getter=isDecoding_v) BOOL decoding_v;

@property (strong, nonatomic) dispatch_queue_t decode_queue_a;
@property (nonatomic,assign,getter=isDecoding_a) BOOL decoding_a;


@property (nonatomic,strong) NSMutableArray <MRVideoFrame *> *videoFrames;
@property (strong, nonatomic) NSMutableArray<MRAudioFrame *> *audioFrames;

@property (nonatomic,assign) AVCodecContext *videoCodecCtx;
@property (nonatomic,assign) AVCodecContext *audioCodecCtx;

@property (nonatomic,assign) MRPacketQueue videoPacketQueue;
@property (nonatomic,assign) MRPacketQueue audioPacketQueue;

@property (nonatomic,assign) int stream_index_video;
@property (nonatomic,assign) int stream_index_audio;

@property (nonatomic,assign) float videoTimeBase;
@property (nonatomic,assign) float audioTimeBase;
@property (nonatomic,assign) BOOL videoBufferOk;
@property (nonatomic,assign) BOOL audioBufferOk;
@property (nonatomic,assign) BOOL eof;

///画面高度，单位像素
@property (nonatomic,assign) int vwidth;
@property (nonatomic,assign) int aligned_width;
@property (nonatomic,assign) int vheight;
//视频目标像素格式
@property (nonatomic,assign) enum AVPixelFormat target_pix_fmt;
@property (nonatomic,assign) enum AVSampleFormat target_sample_fmt;
//格式转换
@property (nonatomic,assign) uint8_t *out_buffer;
@property (nonatomic,assign) struct SwsContext * img_convert_ctx;
@property (nonatomic,assign) AVFrame *pFrameYUV;

@property (strong, nonatomic) MRVideoRenderView *renderView;
@property (assign, nonatomic) CVPixelBufferPoolRef pixelBufferPool;

@property (nonatomic,assign) double  samplingRate;
@property (nonatomic,assign) UInt32   numBytesPerSample;
@property (nonatomic,assign) float  outputVolume;

@property (nonatomic,assign) AudioUnit audioUnit;
@property (nonatomic,assign) AudioStreamBasicDescription outputFormat;
@property (nonatomic,assign) NSInteger   numOutputChannels;
@property (nonatomic,assign) float    *outData;
@property (nonatomic,strong) MRAudioFrame *currentAudioFrame;
//@property (nonatomic,assign) NSUInteger    currentAudioFramePos;
@property (nonatomic,assign) SwrContext  *audio_convert_ctx;

@property (nonatomic,assign) uint8_t     *swrBuffer;
@property (nonatomic,assign) NSUInteger  swrBufferSize;
@property (nonatomic,assign) BOOL isPalying;///audio unit 是否开始

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
    
    NSString *moviePath = nil;//[[NSBundle mainBundle]pathForResource:@"test" ofType:@"mp4"];
    ///该地址可以是网络的也可以是本地的；
    moviePath = @"http://debugly.cn/repository/test.mp4";
    
    moviePath = @"http://192.168.3.2/ffmpeg-test/test.mp4";
    moviePath = @"http://192.168.3.2/ffmpeg-test/xp5.mp4";
    moviePath = @"http://192.168.3.2/ffmpeg-test/IMG_2914.mp4";
    moviePath = @"http://192.168.3.2/ffmpeg-test/IMG_2879.mp4";
    moviePath = @"http://192.168.3.2/ffmpeg-test/IMG_3046.mov";
    moviePath = @"http://192.168.3.2/ffmpeg-test/IMG_3123.mov";
    moviePath = @"http://192.168.3.2/ffmpeg-test/IMG_3149.mov";
    
    moviePath = @"http://10.7.36.117:8080/ffmpeg-test/test.mp4";
    moviePath = @"http://10.7.36.117:8080/ffmpeg-test/4K2160p.120fps.mkv";
    moviePath = @"http://10.7.36.117:8080/ffmpeg-test/Fascination.Nature.Seven.Seasons.ts";
    moviePath = @"http://10.7.36.117:8080/ffmpeg-test/Opera.480p.x264.AAC.mp4";
    moviePath = @"http://10.7.36.117:8080/ffmpeg-test/IMG_3149.mov";
    moviePath = @"http://10.7.36.117:8080/ffmpeg-test/xp5.mp4";
    
//    moviePath = @"http://10.7.36.117:8080/ffmpeg-test/Goldfish.mp3";
    
//    moviePath = @"http://10.7.36.117:8080/ffmpeg-test/IMG_2879.mp4";
//    moviePath = @"http://10.7.36.117:8080/ffmpeg-test/IMG_2914.mp4";
//    moviePath = @"http://10.7.36.117:8080/ffmpeg-test/IMG_3190.mp4";
//    moviePath = @"http://10.7.36.117:8080/ffmpeg-test/sintel.mp4";
//    moviePath = @"http://10.7.36.117:8080/ffmpeg-test/IMG_2899.mp4";
//    moviePath = @"http://10.7.36.117:8080/ffmpeg-test/50846a5f8f8518b5ed957ce01a8adafa.f4v";
//    moviePath = @"http://10.7.36.117:8080/ffmpeg-test/huoshan_2.mp4";
    
    static bool has_init_network = false;
    
    if ([moviePath hasPrefix:@"http"] && !has_init_network) {
        //Using network protocols without global network initialization. Please use avformat_network_init(), this will become mandatory later.
        //播放网络视频的时候，要首先初始化下网络模块。
        avformat_network_init();
        has_init_network = true;
    }
    
    NSLog(@"load movie:%@",moviePath);

    if (file_pcm_l == NULL) {
        const char *l = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"L.pcm"]UTF8String];
        NSLog(@"%s",l);
        file_pcm_l = fopen(l, "wb+");
    }
    
    if (file_pcm_r == NULL) {
        const char *r = [[NSTemporaryDirectory() stringByAppendingPathComponent:@"R.pcm"]UTF8String];
        file_pcm_r = fopen(r, "wb+");
    }
    
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
    
    
#define kMax_Frame_Size     4096
#define kMax_Chan           2
#define kMax_Sample_Dumped  5
    
    _outData = (float *)calloc(kMax_Frame_Size * kMax_Chan, sizeof(float));
    
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
        
        //        bool isPacked = _outputFormat.mFormatFlags & kLinearPCMFormatFlagIsPacked;
        //        if (_outputFormat.mFormatFlags & kLinearPCMFormatFlagIsFloat) {
        //            //真机
        //            self.target_sample_fmt = isPacked ? AV_SAMPLE_FMT_FLT : AV_SAMPLE_FMT_FLTP;
        //        } else if (_outputFormat.mFormatFlags & kAudioFormatFlagIsSignedInteger) {
        //            //模拟器
        //            self.target_sample_fmt = isPacked ? AV_SAMPLE_FMT_S16 : AV_SAMPLE_FMT_S16P;
        //        } else {
        //            NSAssert(NO, @"不支持的格式");
        //        }
        
#if TARGET_OS_SIMULATOR
        if (av_sample_fmt_is_planar((enum AVSampleFormat)_audioCodecCtx->sample_fmt)) {
            _outputFormat.mFormatFlags = kAudioFormatFlagIsNonInterleaved;
        } else {
            _outputFormat.mFormatFlags = kAudioFormatFlagIsPacked;
        }
        
        if (_audioCodecCtx->sample_fmt == AV_SAMPLE_FMT_S16 || _audioCodecCtx->sample_fmt == AV_SAMPLE_FMT_S16P){
            _outputFormat.mFormatFlags |= kAudioFormatFlagIsSignedInteger;
            NSAssert(NO, @"=======需要测试！");
        } else if (_audioCodecCtx->sample_fmt == AV_SAMPLE_FMT_FLT || _audioCodecCtx->sample_fmt == AV_SAMPLE_FMT_FLTP){
            _outputFormat.mFormatID = kAudioFormatLinearPCM;
            _outputFormat.mFormatFlags |= kAudioFormatFlagIsFloat;
            _outputFormat.mFramesPerPacket = 1;
            _outputFormat.mBitsPerChannel = 32;
            _outputFormat.mBytesPerFrame = 4;
            _outputFormat.mBytesPerPacket = 4;
        } else {
            NSAssert(NO, @"=======需要重采样！");
        }
        self.target_sample_fmt = _audioCodecCtx->sample_fmt;
#elif TARGET_OS_IPHONE
        self.target_sample_fmt = AV_SAMPLE_FMT_S16;
        _outputFormat.mFormatID = kAudioFormatLinearPCM;
        _outputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger | kAudioFormatFlagIsPacked;
        _outputFormat.mFramesPerPacket = 1;
        _outputFormat.mBitsPerChannel = 16;
        _outputFormat.mBytesPerFrame = (_outputFormat.mBitsPerChannel / 8) * _outputFormat.mChannelsPerFrame;
        _outputFormat.mBytesPerPacket = _outputFormat.mBytesPerFrame * _outputFormat.mFramesPerPacket;
#endif
        
        status = AudioUnitSetProperty(_audioUnit,
                             kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Input,
                             kOutputBus,
                             &_outputFormat, size);
        NSAssert(noErr == status, @"AudioUnitSetProperty");
        _numBytesPerSample  = _outputFormat.mBitsPerChannel / 8; //真机是4，模拟器是2
        _numOutputChannels  = _outputFormat.mChannelsPerFrame;
        
        //        UInt32 flag = 0;
        //        AudioUnitSetProperty(_audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, kInputBus, &flag, sizeof(flag));
        //        AudioUnitSetProperty(_audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, kInputBus, &flag, sizeof(flag));
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
        int64_t src_ch_layout  = av_get_default_channel_layout(_audioCodecCtx->channels);
        
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
        
        
//        /* allocate source and destination samples buffers */
//
//        int src_nb_channels = av_get_channel_layout_nb_channels(src_ch_layout);
//
//        uint8_t **src_data = NULL, **dst_data = NULL;
//        int src_linesize, dst_linesize;
//        int src_nb_samples = 1024, dst_nb_samples, max_dst_nb_samples;
//
//        av_samples_alloc_array_and_samples(&src_data, &src_linesize, src_nb_channels,
//                                                 src_nb_samples, src_sample_fmt, 0);
//
//        /* compute the number of converted samples: buffering is avoided
//         * ensuring that the output buffer will contain at least all the
//         * converted input samples */
//        max_dst_nb_samples = dst_nb_samples =
//        av_rescale_rnd(src_nb_samples, dst_rate, src_rate, AV_ROUND_UP);
//
//        /* buffer is going to be directly written to a rawaudio file, no alignment */
//        int dst_nb_channels = av_get_channel_layout_nb_channels(dst_ch_layout);
//        av_samples_alloc_array_and_samples(&dst_data, &dst_linesize, dst_nb_channels,
//                                                 dst_nb_samples, dst_sample_fmt, 0);
    
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
        
        if (count < kPacketCacheCount){
            return false;
        }
        
        return true;
    }
}

- (bool)checkAudioPacketFull
{
    @synchronized(self) {
        
        int count = self.audioPacketQueue.nb_packets;
        
        if (count < kPacketCacheCount){
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
        [self pauseAudio];
        [self notifiDecodeAudio];
        __weakSelf__
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.2 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strongSelf__
            [self audioTick];
        });
    }
}

#pragma mark - 解码线程

- (void)notifiDecodeVideo
{
    bool full = [self checkVideoFrameFull];
    if (!full) {
        [self startDecodeVideoPacketToFrames];
    }
}

- (void)notifiDecodeAudio
{
    bool full = [self checkAudioFrameFull];
    if (!full) {
        [self startDecodeAudioPacketToFrames];
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

- (void)startDecodeVideoPacketToFrames
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

#define     SWR_CH_MAX   32

static void setup_array(uint8_t* out[SWR_CH_MAX], AVFrame* in_frame, int format, int samples)
{
    if (av_sample_fmt_is_planar((enum AVSampleFormat)format))
    {
        int i;
        //int plane_size = av_get_bytes_per_sample((enum AVSampleFormat)(format & 0xFF)) * samples;
        format &= 0xFF;
        //从decoder出来的frame中的data数据不是连续分布的，所以不能这样写：in_frame->data[0]+i*plane_size;
        for (i = 0; i < in_frame->channels; i++)
        {
            out[i] = in_frame->data[i];
        }
    }
    else
    {
        out[0] = in_frame->data[0];
    }
}

- (void)startDecodeAudioPacketToFrames
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
                    
                    const NSUInteger numChannels = self.numOutputChannels;
                    NSInteger numFrames = 0;
                    
                    MRAudioFrame *frame = [MRAudioFrame new];
                    if (self.audio_convert_ctx) {
                        const int ratio = MAX(1, self.samplingRate / self.audioCodecCtx->sample_rate) *
                        MAX(1, self.numOutputChannels / self.audioCodecCtx->channels) * 2;
                        
                        const int bufSize = av_samples_get_buffer_size(NULL,
                                                                       (int)self.numOutputChannels,
                                                                       audio_frame->nb_samples * ratio,
                                                                       AV_SAMPLE_FMT_S16,
                                                                       1);
                        
                        if (!self.swrBuffer || self.swrBufferSize < bufSize) {
                            self.swrBufferSize = bufSize;
                            self.swrBuffer = realloc(self.swrBuffer, self.swrBufferSize);
                        }
                        
                        Byte *outbuf[2] = { self.swrBuffer, 0 };
                        
                        numFrames = swr_convert(self.audio_convert_ctx,
                                                outbuf,
                                                audio_frame->nb_samples * ratio,
                                                (const uint8_t **)audio_frame->data,
                                                audio_frame->nb_samples);
                        
                        if (numFrames < 0) {
                            NSLog(@"fail resample audio");
                            break;
                        }
                        
                        //int64_t delay = swr_get_delay(_swrContext, audioManager.samplingRate);
                        //if (delay > 0)
                        //    LoggerAudio(0, @"resample delay %lld", delay);
                        
                        void * audioData = _swrBuffer;
                        const NSUInteger numElements = numFrames * numChannels;
                        NSMutableData *data = [NSMutableData dataWithLength:numElements * sizeof(float)];
                        
                        float scale = 1.0 / (float)INT16_MAX ;
                        //Converts an array of signed 16-bit integers to single-precision floating-point values.
                        vDSP_vflt16((SInt16 *)audioData, 1, data.mutableBytes, 1, numElements);
                        //Single-precision real vector-scalar multiply.
                        vDSP_vsmul(data.mutableBytes, 1, &scale, data.mutableBytes, 1, numElements);
                        frame.samples = [data copy];
                    } else {
                        
                        if (self.audioCodecCtx->sample_fmt != self.target_sample_fmt) {
                            NSAssert(false, @"bucheck, audio format is invalid");
                        }
                        ///FLOTP
                        int data_size = av_samples_get_buffer_size(audio_frame->linesize, 1, audio_frame->nb_samples, self.target_sample_fmt, 0);
                        
                        uint8_t *left = audio_frame->data[0];
                        uint8_t *right = audio_frame->data[1];
                        
                        fwrite(left, 1, data_size, self->file_pcm_l);
                        fwrite(right, 1, data_size, self->file_pcm_r);
                        
                        frame.left = [[NSData alloc]initWithBytes:left length:data_size];
                        frame.right = [[NSData alloc]initWithBytes:right length:data_size];
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
        NSLog(@"cache video packet");
        mr_packet_queue_put(&self->_videoPacketQueue, packet);
    }
}

- (void)cacheAudioPacket:(AVPacket *)packet
{
    @synchronized(self) {
        NSLog(@"cache audio packet");
        mr_packet_queue_put(&self->_audioPacketQueue, packet);
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

- (bool) renderFrames: (UInt32) numFrames
               ioData: (AudioBufferList *) ioData
{
    // 1. 将buffer数组全部置为0；清理现场
    for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
        memset(ioData->mBuffers[iBuffer].mData, 0, ioData->mBuffers[iBuffer].mDataByteSize);
    }
#if TARGET_OS_SIMULATOR
//    numFrames = 558
//    float = 4;
//    ioData->mBuffers[iBuffer].mDataByteSize = 2232
    
    ///双声道
    if (ioData->mNumberBuffers == 2) {
        // 2.索要 numFrames 个帧，每帧 _numOutputChannels 个channel，内部计算大小
        [self fetchPCMLeft:ioData->mBuffers[0].mData sizeLeft:ioData->mBuffers[0].mDataByteSize right:ioData->mBuffers[1].mData sizeRight:ioData->mBuffers[1].mDataByteSize];
    }
#elif TARGET_OS_IPHONE
    // 2.索要 numFrames 个帧，每帧 _numOutputChannels 个channel，内部计算大小
    [self fetchData:_outData numFrames:numFrames numChannels:_numOutputChannels];
    
    float scale = (float)INT16_MAX;
    
    //Single-precision real vector-scalar multiply.
    vDSP_vsmul(_outData, 1, &scale, _outData, 1, numFrames*_numOutputChannels);
    
    //        UInt32 offset = 0;
    for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
        
        int thisNumChannels = ioData->mBuffers[iBuffer].mNumberChannels;
        //            UInt32 size = ioData->mBuffers[iBuffer].mDataByteSize;
        //            memcpy(ioData->mBuffers[iBuffer].mData, _outData + offset, size);
        //            offset += size;
        
        for (int iChannel = 0; iChannel < thisNumChannels; ++iChannel) {
            //Converts an array of single-precision floating-point values to signed 16-bit integer values, rounding towards zero.
            vDSP_vfix16(_outData+iChannel, _numOutputChannels, (SInt16 *)ioData->mBuffers[iBuffer].mData+iChannel, thisNumChannels, numFrames);
        }
    }
    
#endif
    return noErr;
//    NSUInteger bytesPrePack = 0;
//    ///每个采样点占用的字节数，ffmpeg解码出来是float类型的
//    if(self.target_sample_fmt == AV_SAMPLE_FMT_FLTP || self.target_sample_fmt == AV_SAMPLE_FMT_FLT){
//        bytesPrePack = sizeof(float);
//    } else {
//        bytesPrePack = sizeof(SInt16);
//    }
    
    // 真机 Put the rendered data into the output buffer
    if (_numBytesPerSample == 4) // then we've already got floats
    {
//        char *from = (char *)_outData;
//        
//        UInt32 size = ioData->mBuffers[0].mDataByteSize;
//        memcpy(ioData->mBuffers[0].mData, from, size);
//        memcpy(ioData->mBuffers[1].mData, from + size, size);
        
        for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
            float zero = 0.0;
            int thisNumChannels = ioData->mBuffers[iBuffer].mNumberChannels;

            for (int iChannel = 0; iChannel < thisNumChannels; ++iChannel) {
                //Vector-scalar add; single precision.
                vDSP_vsadd(_outData+iChannel, _numOutputChannels, &zero, (float *)ioData->mBuffers[iBuffer].mData, thisNumChannels, numFrames);
            }
        }
    }
    // 模拟器
    else if (_numBytesPerSample == 2) // then we need to convert Float -> SInt16 (and also scale)
    {
        
        float scale = (float)INT16_MAX;
        
        //Single-precision real vector-scalar multiply.
        vDSP_vsmul(_outData, 1, &scale, _outData, 1, numFrames*_numOutputChannels);
        
//        UInt32 offset = 0;
        for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
            
            int thisNumChannels = ioData->mBuffers[iBuffer].mNumberChannels;
//            UInt32 size = ioData->mBuffers[iBuffer].mDataByteSize;
//            memcpy(ioData->mBuffers[iBuffer].mData, _outData + offset, size);
//            offset += size;
        
            for (int iChannel = 0; iChannel < thisNumChannels; ++iChannel) {
                //Converts an array of single-precision floating-point values to signed 16-bit integer values, rounding towards zero.
                vDSP_vfix16(_outData+iChannel, _numOutputChannels, (SInt16 *)ioData->mBuffers[iBuffer].mData+iChannel, thisNumChannels, numFrames);
            }
        }
        
    }
    
    return noErr;
}

- (void)fetchData:(float *)outData numFrames:(NSInteger) numFrames numChannels:(NSInteger) numChannels
{
    @autoreleasepool {
        
        while (numFrames > 0) {
            
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
            
            __weakSelf__
            dispatch_async(dispatch_get_main_queue(), ^{
                __strongSelf__
                [self notifiDecodeAudio];
            });
            
            NSUInteger bytesPrePack = 0;
            //            ///每个采样点占用的字节数，ffmpeg解码出来是float类型的
            //            if(self.target_sample_fmt == AV_SAMPLE_FMT_FLTP || self.target_sample_fmt == AV_SAMPLE_FMT_FLT){
            //                bytesPrePack = sizeof(float);
            //            } else {
            //                bytesPrePack = sizeof(SInt16);
            //            }
            bytesPrePack = sizeof(float);
            
            if (_currentAudioFrame) {
                
                NSData *samples = _currentAudioFrame.samples;
                const void *from = (Byte *)samples.bytes + _currentAudioFrame.offset;
                //                const void *from = _currentAudioFrame.buff + _currentAudioFramePos;
                const NSUInteger bytesLeft = (samples.length - _currentAudioFrame.offset);
                
                ///Audio的Frame是包括所有声道的，所以要乘以声道数；
                const NSUInteger frameSizeOf = numChannels * bytesPrePack;
                ///根据剩余数据长度和需要数据长度算出应当copy的长度
                const NSUInteger bytesToCopy = MIN(numFrames * frameSizeOf, bytesLeft);
                ///计算出copy多少个 Audio unit frame
                const NSUInteger framesToCopy  = bytesToCopy / frameSizeOf;
                
                memcpy(outData, from, bytesToCopy);
                outData = (float *)((char *)outData + bytesToCopy);
                /*
                 计算出copy多少个 float 类型的数据
                 const NSUInteger packetsToCopy = bytesToCopy / bytesPrePack;
                 outData += packetsToCopy;
                 */
                numFrames -= framesToCopy;
                
                if (bytesToCopy < bytesLeft){
                    //剩余的比copy走的多，则修改偏移量
                    _currentAudioFrame.offset += bytesToCopy;
                }else{
                    //读取完毕，则清空；读取下一个包
                    _currentAudioFrame = nil;
                    _currentAudioFrame.offset = 0;
                }
            } else {
                memset(outData, 0, numFrames * numChannels * bytesPrePack);
                //LoggerStream(1, @"silence audio");
                break;
            }
        }
    }
}

- (void)fetchPCMLeft:(void*)leftBuffer sizeLeft:(UInt32)leftSize right:(void*)rightBuffer sizeRight:(UInt32)rightSize
{
    @autoreleasepool {
        
        while (leftSize > 0) {
            
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
            
            __weakSelf__
            dispatch_async(dispatch_get_main_queue(), ^{
                __strongSelf__
                [self notifiDecodeAudio];
            });
            
            if (_currentAudioFrame) {
                
                NSData *leftSamples = _currentAudioFrame.left;
                UInt32 leftOffset = _currentAudioFrame.leftOffset;
                
                NSData *rightSamples = _currentAudioFrame.right;
                UInt32 rightOffset = _currentAudioFrame.rightOffset;
                
                const void *leftFrom = (Byte *)leftSamples.bytes + leftOffset;
                UInt32 leftBytesLeft = (leftSamples.length - leftOffset);
                
                const void *rightFrom = (Byte *)rightSamples.bytes + rightOffset;
                UInt32 rightBytesLeft = (rightSamples.length - rightOffset);
                
//                ///Audio的Frame是包括所有声道的，所以要乘以声道数；
//                const NSUInteger frameSizeOf = numChannels * bytesPrePack;
//                ///根据剩余数据长度和需要数据长度算出应当copy的长度
                
                UInt32 leftBytesToCopy = MIN(leftSize, leftBytesLeft);
                UInt32 rightBytesToCopy = MIN(rightSize, rightBytesLeft);
//                ///计算出copy多少个 Audio unit frame
//                const NSUInteger framesToCopy  = bytesToCopy / frameSizeOf;
                
                memcpy(leftBuffer, leftFrom, leftBytesToCopy);
                leftBuffer = (void *)((char *)leftBuffer + leftBytesToCopy);
                leftSize -= leftBytesToCopy;
                _currentAudioFrame.leftOffset += leftBytesToCopy;
                
                memcpy(rightBuffer, rightFrom, rightBytesToCopy);
                rightBuffer = (void *)((char *)rightBuffer + rightBytesToCopy);
                rightSize -= rightBytesToCopy;
                _currentAudioFrame.rightOffset += rightBytesToCopy;
                
//                /*
//                 计算出copy多少个 float 类型的数据
//                 const NSUInteger packetsToCopy = bytesToCopy / bytesPrePack;
//                 outData += packetsToCopy;
//                 */
//                numFrames -= framesToCopy;
                
                if (leftBytesToCopy < leftBytesLeft){
                    //剩余的比copy走的多，则修改偏移量
//                    _currentAudioFramePos += bytesToCopy;
                }else{
                    //读取完毕，则清空；读取下一个包
                    _currentAudioFrame = nil;
                }
            } else {
                memset(leftBuffer, 0, leftSize);
                memset(rightBuffer, 0, rightSize);
                //LoggerStream(1, @"silence audio");
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

