//
//  MRMoviePlayer.m
//  FFmpeg006
//
//  Created by Matt Reach on 2018/1/29.
//  Copyright © 2018年 Awesome FFmpeg Study Demo. All rights reserved.
//  开源地址: https://github.com/debugly/StudyFFmpeg

#import "MRMoviePlayer.h"

#import <AudioToolbox/AudioToolbox.h>
#import <AudioUnit/AudioUnit.h>
#import <Accelerate/Accelerate.h>
#import <AVFoundation/AVFoundation.h>

#import <libavutil/log.h>
#import <libavformat/avformat.h>
#import <libavcodec/avcodec.h>
#import <libswresample/swresample.h>
#import "MRAudioFrame.h"
#import "NSTimer+Util.h"

#import "OpenGLView20.h"
#import "MRVideoFrame.h"

#ifndef _weakSelf_SL
#define _weakSelf_SL     __weak   __typeof(self) $weakself = self;
#endif

#ifndef _strongSelf_SL
#define _strongSelf_SL   __strong __typeof($weakself) self = $weakself;
#endif

#define usev3 0
#define fflogOn 0

#define OPENGL 1
#define IMAGE  2
#define LAYER  3

#define RENDER OPENGL

@interface MRMoviePlayer ()

@property (assign, nonatomic) AVFormatContext *formatCtx;
@property (weak, nonatomic) NSTimer *readFramesTimer;
@property (strong, nonatomic) dispatch_queue_t io_queue;

@property (assign, nonatomic) unsigned int stream_index_audio;
@property (assign, nonatomic) unsigned int stream_index_video;

@property (nonatomic,copy) NSString *audioRoute;
@property (nonatomic,assign) double  samplingRate;
@property (nonatomic,assign) UInt32   numBytesPerSample;
@property (nonatomic,assign) float  outputVolume;

@property (nonatomic,assign) AudioUnit audioUnit;
@property (nonatomic,assign) AudioStreamBasicDescription outputFormat;
@property (nonatomic,assign) NSInteger   numOutputChannels;
@property (nonatomic,assign) float    *outData;

@property (nonatomic,strong) NSMutableArray *audioFrames;
@property (nonatomic,strong) NSMutableArray *videoFrames;
@property (nonatomic,assign) AVCodecContext *audioCodecCtx;
@property (nonatomic,assign) AVCodecContext *videoCodecCtx;
@property (nonatomic,assign) SwrContext  *swrContext;
@property (nonatomic,assign) void        *swrBuffer;
@property (nonatomic,assign) NSUInteger  swrBufferSize;
@property (nonatomic,assign) CGFloat     audioTimeBase;
@property (nonatomic,assign) CGFloat     currentPlayPosition;
@property (atomic,assign) BOOL     canGiveFrame;
@property (nonatomic,strong) MRAudioFrame *currentAudioFrame;
@property (nonatomic,assign) NSUInteger    currentAudioFramePos;
@property (nonatomic,strong) NSString *sourceURL;

@property (assign, nonatomic) CGFloat videoTimeBase;
@property (assign, nonatomic) CGFloat fps;
@property (weak, nonatomic) OpenGLView20 *glView;
@property (assign, nonatomic) CGSize videoDimensions;

@end

@implementation MRMoviePlayer

- (void)playURLString:(NSString *)url
{
    self.sourceURL = url;
    NSLog(@"************************************");
    NSLog(@"【v%d】\n%s",avcodec_version(),avcodec_configuration());
    NSLog(@"************************************");
    ///初始化音频配置
    [self activateAudioSession];
    BOOL succ = [self openStream:url];
    if (succ) {
        [self openAudioStream];
        [self openVideoStream];
    }
    ///0.01s调用一次解码
    _weakSelf_SL
    self.readFramesTimer = [NSTimer mr_scheduledWithTimeInterval:0.01 repeats:YES block:^{
        _strongSelf_SL
        [self readFrame];
    }];
    
    [self audioTick];
    [self videoTick];
}

static void fflog(void *context, int level, const char *format, va_list args){
#if fflogOn
    @autoreleasepool {
        NSString* message = [[NSString alloc] initWithFormat: [NSString stringWithUTF8String: format] arguments: args];
        NSLog(@"ff:%d%@",level,message);
    }
#endif
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        av_log_set_callback(fflog);//日志比较多，打开日志后会阻塞当前线程
        av_log_set_flags(AV_LOG_PANIC);
        
        ///初始化libavformat，注册所有文件格式，编解码库；这不是必须的，如果你能确定需要打开什么格式的文件，使用哪种编解码类型，也可以单独注册！
        av_register_all();
    }
    return self;
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

- (void)addRenderToSuperView:(UIView *)superView
{
#if RENDER == OPENGL
    OpenGLView20 *glView = [[OpenGLView20 alloc]initWithFrame:superView.bounds];
    [superView addSubview:glView];
    self.glView = glView;
    
    if (!CGSizeEqualToSize(_videoDimensions, CGSizeZero)) {
        CGSize vSize = superView.bounds.size;
        CGFloat vh = vSize.width * _videoDimensions.height / _videoDimensions.width;
        self.glView.frame = CGRectMake(0, (vSize.height-vh)/2, vSize.width , vh);
    }
#elif RENDER == IMAGE
    if (superView) {
        self.render = [[UIImageView alloc]init];
        self.render.frame = superView.bounds;
        self.render.contentMode = UIViewContentModeScaleAspectFit;
        [superView addSubview:self.render];
    }
#elif RENDER == LAYER
    self.sampleBufferDisplayLayer = [[AVSampleBufferDisplayLayer alloc] init];
    self.sampleBufferDisplayLayer.frame = superView.bounds;
    self.sampleBufferDisplayLayer.position = CGPointMake(CGRectGetMidX(superView.bounds), CGRectGetMidY(superView.bounds));
    self.sampleBufferDisplayLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    self.sampleBufferDisplayLayer.opaque = YES;
    [superView.layer addSublayer:self.sampleBufferDisplayLayer];
#endif
}

- (void)removeRenderFromSuperView
{
#if RENDER == OPENGL
    [self.glView removeFromSuperview];
    self.glView = nil;
#elif RENDER == IMAGE
    [self.render removeFromSuperview];
    self.render = nil;
#elif RENDER == LAYER
    [self.sampleBufferDisplayLayer removeFromSuperlayer];
    self.sampleBufferDisplayLayer = nil;
#endif
}

- (void)resetStatus
{
    _stream_index_audio = -1;
    _audioFrames = [NSMutableArray array];
    _videoFrames = [NSMutableArray array];
}

- (void)openAudioStream
{
    AVStream *stream = _formatCtx->streams[_stream_index_audio];
    [self openAudioStream:stream];
}

- (void)openVideoStream
{
    AVStream *stream = _formatCtx->streams[_stream_index_video];
    [self openVideoStream:stream];
}

- (BOOL)audioStreamValidate
{
    return _stream_index_audio != -1;
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
    
    avStreamFPSTimeBase(stream, 0.04, &_fps, &_videoTimeBase);
    
    int width = codecCtx->width;
    int height = codecCtx->height;
    
    _videoDimensions = CGSizeMake(width, height);
#if RENDER == OPENGL
    if (self.glView) {
        UIView *superView = self.glView.superview;
        CGSize vSize = superView.bounds.size;
        CGFloat vh = vSize.width * height / width;
        self.glView.frame = CGRectMake(0, (vSize.height-vh)/2, vSize.width , vh);
    }
#endif

}

- (void)openAudioStream:(AVStream *)stream
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
    
    if (![self audioCodecIsSupported:_audioCodecCtx]) {
        
        int64_t out_ch_layout = av_get_default_channel_layout(_audioCodecCtx->channels);
        int64_t in_ch_layout = av_get_default_channel_layout((int)_numOutputChannels);
        
        SwrContext *swrContext = swr_alloc_set_opts(NULL,
                                                     in_ch_layout,
                                                     AV_SAMPLE_FMT_S16,
                                                     _samplingRate,
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

#pragma mark - 打开流返回 AVFormatContext
- (AVFormatContext *)openInputForAVFormatContext:(NSString *)moviePath {
    
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

#pragma mark - 打开流

- (BOOL)openStream:(NSString *)url
{
    [self resetStatus];
    
    if ([url hasPrefix:@"http"]) {
        //Using network protocols without global network initialization. Please use avformat_network_init(), this will become mandatory later.
        //播放网络视频的时候，要首先初始化下网络模块。
        avformat_network_init();
    }
    
    AVFormatContext * formatCtx = [self openInputForAVFormatContext:url];
    
    if(formatCtx){
        
        /* 接下来，尝试找到我们关系的信息*/
        
        NSMutableString *text = [[NSMutableString alloc]init];
        
        /*AVFormatContext 的 streams 变量是个数组，里面存放了 nb_streams 个元素，每个元素都是一个 AVStream */
        [text appendFormat:@"共%u个流，%llds",formatCtx->nb_streams,formatCtx->duration/AV_TIME_BASE];
        
        //遍历所有的流
        for (unsigned int i = 0; i < formatCtx->nb_streams; i++) {
            
            AVStream *stream = formatCtx->streams[i];
            enum AVMediaType codec_type = stream->codec->codec_type;
            
            switch (codec_type) {
                    ///音频流
                case AVMEDIA_TYPE_AUDIO:
                {
                    //保存音频strema index.
                    _stream_index_audio = i;
                }
                    break;
                    ///视频流
                case AVMEDIA_TYPE_VIDEO:
                {
                    //保存视频strema index.
                    _stream_index_video = i;
                }
                    break;
                case AVMEDIA_TYPE_ATTACHMENT:
                {
                    NSLog(@"附加信息流:%u",i);
                }
                    break;
                default:
                {
                    NSLog(@"其他流:%u",i);
                }
                    break;
            }
        }
        
        _formatCtx = formatCtx;
        
        return YES;
    }else{
        return NO;
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

#pragma mark - read frame loop

- (void)readFrame
{
    if (!self.io_queue) {
        dispatch_queue_t io_queue = dispatch_queue_create("read-io", DISPATCH_QUEUE_SERIAL);
        self.io_queue = io_queue;
    }
    
    BOOL notNeedRead = NO;
    @synchronized(_audioFrames) {
        if (self.audioFrames.count > 5 && self.videoFrames.count > 5) {
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
            if(pkt.stream_index == _stream_index_audio){
                [self decodeAudioPacket:&pkt];
            }else if (pkt.stream_index == _stream_index_video) {
                
                _weakSelf_SL
                [self handleVideoPacket:&pkt completion:^(AVFrame *video_frame) {
                    _strongSelf_SL
                    
                    const double frameDuration = av_frame_get_pkt_duration(video_frame) * _videoTimeBase;
                    MRVideoFrame *frame = [[MRVideoFrame alloc]init];
                    frame.duration = frameDuration;
                    frame.frame = video_frame;
                    
                    @synchronized(self) {
                        [self.videoFrames addObject:frame];
                    }
                }];
            }
        }else{
            NSLog(@"eof,stop read more frame!");
            if (self.readFramesTimer) {
                [self.readFramesTimer invalidate];
            }
            [self pauseAudio];
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
#if use_v3
    int ret = avcodec_send_packet(_codecCtx, packet);
    if (ret != 0) {
        printf("avcodec_send_packet failed.\n");
    }
    AVFrame *video_frame = av_frame_alloc();//老版本是 avcodec_alloc_frame
    
    ret = avcodec_receive_frame(_codecCtx, video_frame);
    switch (ret) {
        case 0:
            while (ret==0) {
                completion(video_frame);
                ret = avcodec_receive_frame(_codecCtx, video_frame);
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
    
    int len = avcodec_decode_video2(_videoCodecCtx, video_frame, &gotframe, packet);
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

- (void)displayVideoFrame:(MRVideoFrame *)frame
{
    AVFrame *video_frame = frame.frame;
#if RENDER == OPENGL
    [self displayUseOpenGL:video_frame];
#elif RENDER == IMAGE
    [self displayUseImage:video_frame];
#elif RENDER == LAYER
    [self displayUseCVPixelBuffer:video_frame];
#endif
}

- (void)displayUseOpenGL:(AVFrame *)video_frame
{
    [self.glView displayYUV420pData:video_frame];
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

///音频渲染回调；
static inline OSStatus MRRenderCallback(void *inRefCon,
                                        AudioUnitRenderActionFlags    * ioActionFlags,
                                        const AudioTimeStamp          * inTimeStamp,
                                        UInt32                        inOutputBusNumber,
                                        UInt32                        inNumberFrames,
                                        AudioBufferList                * ioData)
{
    MRMoviePlayer *am = (__bridge MRMoviePlayer *)inRefCon;
    return [am renderFrames:inNumberFrames ioData:ioData];
}

- (void)activateAudioSession
{
#define kMax_Frame_Size     4096
#define kMax_Chan           2
#define kMax_Sample_Dumped  5
    
    _outData = (float *)calloc(kMax_Frame_Size * kMax_Chan, sizeof(float));
    
    _numOutputChannels = [[AVAudioSession sharedInstance]outputNumberOfChannels];
    _samplingRate = [[AVAudioSession sharedInstance]sampleRate];
    _outputVolume = [[AVAudioSession sharedInstance]outputVolume];
    
    {
        AVAudioSessionRouteDescription *routeDescription = [[AVAudioSession sharedInstance]currentRoute];
        NSArray *outputs = routeDescription.outputs;
        AVAudioSessionPortDescription *outPut = [outputs lastObject];
        _audioRoute = outPut.portName;
        
        [[AVAudioSession sharedInstance]setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker error:nil];
        //        [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(audioRouteChanged:) name:AVAudioSessionRouteChangeNotification object:nil];
        //        [[AVAudioSession sharedInstance]addObserver:self forKeyPath:@"outputVolume" options:NSKeyValueObservingOptionNew context:nil];
        
        [[AVAudioSession sharedInstance]setActive:YES error:nil];
    }
    
    {
        // ----- Audio Unit Setup -----
        
        // Describe the output unit.
        
        AudioComponentDescription desc = {0};
        desc.componentType = kAudioUnitType_Output;
        desc.componentSubType = kAudioUnitSubType_RemoteIO;
        desc.componentManufacturer = kAudioUnitManufacturer_Apple;
        
        // Get component
        AudioComponent component = AudioComponentFindNext(NULL, &desc);
        AudioComponentInstanceNew(component, &_audioUnit);
        UInt32 size;
        
        // Check the output stream format
        size = sizeof(AudioStreamBasicDescription);
        
        AudioUnitGetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &_outputFormat, &size);
        _outputFormat.mSampleRate = _samplingRate;
        
        AudioUnitSetProperty(_audioUnit,
                             kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Input,
                             0,
                             &_outputFormat, size);
        
        _numBytesPerSample = _outputFormat.mBitsPerChannel / 8;
        _numOutputChannels  = _outputFormat.mChannelsPerFrame;
        
        // Slap a render callback on the unit
        AURenderCallbackStruct callbackStruct;
        callbackStruct.inputProc = MRRenderCallback;
        callbackStruct.inputProcRefCon = (__bridge void *)(self);
        
        AudioUnitSetProperty(_audioUnit,
                             kAudioUnitProperty_SetRenderCallback,
                             kAudioUnitScope_Input,
                             0,
                             &callbackStruct,
                             sizeof(callbackStruct));
        
        AudioUnitInitialize(_audioUnit);
    }
}

- (BOOL)audioCodecIsSupported:(AVCodecContext *)audio
{
    if (audio->sample_fmt == AV_SAMPLE_FMT_S16) {
        
        return (int)_samplingRate == audio->sample_rate &&
        _numOutputChannels == audio->channels;
    }
    return NO;
}

- (void)fetchData:(float *)outData numFrames:(NSInteger) numFrames numChannels:(NSInteger) numChannels
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
                    
//                    NSLog(@"audio buffer frame:%lu",(unsigned long)[_audioFrames count]);
                    
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
        
        const int ratio = MAX(1, _samplingRate / _audioCodecCtx->sample_rate) *
        MAX(1, _numOutputChannels / _audioCodecCtx->channels) * 2;
        
        const int bufSize = av_samples_get_buffer_size(NULL,
                                                       (int)_numOutputChannels,
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

- (void)videoTick
{
    MRVideoFrame *videoFrame = nil;
    @synchronized(self) {
        
        //如果没有缓冲好，那么就每隔0.1s过来看下buffer
        if ([self.videoFrames count] < 3) {
            _weakSelf_SL
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                _strongSelf_SL
                [self videoTick];
            });
            return;
        }
        
        videoFrame = [self.videoFrames firstObject];
        [self.videoFrames removeObjectAtIndex:0];
    }
    
    float interval = videoFrame.duration;
    [self displayVideoFrame:videoFrame];
    const NSTimeInterval time = MAX(interval, 0.01);
    //    NSLog(@"after %fs tick",time);
    
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, time * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self videoTick];
    });
}

- (void)audioTick
{
    //如果没有缓冲好，那么就每隔0.1s过来看下buffer
    if ([self.audioFrames count] < 3) {
        _weakSelf_SL
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            _strongSelf_SL
            [self audioTick];
        });
        return;
    }
    MRAudioFrame *audioFrame = [self.audioFrames firstObject];
    float interval = audioFrame.duration;
    
    _currentPlayPosition = audioFrame.position;
    
    ///设置下标志位，音频那边就可以取数据了；
    self.canGiveFrame = YES;
    [self playAudio];
    const NSTimeInterval time = MAX(interval, 0.01);
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, time * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self audioTick];
    });
}

@end

