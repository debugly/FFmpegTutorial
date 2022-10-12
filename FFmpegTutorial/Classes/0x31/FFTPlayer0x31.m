//
//  FFTPlayer0x31.m
//  FFmpegTutorial
//
//  Created by qianlongxu on 2022/7/16.
//

#import "FFTPlayer0x31.h"
#import "FFTThread.h"
#import <libavutil/pixdesc.h>
#import <libavformat/avformat.h>
#import <libavformat/avformat.h>
#import "FFTDecoder.h"
#import "FFTVideoScale.h"
#import "FFTAudioResample.h"
#import "FFTDispatch.h"
#import "FFTPacketQueue.h"
#import "FFTAbstractLogger.h"

//视频宽；单位像素
kFFTPlayer0x31InfoKey kFFTPlayer0x31Width = @"kFFTPlayer0x31Width";
//视频高；单位像素
kFFTPlayer0x31InfoKey kFFTPlayer0x31Height = @"kFFTPlayer0x31Height";

@interface  FFTPlayer0x31 ()<FFTDecoderDelegate>
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
    
    AVFormatContext * _formatCtx;
    //读包完毕？
    int _eof;
}

//读包线程
@property (nonatomic, strong) FFTThread *readThread;
@property (nonatomic, strong) FFTThread *decoderThread;

@property (atomic, assign) int abort_request;
@property (nonatomic, copy) dispatch_block_t onErrorBlock;
@property (atomic, assign, readwrite) int videoPktCount;
@property (atomic, assign, readwrite) int audioPktCount;
@property (atomic, assign, readwrite) int videoFrameCount;
@property (atomic, assign, readwrite) int audioFrameCount;

@end

@implementation  FFTPlayer0x31

static int decode_interrupt_cb(void *ctx)
{
    FFTPlayer0x31 *player = (__bridge FFTPlayer0x31 *)ctx;
    return player.abort_request;
}

- (void)_stop
{
    self.abort_request = 1;
    [_packetQueue cancel];
    
    //避免重复stop做无用功
    if (self.readThread) {
        [self.readThread cancel];
        [self.readThread join];
    }
    
    if (self.decoderThread) {
        [self.decoderThread cancel];
        [self.decoderThread join];
    }
    
    //读包线程结束了，销毁下相关结构体
    avformat_close_input(&_formatCtx);
    [self performSelectorOnMainThread:@selector(didStop:) withObject:self waitUntilDone:YES];
}

- (void)didStop:(id)sender
{
    self.readThread = nil;
}

- (void)dealloc
{
    PRINT_DEALLOC;
}

//准备
- (void)prepareToPlay
{
    if (self.readThread) {
        NSAssert(NO, @"不允许重复创建");
    }
    _packetQueue = [[FFTPacketQueue alloc] init];
    
    self.readThread = [[FFTThread alloc] initWithTarget:self selector:@selector(readPacketsFunc) object:nil];
    self.readThread.name = @"mr-read";
    
    self.decoderThread = [[FFTThread alloc] initWithTarget:self selector:@selector(decoderFunc) object:nil];
    self.decoderThread.name = @"mr-decoder";
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
            [dumpDic setObject:@(_videoDecoder.picWidth) forKey:kFFTPlayer0x31Width];
            [dumpDic setObject:@(_videoDecoder.picHeight) forKey:kFFTPlayer0x31Height];
            _videoScale = [self createVideoScaleIfNeed];
        }
    }
    
    mr_sync_main_queue(^{
        if (self.onStreamOpened) {
            self.onStreamOpened(dumpDic);
        }
    });
    
    _formatCtx = formatCtx;
    [self.decoderThread start];
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
        if (self.onDecoderFrame) {
            self.onDecoderFrame(2, self.audioFrameCount, audioFrame);
        }
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
        if (self.onDecoderFrame) {
            self.onDecoderFrame(1, self.videoFrameCount, videoFrame);
        }
    }
}

- (void)performErrorResultOnMainThread
{
    mr_sync_main_queue(^{
        if (self.onError) {
            self.onError(self.error);
        }
    });
}

- (void)play
{
    [self.readThread start];
}

- (void)asyncStop
{
    [self performSelectorInBackground:@selector(_stop) withObject:self];
}

- (void)onError:(dispatch_block_t)block
{
    self.onErrorBlock = block;
}

@end
