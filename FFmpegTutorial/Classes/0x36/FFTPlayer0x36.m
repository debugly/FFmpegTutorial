//
//  FFTPlayer0x36.m
//  FFmpegTutorial
//
//  Created by qianlongxu on 2022/7/25.
//

#import "FFTPlayer0x36.h"
#import "FFTThread.h"
#import "FFTPlayerHeader.h"
#import <libavutil/pixdesc.h>
#import <libavutil/time.h>
#import <libavutil/frame.h>
#import <libavformat/avformat.h>
#import "FFTDecoder.h"
#import "FFTVideoScale.h"
#import "FFTAudioResample.h"
#import "FFTDispatch.h"
#import "FFTPacketQueue.h"
#import "FFTVideoRenderer.h"
#import "FFTAudioRenderer.h"
#import "FFTAudioFrameQueue.h"
#import "FFTVideoFrameQueue.h"
#import "FFTSyncClock.h"
#import "FFTAbstractLogger.h"

//视频宽；单位像素
kFFTPlayer0x36InfoKey kFFTPlayer0x36Width = @"kFFTPlayer0x36Width";
//视频高；单位像素
kFFTPlayer0x36InfoKey kFFTPlayer0x36Height = @"kFFTPlayer0x36Height";
//视频时长；单位秒
kFFTPlayer0x36InfoKey kFFTPlayer0x36Duration = @"kFFTPlayer0x36Duration";

//将音频裸流PCM写入到文件
#define DEBUG_RECORD_PCM_TO_FILE 0

@interface  FFTPlayer0x36 ()<FFTDecoderDelegate>
{
    //音频流解码器
    FFTDecoder *_audioDecoder;
    //视频流解码器
    FFTDecoder *_videoDecoder;
    
    //图像格式转换/缩放器
    FFTVideoScale *_videoScale;
    //音频重采样
    FFTAudioResample *_audioResample;
    
    FFTPacketQueue *_packetQueue;
    
    FFTVideoFrameQueue *_videoFrameQueue;
    FFTAudioFrameQueue *_audioFrameQueue;
    //音频渲染
    FFTAudioRenderer *_audioRender;
    
    FFTSyncClock *_audioClk;
    FFTSyncClock *_videoClk;
    //视频尺寸
    CGSize _videoSize;
    AVFormatContext * _formatCtx;
    //音频frame已经读的数据
    int _audioFrameRead;
    //读包完毕？
    int _eof;
    BOOL _isPlaying;
    float _duration;
    float _audioPos;
    
#if DEBUG_RECORD_PCM_TO_FILE
    FILE * file_pcm_l;
    FILE * file_pcm_r;
#endif
}

//读包线程
@property (nonatomic, strong) FFTThread *readThread;
@property (nonatomic, strong) FFTThread *decoderThread;
@property (nonatomic, strong) FFTThread *videoThread;

@property (atomic, assign) int abort_request;
@property (nonatomic, copy) dispatch_block_t onErrorBlock;
@property (atomic, assign, readwrite) int videoPktCount;
@property (atomic, assign, readwrite) int audioPktCount;
@property (atomic, assign, readwrite) int videoFrameCount;
@property (atomic, assign, readwrite) int audioFrameCount;

@end

@implementation  FFTPlayer0x36

static int decode_interrupt_cb(void *ctx)
{
    FFTPlayer0x36 *player = (__bridge FFTPlayer0x36 *)ctx;
    return player.abort_request;
}

- (void)_stop
{
    self.abort_request = 1;
    [_packetQueue cancel];
    [_videoFrameQueue cancel];
    [_audioFrameQueue cancel];
    
    [self stopAudio];
    
#if DEBUG_RECORD_PCM_TO_FILE
    [self close_all_file];
#endif
    //避免重复stop做无用功
    if (self.readThread) {
        [self.readThread cancel];
        [self.readThread join];
    }
    
    if (self.decoderThread) {
        [self.decoderThread cancel];
        [self.decoderThread join];
    }
    
    if (self.videoThread) {
        [self.videoThread cancel];
        [self.videoThread join];
    }
    
    //读包线程结束了，销毁下相关结构体
    avformat_close_input(&_formatCtx);
    [self performSelectorOnMainThread:@selector(didStop:) withObject:self waitUntilDone:YES];
}

- (void)didStop:(id)sender
{
    self.readThread = nil;
    self.decoderThread = nil;
    self.videoThread = nil;
}

- (void)dealloc
{
    PRINT_DEALLOC;
}

#pragma -mark 读包线程
//读包循环
- (void)readPacketLoop:(AVFormatContext *)formatCtx
{
    AVPacket pkt1, *pkt = &pkt1;
    //创建一个frame就行了，可以复用
    AVFrame *frame = av_frame_alloc();
    //循环读包
    for (;;) {
        
        //调用了stop方法，则不再读包
        if (self.abort_request) {
            break;
        }
        
        //读包
        int ret = av_read_frame(formatCtx, pkt);
        //读包出错
        if (ret < 0) {
            //读到最后结束了
            if ((ret == AVERROR_EOF || avio_feof(formatCtx->pb))) {
                //标志为读包结束
                av_log(NULL, AV_LOG_DEBUG, "stream eof:%s\n",formatCtx->url);
                //send null packet,let decoder eof.
                pkt->data = NULL;
                pkt->size = 0;
                pkt->stream_index = _videoDecoder.streamIdx;
                [_packetQueue enQueue:pkt];
                pkt->stream_index = _audioDecoder.streamIdx;
                [_packetQueue enQueue:pkt];
                _packetQueue.eof = YES;
                break;
            }
            
            if (formatCtx->pb && formatCtx->pb->error) {
                break;
            }
            
            /* wait 10 ms */
            mr_msleep(10);
            continue;
        } else {
            AVStream *stream = _formatCtx->streams[pkt->stream_index];
            switch (stream->codecpar->codec_type) {
                case AVMEDIA_TYPE_VIDEO:
                {
                    if (pkt->data != NULL) {
                        self.videoPktCount++;
                    }
                    [_packetQueue enQueue:pkt];
                }
                    break;
                case AVMEDIA_TYPE_AUDIO:
                {
                    if (pkt->data != NULL) {
                        self.audioPktCount++;
                    }
                    [_packetQueue enQueue:pkt];
                }
                    break;
                default:
                    break;
            }
            if (self.onReadPkt) {
                self.onReadPkt(self.audioPktCount,self.videoPktCount);
            }
        }
    }
    
    av_frame_free(&frame);
}

#pragma mark - 查找最优的音视频流
- (void)findBestStreams:(AVFormatContext *)formatCtx result:(int (*) [AVMEDIA_TYPE_NB])st_index {

    int first_video_stream = -1;
    int first_h264_stream = -1;
    //查找H264格式的视频流
    for (int i = 0; i < formatCtx->nb_streams; i++) {
        AVStream *st = formatCtx->streams[i];
        enum AVMediaType type = st->codecpar->codec_type;
        st->discard = AVDISCARD_ALL;

        if (type == AVMEDIA_TYPE_VIDEO) {
            enum AVCodecID codec_id = st->codecpar->codec_id;
            if (codec_id == AV_CODEC_ID_H264) {
                if (first_h264_stream < 0) {
                    first_h264_stream = i;
                    break;
                }
                if (first_video_stream < 0) {
                    first_video_stream = i;
                }
            }
        }
    }
    //h264优先
    (*st_index)[AVMEDIA_TYPE_VIDEO] = first_h264_stream != -1 ? first_h264_stream : first_video_stream;
    //根据上一步确定的视频流查找最优的视频流
    (*st_index)[AVMEDIA_TYPE_VIDEO] = av_find_best_stream(formatCtx, AVMEDIA_TYPE_VIDEO, (*st_index)[AVMEDIA_TYPE_VIDEO], -1, NULL, 0);
    //参照视频流查找最优的音频流
    (*st_index)[AVMEDIA_TYPE_AUDIO] = av_find_best_stream(formatCtx, AVMEDIA_TYPE_AUDIO, (*st_index)[AVMEDIA_TYPE_AUDIO], (*st_index)[AVMEDIA_TYPE_VIDEO], NULL, 0);
}

- (void)readPacketsFunc
{
    NSParameterAssert(self.contentPath);
        
    if (![self.contentPath hasPrefix:@"/"]) {
        avformat_network_init();
    }
    
    AVFormatContext *formatCtx = avformat_alloc_context();
    
    if (!formatCtx) {
        self.error = _make_nserror_desc(FFPlayerErrorCode_AllocFmtCtxFailed, @"创建 AVFormatContext 失败！");
        [self performErrorResultOnMainThread];
        return;
    }
    
    formatCtx->interrupt_callback.callback = decode_interrupt_cb;
    formatCtx->interrupt_callback.opaque = (__bridge void *)self;
    
    /*
     打开输入流，读取文件头信息，不会打开解码器；
     */
    //低版本是 av_open_input_file 方法
    const char *moviePath = [self.contentPath cStringUsingEncoding:NSUTF8StringEncoding];
    
    //打开文件流，读取头信息；
    if (0 != avformat_open_input(&formatCtx, moviePath , NULL, NULL)) {
        //释放内存
        avformat_free_context(formatCtx);
        //当取消掉时，不给上层回调
        if (self.abort_request) {
            return;
        }
        self.error = _make_nserror_desc(FFPlayerErrorCode_OpenFileFailed, @"文件打开失败！");
        [self performErrorResultOnMainThread];
        return;
    }
    
    /* 刚才只是打开了文件，检测了下文件头而已，并不知道流信息；因此开始读包以获取流信息
     设置读包探测大小和最大时长，避免读太多的包！
    */
    formatCtx->probesize = 500 * 1024;
    formatCtx->max_analyze_duration = 5 * AV_TIME_BASE;
#if DEBUG
    NSTimeInterval begin = [[NSDate date] timeIntervalSinceReferenceDate];
#endif
    if (0 != avformat_find_stream_info(formatCtx, NULL)) {
        avformat_close_input(&formatCtx);
        self.error = _make_nserror_desc(FFPlayerErrorCode_StreamNotFound, @"不能找到流！");
        [self performErrorResultOnMainThread];
        //出错了，销毁下相关结构体
        avformat_close_input(&formatCtx);
        return;
    }
    
#if DEBUG
    NSTimeInterval end = [[NSDate date] timeIntervalSinceReferenceDate];
    //用于查看详细信息，调试的时候打出来看下很有必要
    av_dump_format(formatCtx, 0, moviePath, false);
    
    MRFF_DEBUG_LOG(@"avformat_find_stream_info coast time:%g",end-begin);
#endif
    
    //确定最优的音视频流
    int st_index[AVMEDIA_TYPE_NB];
    memset(st_index, -1, sizeof(st_index));
    [self findBestStreams:formatCtx result:&st_index];
    
    //打开解码器，创建解码线程
    if (st_index[AVMEDIA_TYPE_AUDIO] >= 0){
        _audioDecoder = [self openStreamComponent:formatCtx streamIdx:st_index[AVMEDIA_TYPE_AUDIO]];
        if (!_audioDecoder) {
            av_log(NULL, AV_LOG_ERROR, "can't open audio stream.");
            self.error = _make_nserror_desc(FFPlayerErrorCode_AudioDecoderOpenFailed, @"音频解码器打开失败！");
            [self performErrorResultOnMainThread];
            //出错了，销毁下相关结构体
            avformat_close_input(&formatCtx);
            return;
        } else {
            _audioResample = [self createAudioResampleIfNeed];
        }
    }
    
    NSMutableDictionary *dumpDic = [NSMutableDictionary dictionary];
    
    if (st_index[AVMEDIA_TYPE_VIDEO] >= 0){
        _videoDecoder = [self openStreamComponent:formatCtx streamIdx:st_index[AVMEDIA_TYPE_VIDEO]];
        if (!_videoDecoder) {
            av_log(NULL, AV_LOG_ERROR, "can't open video stream.");
            self.error = _make_nserror_desc(FFPlayerErrorCode_VideoDecoderOpenFailed, @"音频解码器打开失败！");
            [self performErrorResultOnMainThread];
            //出错了，销毁下相关结构体
            avformat_close_input(&formatCtx);
            return;
        } else {
            _videoSize = CGSizeMake(_videoDecoder.picWidth, _videoDecoder.picHeight);
            [dumpDic setObject:@(_videoDecoder.picWidth) forKey:kFFTPlayer0x36Width];
            [dumpDic setObject:@(_videoDecoder.picHeight) forKey:kFFTPlayer0x36Height];
            _videoScale = [self createVideoScaleIfNeed];
        }
    }

    _videoFrameQueue = [[FFTVideoFrameQueue alloc] init];
    _videoFrameQueue.streamTimeBase = av_q2d(_videoDecoder.stream->time_base);
    _videoFrameQueue.averageDuration = (_videoDecoder.frameRate.num && _videoDecoder.frameRate.den ? av_q2d(_videoDecoder.frameRate) : 0);

    _audioFrameQueue = [[FFTAudioFrameQueue alloc] init];
    _videoClk = [[FFTSyncClock alloc] init];
    _videoClk.name = @"video";
    _audioClk = [[FFTSyncClock alloc] init];
    _audioClk.name = @"audio";
    
    _duration = 1.0 * formatCtx->duration / AV_TIME_BASE;
    [dumpDic setObject:@(_duration) forKey:kFFTPlayer0x36Duration];
    
    mr_sync_main_queue(^{
        //audio queue 不能跨线程，不可以在子线程创建，主线程play。audio unit 可以
        [self setupAudioRender];
        if (self.onStreamOpened) {
            self.onStreamOpened(dumpDic);
        }
    });
    
    _formatCtx = formatCtx;
    [self.decoderThread start];
    //[self.videoThread start];
    //循环读包
    [self readPacketLoop:formatCtx];
}

#pragma mark - 视频像素格式转换

- (FFTVideoScale *)createVideoScaleIfNeed
{
    //未指定期望像素格式
    if (self.supportedPixelFormat == MR_PIX_FMT_NONE) {
        NSAssert(NO, @"supportedPixelFormats can't be none!");
        return nil;
    }
    
    //当前视频的像素格式
    const enum AVPixelFormat format = _videoDecoder.format;
    
    bool matched = false;
    MRPixelFormat firstSupportedFmt = MR_PIX_FMT_NONE;
    for (int i = MR_PIX_FMT_BEGIN; i <= MR_PIX_FMT_END; i ++) {
        const MRPixelFormat fmt = i;
        if (self.supportedPixelFormat == fmt) {
            if (firstSupportedFmt == MR_PIX_FMT_NONE) {
                firstSupportedFmt = fmt;
            }
            
            if (format == MRPixelFormat2AV(fmt)) {
                matched = true;
                break;
            }
        }
    }
    
    if (matched) {
        //期望像素格式包含了当前视频像素格式，则直接使用当前格式，不再转换。
        return nil;
    }
    
    if (firstSupportedFmt == MR_PIX_FMT_NONE) {
        NSAssert(NO, @"supportedPixelFormats is invalid!");
        return nil;
    }
    
    int dest = MRPixelFormat2AV(firstSupportedFmt);
    if ([FFTVideoScale checkCanConvertFrom:format to:dest]) {
        //创建像素格式转换上下文
        av_log(NULL, AV_LOG_INFO, "will scale %d to %d (%dx%d)",format,dest,_videoDecoder.picWidth,_videoDecoder.picHeight);
        FFTVideoScale *scale = [[FFTVideoScale alloc] initWithSrcPixFmt:format dstPixFmt:dest picWidth:_videoDecoder.picWidth picHeight:_videoDecoder.picHeight];
        return scale;
    } else {
        NSAssert(NO, @"can't scale from %d to %d",format,dest);
        return nil;
    }
}

//音频重采样
- (FFTAudioResample *)createAudioResampleIfNeed
{
    //未指定期望音频格式
    if (self.supportedSampleFormat == MR_SAMPLE_FMT_NONE) {
        NSAssert(NO, @"supportedSampleFormats can't be none!");
        return nil;
    }
    
    //未指定支持的比特率就使用目标音频的
    if (self.supportedSampleRate == 0) {
        self.supportedSampleRate = _audioDecoder.sampleRate;
    }
    
    //当前视频的像素格式
    const enum AVSampleFormat format = _audioDecoder.format;
    
    bool matched = false;
    MRSampleFormat firstSupportedFmt = MR_SAMPLE_FMT_NONE;
    for (int i = MR_SAMPLE_FMT_BEGIN; i <= MR_SAMPLE_FMT_END; i ++) {
        const MRSampleFormat fmt = i;
        if (self.supportedSampleFormat == fmt) {
            if (firstSupportedFmt == MR_SAMPLE_FMT_NONE) {
                firstSupportedFmt = fmt;
            }
            
            if (format == MRSampleFormat2AV(fmt)) {
                matched = true;
                break;
            }
        }
    }
    
    if (matched) {
        //采样率不匹配
        if (self.supportedSampleRate != _audioDecoder.sampleRate) {
            firstSupportedFmt = AVSampleFormat2MR(format);
            matched = NO;
        }
    }
    
    if (matched) {
        //期望音频格式包含了当前音频格式，则直接使用当前格式，不再转换。
        av_log(NULL, AV_LOG_INFO, "audio not need resample!\n");
        return nil;
    }
    
    if (firstSupportedFmt == MR_SAMPLE_FMT_NONE) {
        NSAssert(NO, @"supportedSampleFormats is invalid!");
        return nil;
    }
    
    //创建音频格式转换上下文
    FFTAudioResample *resample = [[FFTAudioResample alloc] initWithSrcSampleFmt:format
                                                                         dstSampleFmt:MRSampleFormat2AV(firstSupportedFmt)
                                                                   srcChannel:_audioDecoder.channelLayout
                                                                           dstChannel:_audioDecoder.channelLayout
                                                                              srcRate:_audioDecoder.sampleRate
                                                                              dstRate:self.supportedSampleRate];
    return resample;
}

#pragma mark - 解码


- (FFTDecoder *)openStreamComponent:(AVFormatContext *)ic streamIdx:(int)idx
{
    FFTDecoder *decoder = [FFTDecoder new];
    decoder.ic = ic;
    decoder.streamIdx = idx;
    if ([decoder open] == 0) {
        decoder.delegate = self;
        return decoder;
    } else {
        return nil;
    }
}

- (void)decodePkt:(AVPacket *)pkt
{
    AVStream *stream = _formatCtx->streams[pkt->stream_index];
    switch (stream->codecpar->codec_type) {
        case AVMEDIA_TYPE_VIDEO:
        {
            [_videoDecoder sendPacket:pkt];
        }
            break;
        case AVMEDIA_TYPE_AUDIO:
        {
            [_audioDecoder sendPacket:pkt];
        }
            break;
        default:
            break;
    }
}

- (void)decoderFunc
{
    while (!self.abort_request) {
        __weakSelf__
        [_packetQueue deQueue:^(AVPacket * pkt) {
            __strongSelf__
            if (pkt) {
                [self decodePkt:pkt];
            }
        }];
    }
}

#pragma mark - FFTDecoderDelegate

- (void)decoder:(FFTDecoder *)decoder reveivedAFrame:(AVFrame *)aFrame
{
    if (decoder == _audioDecoder) {
        AVFrame *audioFrame = nil;
        if (_audioResample) {
            if (![_audioResample resampleFrame:aFrame out:&audioFrame]) {
                self.error = _make_nserror_desc(FFPlayerErrorCode_ResampleFrameFailed, @"音频帧重采样失败！");
                [self performErrorResultOnMainThread];
                return;
            }
        } else {
            audioFrame = aFrame;
        }
        
        self.audioFrameCount++;
        [self enQueueAudioFrame:audioFrame];
    } else if (decoder == _videoDecoder) {
        AVFrame *videoFrame = nil;
        if (_videoScale) {
            if (![_videoScale rescaleFrame:aFrame out:&videoFrame]) {
                self.error = _make_nserror_desc(FFPlayerErrorCode_RescaleFrameFailed, @"视频帧重转失败！");
                [self performErrorResultOnMainThread];
                return;
            }
        } else {
            videoFrame = aFrame;
        }
        
        self.videoFrameCount++;
        [self enQueueVideoFrame:videoFrame];
    }
}

- (void)decoderEof:(FFTDecoder *)decoder
{
    if (decoder == _audioDecoder) {
        _audioFrameQueue.eof = YES;
    } else if (decoder == _videoDecoder) {
        _videoFrameQueue.eof = YES;
    }
}

#pragma - mark Video

- (void)doDisplayVideoFrame:(FFFrameItem *)vp
{
    if (!vp) {
        return;
    }
    
    [[self _videoRender] displayAVFrame:vp.frame];
}

- (double)vp_duration:(FFFrameItem *)p1 current:(FFFrameItem *)p2
{
    if (p1 && p2) {
        double duration = p2.pts - p1.pts;
        if (duration <= 0 || duration > 10){
            return p1.duration;
        } else {
            return duration;
        }
    } else if (p1){
        return p1.duration;
    } else {
        return 0.0;
    }
}

- (void)video_refresh:(double *)remaining_time
{
    //上一帧
    FFFrameItem *lastvp = [_videoFrameQueue peekLast];
    
    if (![self isPlaying]) {
        //仍旧显示上一帧
        [self doDisplayVideoFrame:lastvp];
        return;
    }
    
    if ([_videoFrameQueue count] > 0) {
        if (!_audioClk.eof) {
            double master_time = [_audioClk getClock];
            
            for (;![_videoFrameQueue isCanceled];) {
                //当前帧
                FFFrameItem *vp = [_videoFrameQueue peek];
                FFFrameItem *nextvp = [_videoFrameQueue peekNext];
                double duration = [self vp_duration:vp current:nextvp];//当前帧显示时长
                if (vp.pts + duration < master_time) {
                    [_videoClk setClock:vp.pts];
                    [_videoFrameQueue pop];
                    self.videoFrameCount--;
                } else {
                    break;
                }
            }
        } else {
            [_videoFrameQueue pop];
            self.videoFrameCount--;
            *remaining_time = 0.04;
        }
        double diff = [_audioClk getClock] - [_videoClk getClock];
        if (diff > 0.05) {
            av_log(NULL, AV_LOG_INFO, "A-V=%f\n",diff);
        }
        
        FFFrameItem *vp = [_videoFrameQueue peek];
        [self doDisplayVideoFrame:vp];
        [_videoClk setClock:vp.pts];
        
        if ([_videoFrameQueue count] > 1) {
            FFFrameItem *nextvp =[_videoFrameQueue peekNext];
            double duration = [self vp_duration:vp current:nextvp];//当前帧显示时长
            *remaining_time = FFMIN(duration, AV_SYNC_THRESHOLD_MIN);
        }
    } else if (_videoFrameQueue.eof){
        //no picture do display ?
        if (!_videoClk.eof) {
            _videoClk.eof = YES;
            av_log(NULL, AV_LOG_INFO, "video frame is eof\n");
            [self checkReachEnd];
        }
        *remaining_time = 0.01;
    } else {
        //buffing ?
    }
}

- (void)videoThreadFunc
{
    double remaining_time = 0.0;
    //调用了stop方法，则不再渲染
    while (!self.abort_request) {
        if (remaining_time > 0.0){
            mr_msleep(remaining_time * 1000);
        }
        remaining_time = REFRESH_RATE;
        [self video_refresh:&remaining_time];
    }
}

- (void)enQueueVideoFrame:(AVFrame *)frame
{
    const char *fmt_str = av_pixel_fmt_to_string(frame->format);
    
    self.videoPixelInfo = [NSString stringWithFormat:@"(%s)%dx%d",fmt_str,frame->width,frame->height];
    
    FFFrameItem *item = [[FFFrameItem alloc] initWithAVFrame:frame];
    
    if (frame->pts != AV_NOPTS_VALUE) {
        item.pts = frame->pts * av_q2d(_videoDecoder.stream->time_base);
    }
    
    item.duration = (_videoDecoder.frameRate.num && _videoDecoder.frameRate.den ? av_q2d(_videoDecoder.frameRate) : 0);
    
    [_videoFrameQueue push:item];
}

#pragma - mark Audio

- (void)play
{
    _isPlaying = YES;
    [_audioRender play];
}

- (void)pause
{
    _isPlaying = NO;
    [_audioRender pause];
}

- (BOOL)isPlaying
{
    return _isPlaying;
}

- (void)stopAudio
{
    [_audioRender stop];
}

- (void)close_all_file
{
#if DEBUG_RECORD_PCM_TO_FILE
    if (file_pcm_l) {
        fflush(file_pcm_l);
        fclose(file_pcm_l);
        file_pcm_l = NULL;
    }
    if (file_pcm_r) {
        fflush(file_pcm_r);
        fclose(file_pcm_r);
        file_pcm_r = NULL;
    }
#endif
}

- (void)setupAudioRender
{
    //这里指定了优先使用AudioQueue，当遇到不支持的格式时，自动使用AudioUnit
    FFTAudioRenderer *audioRender = [[FFTAudioRenderer alloc] initWithFmt:self.supportedSampleFormat preferredAudioQueue:YES sampleRate:self.supportedSampleRate];
    __weakSelf__
    [audioRender onFetchSamples:^UInt32(uint8_t * _Nonnull *buffer, UInt32 bufferSize) {
        __strongSelf__
        return [self fillBuffers:buffer byteSize:bufferSize];
    }];
    _audioRender = audioRender;
}

- (int)doFillAudioBuffers:(uint8_t * [2])buffer
                 byteSize:(int)bufferSize
{
    FFFrameItem *item = [_audioFrameQueue peek];
    if (!item) {
        return 0;
    }
    AVFrame *frame = item.frame;
    int data_size = audio_buffer_size(frame);
    int leave = data_size - _audioFrameRead;
    if (leave <= 0) {
        _audioFrameRead = 0;
        [_audioFrameQueue pop];
        return 0;
    }
    
    int cpSize = MIN(bufferSize,leave);
    
    for (int i = 0; i < 2; i++) {
        uint8_t *dst = buffer[i];
        if (NULL != dst) {
            uint8_t *src = (uint8_t *)(frame->data[i]) + _audioFrameRead;
            memcpy(dst, src, cpSize);
        } else {
            break;
        }
    }
    _audioFrameRead += cpSize;
    
    if (data_size - _audioFrameRead <= 0) {
        _audioFrameRead = 0;
        [_audioFrameQueue pop];
    }
    
    return cpSize;
}

- (void)updateAudioClock:(FFFrameItem *)ap
{
    if (!ap) {
        return;
    }
    AVFrame *frame = ap.frame;
    int data_size = audio_buffer_size(frame);
    float percent = 1.0 * _audioFrameRead / data_size;
    double audio_clock = ap.pts + percent * ap.frame->nb_samples / ap.frame->sample_rate;
    //double bytes_per_sec = self.supportedSampleRate * self.audioClk.bytesPerSample;
    //double audio_clock = audio_pts - 2.0 * (ap->offset + filled) / bytes_per_sec;
    [_audioClk setClock:audio_clock];
}

- (UInt32)fillBuffers:(uint8_t *[2])buffer
             byteSize:(UInt32)bufferSize
{
    int totalFilled = 0;
    while (bufferSize > 0) {
        int filled = [self doFillAudioBuffers:buffer byteSize:bufferSize];
        if (filled) {
            totalFilled += filled;
            bufferSize -= filled;
        } else {
            break;
        }
    }
    
    FFFrameItem *item = [_audioFrameQueue peek];
    [self updateAudioClock:item];
    
    if (totalFilled < bufferSize) {
        if (_audioFrameQueue.eof && [_audioFrameQueue count] == 0) {
            if (!_audioClk.eof) {
                _audioClk.eof = YES;
                av_log(NULL, AV_LOG_INFO, "audio frame is eof\n");
                [self checkReachEnd];
            }
        }
    }
#if DEBUG_RECORD_PCM_TO_FILE
    for(int i = 0; i < 2; i++) {
        uint8_t *src = buffer[i];
        if (NULL != src) {
            if (i == 0) {
                if (file_pcm_l == NULL) {
                    NSString *fileName = [NSString stringWithFormat:@"L-%@.pcm",self.audioSamplelInfo];
                    const char *l = [[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]UTF8String];
                    NSLog(@"create file:%s",l);
                    file_pcm_l = fopen(l, "wb+");
                }
                fwrite(src, totalFilled, 1, file_pcm_l);
            } else if (i == 1) {
                if (file_pcm_r == NULL) {
                    NSString *fileName = [NSString stringWithFormat:@"R-%@.pcm",self.audioSamplelInfo];
                    const char *r = [[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]UTF8String];
                    NSLog(@"create file:%s",r);
                    file_pcm_r = fopen(r, "wb+");
                }
                fwrite(src, totalFilled, 1, file_pcm_r);
            }
        }
    }
#endif
    return totalFilled;
}

- (void)enQueueAudioFrame:(AVFrame *)frame
{
    const char *fmt_str = av_sample_fmt_to_string(frame->format);
    self.audioSamplelInfo = [NSString stringWithFormat:@"(%s)%d",fmt_str,frame->sample_rate];
 
    [_audioFrameQueue enQueue:frame];
}

- (void)performErrorResultOnMainThread
{
    mr_sync_main_queue(^{
        if (self.onEnd) {
            self.onEnd(self.error);
        }
    });
}

# pragma mark - 播放进度

- (void)checkReachEnd
{
    mr_sync_main_queue(^{
        if (self->_audioClk.eof && self->_videoClk.eof) {
            av_log(NULL, AV_LOG_INFO, "stream is eof\n");
            self.error = nil;
            if (self.onEnd) {
                self.onEnd(self.error);
            }
        }
    });
}

- (float)duration
{
    return _duration;
}

- (float)audioPosition
{
    return (float)[_audioFrameQueue clock];
}

- (float)videoPosition
{
    return (float)[_videoFrameQueue clock];
}

- (void)load
{
    if (self.readThread) {
        NSAssert(NO, @"不允许重复创建");
    }
    
    _isPlaying = YES;
    
    _packetQueue = [[FFTPacketQueue alloc] init];
    
    self.readThread = [[FFTThread alloc] initWithTarget:self selector:@selector(readPacketsFunc) object:nil];
    self.readThread.name = @"mr-read";
    
    self.decoderThread = [[FFTThread alloc] initWithTarget:self selector:@selector(decoderFunc) object:nil];
    self.decoderThread.name = @"mr-decoder";
    
    self.videoThread = [[FFTThread alloc] initWithTarget:self selector:@selector(videoThreadFunc) object:nil];
    self.videoThread.name = @"mr-v-display";
    
    [self.readThread start];
    [self.videoThread start];
}

- (void)asyncStop
{
    [self performSelectorInBackground:@selector(_stop) withObject:self];
}

- (void)onError:(dispatch_block_t)block
{
    self.onErrorBlock = block;
}

- (int)videoFrameQueueSize
{
    return (int)[_videoFrameQueue count];
}

- (int)audioFrameQueueSize
{
    return (int)[_audioFrameQueue count];
}

- (NSString *)audioRenderName
{
    return [_audioRender name];
}

- (FFTVideoRenderer *)_videoRender
{
    return (FFTVideoRenderer *)_videoRender;
}

- (UIView *)videoRender
{
    if (!_videoRender) {
        id videoRender = [[FFTVideoRenderer alloc] init];
        _videoRender = videoRender;
    }
    return _videoRender;
}

@end
