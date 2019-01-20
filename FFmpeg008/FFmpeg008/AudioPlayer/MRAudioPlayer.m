//
//  MRAudioPlayer.m
//  FFmpeg008
//
//  Created by Matt Reach on 2018/2/21.
//  Copyright © 2018年 Awesome FFmpeg Study Demo. All rights reserved.
//  开源地址: https://github.com/debugly/StudyFFmpeg

#import "MRAudioPlayer.h"

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

#ifndef __weakSelf__
#define __weakSelf__     __weak   __typeof(self) $weakself = self;
#endif

#ifndef __strongSelf__
#define __strongSelf__   __strong __typeof($weakself) self = $weakself;
#endif

@interface MRAudioPlayer ()

@property (assign, nonatomic) AVFormatContext *formatCtx;
@property (strong, nonatomic) dispatch_queue_t read_queue;
@property (strong, nonatomic) dispatch_queue_t decode_queue;

@property (assign, nonatomic) unsigned int stream_index_audio;
@property (nonatomic,copy) NSString *audioRoute;
@property (nonatomic,assign) double  samplingRate;
@property (nonatomic,assign) UInt32   numBytesPerSample;
@property (nonatomic,assign) float  outputVolume;

@property (nonatomic,assign) AudioUnit audioUnit;
@property (nonatomic,assign) AudioStreamBasicDescription outputFormat;
@property (nonatomic,assign) NSInteger   numOutputChannels;
@property (nonatomic,assign) float    *outData;

@property (strong, nonatomic) NSMutableArray<MRAudioFrame *> *audioPackets;
@property (strong, nonatomic) NSMutableArray<MRAudioFrame *> *audioFrames;

@property (nonatomic,assign) AVCodecContext *audioCodecCtx;
@property (nonatomic,assign) SwrContext  *swrContext;
@property (nonatomic,assign) uint8_t     *swrBuffer;
@property (nonatomic,assign) NSUInteger  swrBufferSize;
@property (nonatomic,assign) CGFloat     audioTimeBase;

@property (nonatomic,strong) MRAudioFrame *currentAudioFrame;
@property (nonatomic,assign) NSUInteger    currentAudioFramePos;

@property (nonatomic,assign) BOOL isPalying;///audio unit 是否开始
@property (nonatomic,assign) BOOL readingAVFrame;
@property (nonatomic,assign) BOOL readEOF;
@property (nonatomic,assign) BOOL decoding;
@property (nonatomic,assign) BOOL bufferOk;
@property (nonatomic,assign) BOOL activity;

@end

@implementation MRAudioPlayer

static void fflog(void *context, int level, const char *format, va_list args){
    //    @autoreleasepool {
    //        NSString* message = [[NSString alloc] initWithFormat: [NSString stringWithUTF8String: format] arguments: args];
    //
    //        NSLog(@"ff:%d%@",level,message);
    //    }
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _audioPackets = [NSMutableArray array];
        _audioFrames = [NSMutableArray array];
    }
    return self;
}

- (void)dealloc
{
    if (NULL != _formatCtx) {
        avformat_close_input(&_formatCtx);
    }
}

- (void)playURLString:(NSString *)url
{
    _stream_index_audio = -1;
    self.activity = YES;
    
    ///初始化音频配置
    [self activateAudioSession];
    
    av_log_set_callback(fflog);//日志比较多，打开日志后会阻塞当前线程
    //av_log_set_flags(AV_LOG_SKIP_REPEATED);
    
    __weakSelf__
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        ///初始化libavformat，注册所有文件格式，编解码库；这不是必须的，如果你能确定需要打开什么格式的文件，使用哪种编解码类型，也可以单独注册！
        av_register_all();
        
        ///该地址可以是网络的也可以是本地的；
        if ([url hasPrefix:@"http"]) {
            //Using network protocols without global network initialization. Please use avformat_network_init(), this will become mandatory later.
            //播放网络视频的时候，要首先初始化下网络模块。
            avformat_network_init();
        }
        
        [self openStreamWithPath:url completion:^(AVFormatContext *formatCtx){
            
            __strongSelf__
            
            if(formatCtx){
                
                self.formatCtx = formatCtx;
                
                BOOL succ = [self openAudioStream];
                if (succ) {
                    [self startReadFrames];
                    [self audioTick];
                    return;
                }
            }
            
            ///default
            {
                NSLog(@"不能打开流");
            }
        }];
    });
}

#pragma mark - Open Stream

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

#pragma mark - Open Audio Stream

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
            return NO;
        }
        _swrContext = swrContext;
    }
    avStreamFPSTimeBase(stream, 0.025, 0, &_audioTimeBase);
    return YES;
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

#pragma mark - Read Frame Loop

///缓冲 10s 的package！
- (BOOL)checkIsBufferEnoughPackages
{
    float buffedDuration = 0.0;
    static float kMinBufferDuration = 10;
    @synchronized(self) {
        NSArray *audioPackets = [self.audioPackets copy];
        
        for (MRAudioFrame *frame in audioPackets) {
            buffedDuration += frame.duration;
            if (buffedDuration >= kMinBufferDuration) {
                break;
            }
        }
    }
    
    NSLog(@"buffed package:%0.2f",buffedDuration);
    return buffedDuration >= kMinBufferDuration;
}

- (void)startReadFrames
{
    if (self.readEOF) {
        return;
    }
    
    if (!self.activity) {
        return;
    }
    
    if(self.readingAVFrame){
        return;
    }
    self.readingAVFrame = YES;
    
    if (!self.read_queue) {
        dispatch_queue_t read_queue = dispatch_queue_create("read-io", DISPATCH_QUEUE_SERIAL);
        self.read_queue = read_queue;
    }
    
    NSLog(@"==========================================startReadFrames");
    
    __weakSelf__
    dispatch_async(self.read_queue, ^{
        
        while (![self checkIsBufferEnoughPackages]) {
            if (!self.activity) {
                return;
            }
            NSLog(@"continue read frame");
            NSTimeInterval begin = CFAbsoluteTimeGetCurrent();
            
            AVPacket pkt;
            __strongSelf__
            if (av_read_frame(_formatCtx,&pkt) >= 0) {
                if (pkt.stream_index == self.stream_index_audio) {
                    NSTimeInterval end = CFAbsoluteTimeGetCurrent();
                    NSLog(@"read frame:%0.6f",end-begin);
                    
                    MRAudioFrame *frame = [[MRAudioFrame alloc]init];
                    frame.packet = &pkt;
                    double frameDuration = frame.packet->duration * self.audioTimeBase;
                    frame.duration = frameDuration;
                    [self enDecodeQueue:frame];
                }
            }else{
                NSLog(@"没有包可读了，读包停止！");
                MRAudioFrame *frame = [[MRAudioFrame alloc]init];
                frame.eof = YES;
                @synchronized(self) {
                    self.readEOF = YES;
                    [self.audioPackets addObject:frame];
                }
                break;
            }
            ///释放内存
            av_packet_unref(&pkt);
        }
        
        self.readingAVFrame = NO;
        
        NSLog(@"==========================================endReadFrames");
    });
}

#pragma mark - Decode Audio Packet

- (void)enDecodeQueue:(MRAudioFrame *)packet
{
    @synchronized(self) {
        [self.audioPackets addObject:packet];
        NSLog(@"read packet succ;pk sum:%lu",(unsigned long)[self.audioPackets count]);
    }
    [self startDecodeLoop];
}

///解码缓冲 2s，够 2s 就开始播放
- (BOOL)checkIsBufferEnoughFrames
{
    float buffedDuration = 0.0;
    static float kMinBufferDuration = 2;
    
    @synchronized(self) {
        NSArray *audioFrames = [self.audioFrames copy];
        
        for (MRAudioFrame *frame in audioFrames) {
            buffedDuration += frame.duration;
            if (buffedDuration >= kMinBufferDuration) {
                break;
            }
        }
    }
    NSLog(@"buffed frame:%0.2f",buffedDuration);
    return buffedDuration >= kMinBufferDuration;
}

- (void)startDecodeLoop
{
    if (!self.activity) {
        return;
    }
    
    if (self.decoding) {
        return;
    }
    
    self.decoding = YES;
    
    NSLog(@"==========================================startDecodeLoop");
    
    if (!self.decode_queue) {
        dispatch_queue_t decode_queue = dispatch_queue_create("decode-io", DISPATCH_QUEUE_SERIAL);
        self.decode_queue = decode_queue;
    }
    
    __weakSelf__
    dispatch_async(self.decode_queue, ^{
        __strongSelf__
        while (![self checkIsBufferEnoughFrames]) {
            
            if (!self.activity) {
                return;
            }
            NSLog(@"continue decode");
            ///每次开始解码之前，都check下缓冲的package是否足够！
            [self startReadFrames];
            
            MRAudioFrame *frame = nil;
            @synchronized(self) {
                frame = [self.audioPackets firstObject];
                if(frame){
                    [self.audioPackets removeObjectAtIndex:0];
                    NSLog(@"consume a package;pk sum:%lu",(unsigned long)[self.audioPackets count]);
                }
            }
            
            if (!frame) {
                NSLog(@"no frame to decode,break");
                break;
            }
            
            [self decodeAudioPacket:frame];
        }
        
        ///满了，可以播放了！
        if (!self.bufferOk) {
            self.bufferOk = [self checkIsBufferEnoughFrames];
        }
        self.decoding = NO;
        
        NSLog(@"==========================================endDecodeLoop");
    });
}

- (BOOL)decodeAudioPacket:(MRAudioFrame *)frame
{
    if (frame.eof) {
        return YES;
    }
    AVPacket *packet = frame.packet;
    int pktSize = (*packet).size;
    
    NSMutableArray *frames = [NSMutableArray array];
    while (pktSize > 0) {
        
        int gotframe = 0;
        AVFrame *audio_Frame = av_frame_alloc();//老版本是 avcodec_alloc_frame
        int len = avcodec_decode_audio4(_audioCodecCtx,
                                        audio_Frame,
                                        &gotframe,
                                        packet);
        
        if (gotframe && len > 0) {
            
            MRAudioFrame *aFrame = [MRAudioFrame new];
            aFrame.frame = audio_Frame;
            
            av_frame_free(&audio_Frame);
            audio_Frame = NULL;
            
            BOOL succ = [self handleAudioFrame:aFrame];
            if (succ) {
                [frames addObject:aFrame];
            }
        }else{
            av_frame_free(&audio_Frame);
            audio_Frame = NULL;
            
            NSLog(@"decode audio error, skip packet");
            break;
        }
        pktSize -= len;
    }
    
    if ([frames count] > 0) {
        @synchronized(self) {
            ///加入到frame队列；
            [self.audioFrames addObjectsFromArray:frames];
            NSLog(@"decode succ;frame sum:%lu",(unsigned long)[self.audioFrames count]);
        }
        return YES;
    }else{
        NSLog(@"this pkt decode 0 frame ;frame sum:%lu",(unsigned long)[self.audioFrames count]);
    }
    
    return NO;
}

#pragma mark - Audio

- (void) pauseAudio
{
    if (self.isPalying) {
        AudioOutputUnitStop(_audioUnit);
        self.isPalying = NO;
    }
}

- (void) playAudio
{
    if (!self.isPalying) {
        AudioOutputUnitStart(_audioUnit);
        self.isPalying = YES;
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
    MRAudioPlayer *am = (__bridge MRAudioPlayer *)inRefCon;
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
        
        return  (int)_samplingRate == audio->sample_rate &&
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
            
            @synchronized(self){
                ///没有读到文件末尾，或者pkt队列不空，那么就有必要触发解码逻辑！
                if (!self.readEOF || [self.audioPackets count] != 0) {
                    __weakSelf__
                    dispatch_async(dispatch_get_main_queue(), ^{
                        __strongSelf__
                        [self startDecodeLoop];
                    });
                }else{
                    NSLog(@"没有包可供解码了，解码器停止！");
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

- (BOOL)handleAudioFrame:(MRAudioFrame *)frame
{
    AVFrame *audio_Frame = frame.frame;
    if (!audio_Frame || !audio_Frame->data[0]){
        return NO;
    }
    
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
        
        numFrames = swr_convert(_swrContext,
                                &_swrBuffer,
                                audio_Frame->nb_samples * ratio,
                                (const uint8_t **)audio_Frame->data,
                                audio_Frame->nb_samples);
        
        if (numFrames < 0) {
            NSLog(@"fail resample audio");
            return NO;
        }
        
        //int64_t delay = swr_get_delay(_swrContext, audioManager.samplingRate);
        //if (delay > 0)
        //    LoggerAudio(0, @"resample delay %lld", delay);
        
        audioData = _swrBuffer;
        
    } else {
        
        if (_audioCodecCtx->sample_fmt != AV_SAMPLE_FMT_S16) {
            NSAssert(false, @"bucheck, audio format is invalid");
            return NO;
        }
        
        audioData = audio_Frame->data[0];
        numFrames = audio_Frame->nb_samples;
    }
    
    const NSUInteger numElements = numFrames * numChannels;
    NSMutableData *data = [NSMutableData dataWithLength:numElements * sizeof(float)];
    
    float scale = 1.0 / (float)INT16_MAX ;
    vDSP_vflt16((SInt16 *)audioData, 1, data.mutableBytes, 1, numElements);
    vDSP_vsmul(data.mutableBytes, 1, &scale, data.mutableBytes, 1, numElements);
    
    frame.position = av_frame_get_best_effort_timestamp(audio_Frame) * _audioTimeBase;
    frame.duration = av_frame_get_pkt_duration(audio_Frame) * _audioTimeBase;
    frame.samples = [data copy];
    
    if (frame.duration == 0) {
        // sometimes ffmpeg can't determine the duration of audio frame
        // especially of wma/wmv format
        // so in this case must compute duration
        frame.duration = frame.samples.length / (sizeof(float) * numChannels * _samplingRate);
    }
    
    frame.frame = nil;
    
//    NSLog(@"frame duration:%.6f,%ld",frame.duration,data.length);
    
    return YES;
}

# pragma mark - 播放速度控制

- (void)audioTick
{
    if (!self.activity) {
        return;
    }
    
    if (self.bufferOk) {
        ///驱动解码loop
        [self startDecodeLoop];
        [self playAudio];
    }else{
        [self pauseAudio];
        self.bufferOk = NO;
        __weakSelf__
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.5 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            __strongSelf__
            [self audioTick];
        });
    }
}

- (void)stop
{
    self.activity = NO;
    AudioOutputUnitStop(_audioUnit);
}

@end

