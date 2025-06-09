//
//  FFTPlayer0x33.m
//  FFmpegTutorial
//
//  Created by qianlongxu on 2022/7/20.
//

#import "FFTPlayer0x33.h"
#import "FFTThread.h"
#import <libavutil/pixdesc.h>
#import <libavformat/avformat.h>
#import "FFTDecoder.h"
#import "FFTVideoScale.h"
#import "FFTAudioResample.h"
#import "FFTDispatch.h"
#import "FFTPacketQueue.h"
#import "FFTVideoFrameQueue.h"
#import "IJKMetalView.h"
#import "FFTAudioRenderer.h"
#import "FFTAudioFrameQueue.h"
#import "FFTAbstractLogger.h"
#import "FFTConvertUtil.h"

//视频宽；单位像素
kFFTPlayer0x33InfoKey kFFTPlayer0x33Width = @"kFFTPlayer0x33Width";
//视频高；单位像素
kFFTPlayer0x33InfoKey kFFTPlayer0x33Height = @"kFFTPlayer0x33Height";

//将音频裸流PCM写入到文件
#define DEBUG_RECORD_PCM_TO_FILE 0

@interface  FFTPlayer0x33 ()<FFTDecoderDelegate>
{
    //音频流解码器
    FFTDecoder *_audioDecoder;
    //视频流解码器
    FFTDecoder *_videoDecoder;
    
    //图像格式转换/缩放器
    FFTVideoScale *_videoScale;
    //音频重采样
    FFTAudioResample *_audioResample;
    
    FFTPacketQueue *_audioPacketQueue;
    FFTPacketQueue *_videoPacketQueue;
    
    FFTVideoFrameQueue *_videoFrameQueue;
    FFTAudioFrameQueue *_audioFrameQueue;
    //音频渲染
    FFTAudioRenderer *_audioRender;
    
    //视频尺寸
    CGSize _videoSize;
    AVFormatContext * _formatCtx;
    //读包完毕？
    int _eof;
    CVPixelBufferPoolRef _pixelBufferPoolRef;
#if DEBUG_RECORD_PCM_TO_FILE
    FILE * file_pcm_l;
    FILE * file_pcm_r;
#endif
}

//读包线程
@property (nonatomic, strong) FFTThread *readThread;
@property (nonatomic, strong) FFTThread *audioDecoderThread;
@property (nonatomic, strong) FFTThread *videoDecoderThread;
@property (nonatomic, strong) FFTThread *videoThread;

@property (atomic, assign) int abort_request;
@property (nonatomic, copy) dispatch_block_t onErrorBlock;
@property (atomic, assign, readwrite) int videoPktCount;
@property (atomic, assign, readwrite) int audioPktCount;
@property (atomic, assign, readwrite) int videoFrameCount;
@property (atomic, assign, readwrite) int audioFrameCount;

@end

@implementation  FFTPlayer0x33

static int decode_interrupt_cb(void *ctx)
{
    FFTPlayer0x33 *player = (__bridge FFTPlayer0x33 *)ctx;
    return player.abort_request;
}

- (void)_stop
{
    self.abort_request = 1;
    [_audioPacketQueue cancel];
    [_videoPacketQueue cancel];
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
    
    if (self.audioDecoderThread) {
        [self.audioDecoderThread cancel];
        [self.audioDecoderThread join];
    }
    
    if (self.videoDecoderThread) {
        [self.videoDecoderThread cancel];
        [self.videoDecoderThread join];
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
    
    _audioPacketQueue = [[FFTPacketQueue alloc] init];
    _videoPacketQueue = [[FFTPacketQueue alloc] init];
    
    self.readThread = [[FFTThread alloc] initWithTarget:self selector:@selector(readPacketsFunc) object:nil];
    self.readThread.name = @"mr-read";
    
    self.audioDecoderThread = [[FFTThread alloc] initWithTarget:self selector:@selector(audioDecoderFunc) object:nil];
    self.audioDecoderThread.name = @"audio-decoder";
    
    self.videoDecoderThread = [[FFTThread alloc] initWithTarget:self selector:@selector(videoDecoderFunc) object:nil];
    self.videoDecoderThread.name = @"video-decoder";
    
    self.videoThread = [[FFTThread alloc] initWithTarget:self selector:@selector(videoThreadFunc) object:nil];
    self.videoThread.name = @"mr-v-display";
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
                [_videoPacketQueue enQueue:pkt];
                pkt->stream_index = _audioDecoder.streamIdx;
                [_audioPacketQueue enQueue:pkt];
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
                    [_videoPacketQueue enQueue:pkt];
                }
                    break;
                case AVMEDIA_TYPE_AUDIO:
                {
                    if (pkt->data != NULL) {
                        self.audioPktCount++;
                    }
                    [_audioPacketQueue enQueue:pkt];
                }
                    break;
                default:
                    break;
            }
            if (self.onReadPkt) {
                self.onReadPkt(self,self.audioPktCount,self.videoPktCount);
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
            [dumpDic setObject:@(_videoDecoder.picWidth) forKey:kFFTPlayer0x33Width];
            [dumpDic setObject:@(_videoDecoder.picHeight) forKey:kFFTPlayer0x33Height];
            _videoScale = [self createVideoScaleIfNeed];
        }
    }
    
    _videoFrameQueue = [[FFTVideoFrameQueue alloc] init];
    _videoFrameQueue.streamTimeBase = av_q2d(_videoDecoder.stream->time_base);
    _videoFrameQueue.averageDuration = (_videoDecoder.frameRate.num && _videoDecoder.frameRate.den ? av_q2d(_videoDecoder.frameRate) : 0);
    
    _audioFrameQueue = [[FFTAudioFrameQueue alloc] init];
    _audioFrameQueue.streamTimeBase = av_q2d(_audioDecoder.stream->time_base);
    
    mr_sync_main_queue(^{
        //audio queue 不能跨线程，不可以在子线程创建，主线程play。audio unit 可以
        [self setupAudioRender];
        if (self.onStreamOpened) {
            self.onStreamOpened(self,dumpDic);
        }
    });
    
    _formatCtx = formatCtx;
    [self.audioDecoderThread start];
    [self.videoDecoderThread start];

    //循环读包
    [self readPacketLoop:formatCtx];
}

#pragma mark - 视频像素格式转换

- (FFTVideoScale *)createVideoScaleIfNeed
{
    //未指定期望像素格式
    if (self.pixelFormat == MR_PIX_FMT_NONE) {
        NSAssert(NO, @"supportedPixelFormats can't be none!");
        return nil;
    }
    
    //当前视频的像素格式
    const enum AVPixelFormat format = _videoDecoder.format;
    
    int dest = MRPixelFormat2AV(self.pixelFormat);
    
    if (dest == format) {
        //期望像素格式包含了当前视频像素格式，则直接使用当前格式，不再转换。
        return nil;
    }
    const char *in_fmt_str = av_pixel_fmt_to_string(format);
    const char *out_fmt_str = av_pixel_fmt_to_string(dest);
    
    av_log(NULL, AV_LOG_INFO, "scale %s to %s (%dx%d)",in_fmt_str,out_fmt_str,_videoDecoder.picWidth,_videoDecoder.picHeight);
    
    if ([FFTVideoScale checkCanConvertFrom:format to:dest]) {
        //创建像素格式转换上下文
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
    if (self.sampleFormat == MR_SAMPLE_FMT_NONE) {
        NSAssert(NO, @"supportedSampleFormats can't be none!");
        return nil;
    }
    
    //未指定支持的比特率就使用目标音频的
    if (self.sampleRate == 0) {
        self.sampleRate = _audioDecoder.sampleRate;
    }
    
    //当前音频的采样格式
    const enum AVSampleFormat format = _audioDecoder.format;
    
    int dest = MRSampleFormat2AV(self.sampleFormat);
    
    if (dest == format) {
        //采样率也匹配
        if (self.sampleRate == _audioDecoder.sampleRate) {
            av_log(NULL, AV_LOG_INFO, "audio not need resample!\n");
            return nil;
        }
    }
    
    const char *in_fmt_str = av_sample_fmt_to_string(format);
    const char *out_fmt_str = av_sample_fmt_to_string(dest);
    
    av_log(NULL, AV_LOG_INFO, "scale sample %s to %s (%dx%d)",in_fmt_str,out_fmt_str,_videoDecoder.picWidth,_videoDecoder.picHeight);
    
    //创建音频格式转换上下文
    FFTAudioResample *resample = [[FFTAudioResample alloc] initWithSrcSampleFmt:format
                                                                   dstSampleFmt:dest
                                                                     srcChannel:_audioDecoder.channelLayout
                                                                     dstChannel:_audioDecoder.channelLayout
                                                                        srcRate:_audioDecoder.sampleRate
                                                                        dstRate:self.sampleRate];
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

- (void)audioDecoderFunc
{
    while (!self.abort_request) {
        __weakSelf__
        [_audioPacketQueue deQueue:^(AVPacket * pkt) {
            __strongSelf__
            if (pkt) {
                [self decodePkt:pkt];
            }
        }];
    }
}

- (void)videoDecoderFunc
{
    while (!self.abort_request) {
        __weakSelf__
        [_videoPacketQueue deQueue:^(AVPacket * pkt) {
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

#pragma - mark Video

- (void)videoThreadFunc
{
    while (!_abort_request) {
        NSTimeInterval begin = CFAbsoluteTimeGetCurrent();
        FFFrameItem *item = [_videoFrameQueue peek];
        if (item) {
            [self displayVideoFrame:item.frame];
        } else {
            NSLog(@"has no video frame to display.");
        }

        NSTimeInterval end = CFAbsoluteTimeGetCurrent();
        int remained = item.duration - (end - begin) * 1000;
        if (remained > 0) {
            mr_msleep(remained);
        }
        [_videoFrameQueue pop];
    }
}

- (void)enQueueVideoFrame:(AVFrame *)frame
{
    const char *fmt_str = av_pixel_fmt_to_string(frame->format);
    
    self.videoPixelInfo = [NSString stringWithFormat:@"(%s)%dx%d",fmt_str,frame->width,frame->height];
    [_videoFrameQueue enQueue:frame];
}

- (CVPixelBufferRef)createCVPixelBufferFromAVFrame:(AVFrame *)frame
{
    if (_pixelBufferPoolRef) {
        NSDictionary *attributes = (__bridge NSDictionary *)CVPixelBufferPoolGetPixelBufferAttributes(_pixelBufferPoolRef);
        int _width = [[attributes objectForKey:(NSString*)kCVPixelBufferWidthKey] intValue];
        int _height = [[attributes objectForKey:(NSString*)kCVPixelBufferHeightKey] intValue];
        int _format = [[attributes objectForKey:(NSString*)kCVPixelBufferPixelFormatTypeKey] intValue];
        
        if (frame->width != _width || frame->height != _height || [FFTConvertUtil cvpixelFormatTypeWithAVFrame:frame] != _format) {
            CVPixelBufferPoolRelease(_pixelBufferPoolRef);
            _pixelBufferPoolRef = NULL;
        }
    }
    
    if (!_pixelBufferPoolRef) {
        _pixelBufferPoolRef = [FFTConvertUtil createPixelBufferPoolWithAVFrame:frame];
    }
    return [FFTConvertUtil pixelBufferFromAVFrame:frame opt:_pixelBufferPoolRef];
}

- (void)displayVideoFrame:(AVFrame *)frame
{
    CVPixelBufferRef videoPic = [self createCVPixelBufferFromAVFrame:frame];
    
    IJKOverlayAttach *attach = [[IJKOverlayAttach alloc] init];
    attach.w = frame->width;
    attach.h = frame->height;
  
    attach.pixelW = (int)CVPixelBufferGetWidth(videoPic);
    attach.pixelH = (int)CVPixelBufferGetHeight(videoPic);
    
    attach.sarNum = frame->sample_aspect_ratio.num;
    attach.sarDen = frame->sample_aspect_ratio.den;
    attach.autoZRotate = 0;
    attach.videoPicture = CVPixelBufferRetain(videoPic);
    
    [self.videoRender displayAttach:attach];
    CVPixelBufferRelease(videoPic);
}

#pragma - mark Audio

- (void)play
{
    [self.videoThread start];
    [_audioRender play];
}

- (void)pauseAudio
{
    [_audioRender pause];
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
    FFTAudioRenderer *audioRender = [[FFTAudioRenderer alloc] initWithFmt:self.sampleFormat preferredAudioQueue:YES sampleRate:self.sampleRate];
    __weakSelf__
    [audioRender onFetchSamples:^UInt32(uint8_t * _Nonnull *buffer, UInt32 bufferSize) {
        __strongSelf__
        return [self fillBuffers:buffer byteSize:bufferSize];
    }];
    _audioRender = audioRender;
}

- (UInt32)fillBuffers:(uint8_t *[2])buffer
             byteSize:(UInt32)bufferSize
{
    int filled = [_audioFrameQueue fillBuffers:buffer byteSize:bufferSize];
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
                fwrite(src, bufferSize, 1, file_pcm_l);
            } else if (i == 1) {
                if (file_pcm_r == NULL) {
                    NSString *fileName = [NSString stringWithFormat:@"R-%@.pcm",self.audioSamplelInfo];
                    const char *r = [[NSTemporaryDirectory() stringByAppendingPathComponent:fileName]UTF8String];
                    NSLog(@"create file:%s",r);
                    file_pcm_r = fopen(r, "wb+");
                }
                fwrite(src, bufferSize, 1, file_pcm_r);
            }
        }
    }
#endif
    return filled;
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
        if (self.onError) {
            self.onError(self,self.error);
        }
    });
}

- (void)load
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

- (UIView<IJKVideoRenderingProtocol> *)videoRender
{
    if (!_videoRender) {
        IJKMetalView *videoRender = [[IJKMetalView alloc] init];
        _videoRender = videoRender;
    }
    return _videoRender;
}

@end
