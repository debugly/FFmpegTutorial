//
//  FFPlayer0x30.m
//  FFmpegTutorial
//
//  Created by qianlongxu on 2022/2/17.
//

#import "FFPlayer0x30.h"
#import "MRThread.h"
#import "FFPlayerInternalHeader.h"
#import "FFPlayerPacketHeader.h"
#import "FFPlayerFrameHeader.h"
#import "FFDecoder0x30.h"
#import "FFVideoScale.h"
#import "FFAudioResample0x30.h"
#import "FFSyncClock0x30.h"
#import "MRConvertUtil.h"
#import <CoreVideo/CVPixelBufferPool.h>
#import <libavutil/time.h>

//是否使用POOL
#define USE_PIXEL_BUFFER_POOL 1

@interface FFPlayer0x30 ()<FFDecoderDelegate0x30>
{
    //解码前的音频包缓存队列
    PacketQueue _audioq;
    //解码前的视频包缓存队列
    PacketQueue _videoq;
    
    //解码后的音频帧缓存队列
    FrameQueue _sampq;
    //解码后的视频帧缓存队列
    FrameQueue _pictq;
    
    BOOL _buffing;
}

//读包线程
@property (nonatomic, strong) MRThread *readThread;
//渲染线程
@property (nonatomic, strong) MRThread *rendererThread;

//音频解码器
@property (nonatomic, strong) FFDecoder0x30 *audioDecoder;
//视频解码器
@property (nonatomic, strong) FFDecoder0x30 *videoDecoder;
//图像格式转换/缩放器
@property (nonatomic, strong) FFVideoScale *videoScale;
//音频格式转换器
@property (nonatomic, strong) FFAudioResample0x30 *audioResample;
//音频时钟
@property (nonatomic, strong) FFSyncClock0x30 *audioClk;
//视频时钟
@property (nonatomic, strong) FFSyncClock0x30 *videoClk;

//PixelBuffer池可提升效率
@property (assign, nonatomic) CVPixelBufferPoolRef pixelBufferPool;
@property (atomic, assign) int abort_request;

@property (nonatomic, copy) dispatch_block_t onErrorBlock;
@property (nonatomic, copy) dispatch_block_t onPacketBufferFullBlock;
@property (nonatomic, copy) dispatch_block_t onPacketBufferEmptyBlock;
@property (nonatomic, copy) dispatch_block_t onVideoEndsBlock;

@property (atomic, assign) BOOL packetBufferIsFull;
@property (atomic, assign) BOOL packetBufferIsEmpty;
@property (nonatomic, assign) double max_frame_duration;
//读包完毕
@property (atomic, assign) BOOL eof;
@property (atomic, assign) BOOL videoEnds;
@property (atomic, assign, readwrite) int videoFrameCount;
@property (atomic, assign, readwrite) int audioFrameCount;

@end

@implementation  FFPlayer0x30

static int decode_interrupt_cb(void *ctx)
{
    FFPlayer0x30 *player = (__bridge FFPlayer0x30 *)ctx;
    return player.abort_request;
}

- (void)_stop
{
    //避免重复stop做无用功
    if (self.readThread) {
        self.abort_request = 1;
        _audioq.abort_request = 1;
        _videoq.abort_request = 1;
        _sampq.abort_request = 1;
        _pictq.abort_request = 1;
        
        [self.readThread cancel];
        [self.audioDecoder cancel];
        [self.videoDecoder cancel];
        [self.rendererThread cancel];
        
        [self.readThread join];
        [self.audioDecoder join];
        [self.videoDecoder join];
        [self.rendererThread join];
    }
    [self performSelectorOnMainThread:@selector(didStop:) withObject:self waitUntilDone:YES];
}

- (void)didStop:(id)sender
{
    self.readThread = nil;
    self.audioDecoder = nil;
    self.videoDecoder = nil;
    self.rendererThread = nil;
    
    if (self.pixelBufferPool){
        CVPixelBufferPoolRelease(self.pixelBufferPool);
        self.pixelBufferPool = NULL;
    }
    
    packet_queue_destroy(&_audioq);
    packet_queue_destroy(&_videoq);
    
    frame_queue_destory(&_pictq);
    frame_queue_destory(&_sampq);
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
    
    //初始化视频包队列
    packet_queue_init(&_videoq);
    //初始化音频包队列
    packet_queue_init(&_audioq);
    //初始化ffmpeg相关函数
    init_ffmpeg_once();
    
    //初始化视频帧队列
    frame_queue_init(&_pictq, VIDEO_PICTURE_QUEUE_SIZE, "pictq", 1);
    //初始化音频帧队列
    frame_queue_init(&_sampq, SAMPLE_QUEUE_SIZE, "sampq", 1);
    
    self.readThread = [[MRThread alloc] initWithTarget:self selector:@selector(readPacketsFunc) object:nil];
    self.readThread.name = @"mr-read";
    
    _buffing = YES;
}

#pragma mark - clock

- (void)initVideoClock
{
    self.videoClk = [[FFSyncClock0x30 alloc] init];
}

- (void)initAudioClock
{
    self.audioClk = [[FFSyncClock0x30 alloc] init];
    enum AVSampleFormat fmt = 0;
    if (self.audioResample) {
        fmt = self.audioResample.out_sample_fmt;
    } else {
        fmt = self.audioDecoder.format;
    }
    
    int bytesPerSample = 0;
    if (fmt == AV_SAMPLE_FMT_FLT || fmt == AV_SAMPLE_FMT_FLTP) {
        bytesPerSample = sizeof(float);
    } else if (fmt == AV_SAMPLE_FMT_S16 || fmt == AV_SAMPLE_FMT_S16P) {
        bytesPerSample = sizeof(int16_t);
    }
    self.audioClk.bytesPerSample = bytesPerSample;
}

#pragma mark - 打开解码器创建解码线程

- (FFDecoder0x30 *)openStreamComponent:(AVFormatContext *)ic streamIdx:(int)idx
{
    FFDecoder0x30 *decoder = [FFDecoder0x30 new];
    decoder.ic = ic;
    decoder.streamIdx = idx;
    if ([decoder open] == 0) {
        return decoder;
    } else {
        return nil;
    }
}

#pragma -mark 读包线程

//读包循环
- (void)readPacketLoop:(AVFormatContext *)formatCtx
{
    AVPacket pkt1, *pkt = &pkt1;
    //循环读包
    for (;;) {
        
        //调用了stop方法，则不再读包
        if (self.abort_request) {
            break;
        }
        
        /* 队列不满继续读，满了则休眠10 ms */
        if (_audioq.size + _videoq.size > MAX_QUEUE_SIZE
            || (stream_has_enough_packets(self.audioDecoder.stream, self.audioDecoder.streamIdx, &_audioq) &&
                stream_has_enough_packets(self.videoDecoder.stream, self.videoDecoder.streamIdx, &_videoq))) {
            
            if (!self.packetBufferIsFull) {
                self.packetBufferIsFull = YES;
                if (self.onPacketBufferFullBlock) {
                    self.onPacketBufferFullBlock();
                }
            }
            /* wait 10 ms */
            mr_msleep(10);
            continue;
        }
        
        self.packetBufferIsFull = NO;
        //读包
        int ret = av_read_frame(formatCtx, pkt);
        //读包出错
        if (ret < 0) {
            //读到最后结束了
            if ((ret == AVERROR_EOF || avio_feof(formatCtx->pb)) && !self.eof) {
                //最后放一个空包进去
                if (self.audioDecoder.streamIdx >= 0) {
                    packet_queue_put_nullpacket(&_audioq, self.audioDecoder.streamIdx);
                }
                    
                if (self.videoDecoder.streamIdx >= 0) {
                    packet_queue_put_nullpacket(&_videoq, self.videoDecoder.streamIdx);
                }
                //标志为读包结束
                self.eof = 1;
            }
            
            if (formatCtx->pb && formatCtx->pb->error) {
                break;
            }
            /* wait 10 ms */
            mr_msleep(10);
            continue;
        } else {
            //音频包入音频队列
            if (pkt->stream_index == self.audioDecoder.streamIdx) {
                packet_queue_put(&_audioq, pkt);
            }
            //视频包入视频队列
            else if (pkt->stream_index == self.videoDecoder.streamIdx) {
                packet_queue_put(&_videoq, pkt);
            }
            //其他包释放内存忽略掉
            else {
                av_packet_unref(pkt);
            }
        }
    }
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

#pragma mark - 视频像素格式转换

- (FFVideoScale *)createVideoScaleIfNeed
{
    //未指定期望像素格式
    if (self.supportedPixelFormats == MR_PIX_FMT_MASK_NONE) {
        NSAssert(NO, @"supportedPixelFormats can't be none!");
        return nil;
    }
    
    //当前视频的像素格式
    const enum AVPixelFormat format = self.videoDecoder.format;
    
    bool matched = false;
    MRPixelFormat firstSupportedFmt = MR_PIX_FMT_NONE;
    for (int i = MR_PIX_FMT_BEGIN; i <= MR_PIX_FMT_END; i ++) {
        const MRPixelFormat fmt = i;
        const MRPixelFormatMask mask = 1 << fmt;
        if (self.supportedPixelFormats & mask) {
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
        av_log(NULL, AV_LOG_INFO, "video not need rescale!\n");
        return nil;
    }
    
    if (firstSupportedFmt == MR_PIX_FMT_NONE) {
        NSAssert(NO, @"supportedPixelFormats is invalid!");
        return nil;
    }
    
    int dest = MRPixelFormat2AV(firstSupportedFmt);
    if ([FFVideoScale checkCanConvertFrom:format to:dest]) {
        //创建像素格式转换上下文
        FFVideoScale *scale = [[FFVideoScale alloc] initWithSrcPixFmt:format dstPixFmt:dest picWidth:self.videoDecoder.picWidth picHeight:self.videoDecoder.picHeight];
        return scale;
    } else {
        //TODO ??
        return nil;
    }
}

- (FFAudioResample0x30 *)createAudioResampleIfNeed
{
    //未指定期望音频格式
    if (self.supportedSampleFormats == MR_SAMPLE_FMT_MASK_NONE) {
        NSAssert(NO, @"supportedSampleFormats can't be none!");
        return nil;
    }
    
    //未指定支持的比特率就使用目标音频的
    if (self.supportedSampleRate == 0) {
        self.supportedSampleRate = self.audioDecoder.sampleRate;
    }
    
    //当前视频的像素格式
    const enum AVSampleFormat format = self.audioDecoder.format;
    
    bool matched = false;
    MRSampleFormat firstSupportedFmt = MR_SAMPLE_FMT_NONE;
    for (int i = MR_SAMPLE_FMT_BEGIN; i <= MR_SAMPLE_FMT_END; i ++) {
        const MRSampleFormat fmt = i;
        const MRSampleFormatMask mask = 1 << fmt;
        if (self.supportedSampleFormats & mask) {
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
        if (self.supportedSampleRate != self.audioDecoder.sampleRate) {
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
    FFAudioResample0x30 *resample = [[FFAudioResample0x30 alloc] initWithSrcSampleFmt:format
                                                                         dstSampleFmt:MRSampleFormat2AV(firstSupportedFmt)
                                                                           srcChannel:self.audioDecoder.channelLayout
                                                                           dstChannel:self.audioDecoder.channelLayout
                                                                              srcRate:self.audioDecoder.sampleRate
                                                                              dstRate:self.supportedSampleRate];
    return resample;
}

- (void)readPacketsFunc
{
    if (![self.contentPath hasPrefix:@"/"]) {
        _init_net_work_once();
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
    self.max_frame_duration = (formatCtx->iformat->flags & AVFMT_TS_DISCONT) ? 10.0 : 3600.0;
    //确定最优的音视频流
    int st_index[AVMEDIA_TYPE_NB];
    memset(st_index, -1, sizeof(st_index));
    [self findBestStreams:formatCtx result:&st_index];
    
    //打开音频解码器，创建解码线程
    if (st_index[AVMEDIA_TYPE_AUDIO] >= 0){
        
        self.audioDecoder = [self openStreamComponent:formatCtx streamIdx:st_index[AVMEDIA_TYPE_AUDIO]];
        
        if(self.audioDecoder){
            self.audioDecoder.delegate = self;
            self.audioDecoder.name = @"mr-audio-dec";
            self.audioResample = [self createAudioResampleIfNeed];
        } else {
            av_log(NULL, AV_LOG_ERROR, "can't open audio stream.\n");
            self.error = _make_nserror_desc(FFPlayerErrorCode_StreamOpenFailed, @"音频流打开失败！");
            [self performErrorResultOnMainThread];
            //出错了，销毁下相关结构体
            avformat_close_input(&formatCtx);
            return;
        }
        
        if ([self.delegate respondsToSelector:@selector(player:onInitAudioRender:)]) {
            if (self.audioResample) {
                [self.delegate player:self onInitAudioRender:AVSampleFormat2MR(self.audioResample.out_sample_fmt)];
            } else {
                [self.delegate player:self onInitAudioRender:AVSampleFormat2MR(self.audioDecoder.format)];
            }
        }
    }

    //打开视频解码器，创建解码线程
    if (st_index[AVMEDIA_TYPE_VIDEO] >= 0){
        self.videoDecoder = [self openStreamComponent:formatCtx streamIdx:st_index[AVMEDIA_TYPE_VIDEO]];
        if(self.videoDecoder){
            self.videoDecoder.delegate = self;
            self.videoDecoder.name = @"mr-video-dec";
            self.videoScale = [self createVideoScaleIfNeed];
        } else {
            av_log(NULL, AV_LOG_ERROR, "can't open video stream.");
            self.error = _make_nserror_desc(FFPlayerErrorCode_StreamOpenFailed, @"视频流打开失败！");
            [self performErrorResultOnMainThread];
            //出错了，销毁下相关结构体
            avformat_close_input(&formatCtx);
            return;
        }
    }
    //初始化同步时钟
    [self initVideoClock];
    [self initAudioClock];
    //音视频解码线程开始工作
    [self.audioDecoder start];
    [self.videoDecoder start];
    //准备渲染线程
    [self prepareRendererThread];
    //渲染线程开始工作
    [self.rendererThread start];
    //循环读包
    [self readPacketLoop:formatCtx];
    //读包线程结束了，销毁下相关结构体
    avformat_close_input(&formatCtx);
}

#pragma mark - FFDecoderDelegate0x30

- (int)decoder:(FFDecoder0x30 *)decoder wantAPacket:(AVPacket *)pkt
{
    if (decoder == self.audioDecoder) {
        return packet_queue_get(&_audioq, pkt, 1);
    } else if (decoder == self.videoDecoder) {
        return packet_queue_get(&_videoq, pkt, 1);
    } else {
        return -1;
    }
}

- (void)decoder:(FFDecoder0x30 *)decoder reveivedAFrame:(AVFrame *)frame
{
    if (decoder == self.audioDecoder) {
        FrameQueue *fq = &_sampq;
        
        AVFrame *outP = nil;
        if (self.audioResample) {
            if (![self.audioResample resampleFrame:frame out:&outP]) {
                self.error = _make_nserror_desc(FFPlayerErrorCode_ResampleFrameFailed, @"音频帧重采样失败！");
                [self performErrorResultOnMainThread];
                return;
            }
        } else {
            outP = frame;
        }
        double duration = av_q2d((AVRational){outP->nb_samples, outP->sample_rate});
        AVRational tb = (AVRational){1, frame->sample_rate};
        frame_queue_push_v2(fq, outP,^(Frame * const af){
            af->duration = duration;
            af->pts = (frame->pts == AV_NOPTS_VALUE) ? NAN : frame->pts * av_q2d(tb);;
        });
        self.audioFrameCount++;
    } else if (decoder == self.videoDecoder) {
        FrameQueue *fq = &_pictq;
        
        AVFrame *outP = nil;
        if (self.videoScale) {
            if (![self.videoScale rescaleFrame:frame out:&outP]) {
                self.error = _make_nserror_desc(FFPlayerErrorCode_RescaleFrameFailed, @"视频帧重转失败！");
                [self performErrorResultOnMainThread];
                return;
            }
        } else {
            outP = frame;
        }
        
        double duration = (self.videoDecoder.frameRate.num && self.videoDecoder.frameRate.den ? av_q2d(self.videoDecoder.frameRate) : 0);
        AVRational tb = self.videoDecoder.stream->time_base;
        double pts = (outP->pts == AV_NOPTS_VALUE) ? NAN : outP->pts * av_q2d(tb);
        frame_queue_push_v2(fq, outP,^(Frame * const af){
            af->duration = duration;
            af->pts = pts;
        });
        self.videoFrameCount++;
    }
}

#pragma mark - RendererThread

- (void)prepareRendererThread
{
    self.rendererThread = [[MRThread alloc] initWithTarget:self selector:@selector(rendererThreadFunc) object:nil];
    self.rendererThread.name = @"mr-renderer";
}

- (CVPixelBufferRef _Nullable)pixelBufferFromAVFrame:(AVFrame *)frame
{
#if USE_PIXEL_BUFFER_POOL
    if (!self.pixelBufferPool){
        CVPixelBufferPoolRef pixelBufferPool = [MRConvertUtil createCVPixelBufferPoolRef:frame->format w:frame->width h:frame->height fullRange:frame->color_range != AVCOL_RANGE_MPEG];
        if (pixelBufferPool) {
            CVPixelBufferPoolRetain(pixelBufferPool);
            self.pixelBufferPool = pixelBufferPool;
        }
    }
#endif
    
    CVPixelBufferRef pixelBuffer = [MRConvertUtil pixelBufferFromAVFrame:frame opt:self.pixelBufferPool];
    return pixelBuffer;
}

- (void)doDisplayVideoFrame:(Frame *)vp
{
    if ([self.delegate respondsToSelector:@selector(player:reveiveFrameToRenderer:)]) {
        @autoreleasepool {
            CVPixelBufferRef pixelBuffer = [self pixelBufferFromAVFrame:vp->frame];
            if (pixelBuffer) {
                [self.delegate player:self reveiveFrameToRenderer:pixelBuffer];
            }
        }
    }
}

- (double)vp_durationWithP1:(Frame *)p1 p2:(Frame *)p2
{
    if (p1 == p2) {
        return 0.0;
    }
    double duration = p2->pts - p1->pts;
    if (isnan(duration) || duration <= 0 || duration > self.max_frame_duration){
        return p1->duration;
    } else {
        return duration;
    }
}

- (double)compute_target_delay:(double)delay
{
    //计算视频时钟和主时钟（音频时钟）的差距
    if (self.audioClk.eof) {
        return delay;
    }
    
    double diff = [self.videoClk getClock] - [self.audioClk getClock];
    
    /* skip or repeat frame. We take into account the
       delay to compute the threshold. I still don't know
       if it is the best guess */
    double sync_threshold = FFMAX(AV_SYNC_THRESHOLD_MIN, FFMIN(AV_SYNC_THRESHOLD_MAX, delay));
    if (!isnan(diff) && fabs(diff) < self.max_frame_duration) {
        if (diff <= -sync_threshold)
            delay = FFMAX(0, delay + diff);
        else if (diff >= sync_threshold && delay > AV_SYNC_FRAMEDUP_THRESHOLD)
            delay = delay + diff;
        else if (diff >= sync_threshold)
            delay = 2 * delay;
    }
    
    int vfr = frame_queue_nb_remaining(&_pictq);
    int afr = frame_queue_nb_remaining(&_sampq);
    int apc = _audioq.nb_packets;
    int vpc = _videoq.nb_packets;
    
    av_log(NULL, AV_LOG_INFO, "video: delay=%0.3f A-V=%f; af:%02d,vf:%02d; ap:%02d,vp:%02d;\n",
            delay, -diff, afr, vfr, apc, vpc);
    return delay;
}

- (void)video_refresh:(double *)remaining_time
{
    if (frame_queue_nb_remaining(&_pictq) > 0) {
        Frame *vp, *lastvp;
        lastvp = frame_queue_peek_last(&_pictq);
        vp = frame_queue_peek(&_pictq);
        //计算上一帧的持续时长
        double last_duration = [self vp_durationWithP1:lastvp p2:vp];
        //参考audio clock计算上一帧真正的持续时长
        double delay = [self compute_target_delay:last_duration];
        double time = av_gettime_relative() / 1000000.0;
        //时间还没到上一帧结束点
        if (time < self.videoClk.frame_timer + delay) {
            *remaining_time = FFMIN(self.videoClk.frame_timer + delay - time, *remaining_time);
            //仍旧显示上一帧
            [self doDisplayVideoFrame:lastvp];
            return;
        }
        
        self.videoClk.frame_timer += delay;
        if (delay > 0 && time - self.videoClk.frame_timer > AV_SYNC_THRESHOLD_MAX) {
            self.videoClk.frame_timer = time;
        }
        
        [self.videoClk setClock:vp->pts];
        
        //丢帧逻辑
        if (frame_queue_nb_remaining(&_pictq) > 1) {
            Frame *nextvp = frame_queue_peek_next(&_pictq);
            double duration = [self vp_durationWithP1:vp p2:nextvp];//当前帧显示时长
            if(time > self.videoClk.frame_timer + duration){//如果系统时间已经大于当前帧，则丢弃当前帧
                static int frame_drops_late = 0;
                frame_drops_late++;
                av_log(NULL, AV_LOG_INFO, "drop video:%4d\n",
                frame_drops_late);
                //继续重试
                *remaining_time = 0.0;
            }
        }
        frame_queue_pop(&_pictq);
        self.videoFrameCount--;
    } else if(self.eof && self.videoDecoder.eof){
        //no picture do display.
        self.videoClk.eof = YES;
        av_log(NULL, AV_LOG_INFO, "video frame is eof\n");
        [self maybeReachEnds];
    } else {
        //begin buffing
        [self beginBuffer];
    }
}

- (void)beginBuffer
{
    if (!_buffing) {
        _buffing = YES;
        if ([self.delegate respondsToSelector:@selector(onBufferEmpty:)]) {
            [self.delegate onBufferEmpty:self];
        }
    }
}

- (void)endBuffer
{
    if (_buffing) {
        _buffing = NO;
        if ([self.delegate respondsToSelector:@selector(onBufferFull:)]) {
            [self.delegate onBufferFull:self];
        }
    }
}

- (void)rendererThreadFunc
{
    double remaining_time = 0.0;
    //调用了stop方法，则不再渲染
    while (!self.abort_request && !self.videoClk.eof) {
        if (remaining_time > 0.0){
            mr_sleep(remaining_time);
        }
        remaining_time = REFRESH_RATE;
        
        if (_buffing) {
            if (frame_queue_is_full(&_pictq)) {
                [self endBuffer];
                [self video_refresh:&remaining_time];
            } else {
                if (self.videoDecoder.eof) {
                    [self endBuffer];
                    [self video_refresh:&remaining_time];
                }
            }
        } else {
            [self video_refresh:&remaining_time];
        }
    }
}

- (void)updateAudioClock:(Frame *)ap percent:(float)p
{
    double audio_clock = ap->pts + p * ap->frame->nb_samples / ap->frame->sample_rate;
    //double bytes_per_sec = self.supportedSampleRate * self.audioClk.bytesPerSample;
    //double audio_clock = audio_pts - 2.0 * (ap->offset + filled) / bytes_per_sec;
    [self.audioClk setClock:audio_clock];
}

- (UInt32)fetchPacketSample:(uint8_t *)buffer
                  wantBytes:(UInt32)bufferSize
{
    UInt32 filled = 0;
    Frame *ap = NULL;
    while (bufferSize > 0) {
        //队列里缓存帧大于0，则取出
        if (frame_queue_nb_remaining(&_sampq) > 0) {
            ap = frame_queue_peek(&_sampq);
            av_log(NULL, AV_LOG_VERBOSE, "render audio frame %lld\n", ap->frame->pts);
        } else {
            //队列里没有音频桢了，跳出循环
            break;
        }
        
        uint8_t *src = ap->frame->data[0];
        const int fmt = ap->frame->format;
        assert(0 == av_sample_fmt_is_planar(fmt));
        
        const int data_size = av_samples_get_buffer_size(ap->frame->linesize, 2, ap->frame->nb_samples, fmt, 1);
        NSAssert(data_size != 0, @"fuck");
        int l_src_size = data_size;//ap->frame->linesize[0];
        const int offset = ap->offset;
        const void *from = src + offset;
        int left = l_src_size - offset;
        
        //根据剩余数据长度和需要数据长度算出应当copy的长度
        int leftBytesToCopy = FFMIN(bufferSize, left);
        
        memcpy(buffer, from, leftBytesToCopy);
        buffer += leftBytesToCopy;
        bufferSize -= leftBytesToCopy;
        ap->offset += leftBytesToCopy;
        filled += leftBytesToCopy;
        
        [self updateAudioClock:ap percent:1.0 * ap->offset / data_size];
        
        if (leftBytesToCopy >= left){
            //读取完毕，则清空；读取下一个包
            //av_log(NULL, AV_LOG_DEBUG, "packet sample:next frame\n");
            frame_queue_pop(&_sampq);
            self.audioFrameCount--;
        }
    }
    
    //没有取出采样桢，读包eof，解码也eof时标记为音频渲染完毕
    if(!ap && self.eof && self.audioDecoder.eof){
        self.audioClk.eof = YES;
        av_log(NULL, AV_LOG_INFO, "audio frame is eof\n");
        [self maybeReachEnds];
    }
    
    return filled;
}

- (UInt32)fetchPlanarSample:(uint8_t *)l_buffer
                   leftSize:(UInt32)l_size
                      right:(uint8_t *)r_buffer
                  rightSize:(UInt32)r_size
{
    UInt32 filled = 0;
    Frame *ap = NULL;
    while (l_size > 0 || r_size > 0) {
        //队列里缓存帧大于0，则取出
        if (frame_queue_nb_remaining(&_sampq) > 0) {
            ap = frame_queue_peek(&_sampq);
            av_log(NULL, AV_LOG_VERBOSE, "render audio frame %lld\n", ap->frame->pts);
        } else {
            //队列里没有音频桢了，跳出循环
            break;
        }
        uint8_t *l_src = ap->frame->data[0];
        const int fmt  = ap->frame->format;
        assert(av_sample_fmt_is_planar(fmt));
        
        const int data_size = av_samples_get_buffer_size(ap->frame->linesize, 1, ap->frame->nb_samples, fmt, 1);
        
        int l_src_size = data_size;//af->frame->linesize[0];
        const int offset = ap->offset;
        const void *leftFrom = l_src + offset;
        int leftBytesLeft = l_src_size - offset;
        
        //根据剩余数据长度和需要数据长度算出应当copy的长度
        int leftBytesToCopy = FFMIN(l_size, leftBytesLeft);
        
        memcpy(l_buffer, leftFrom, leftBytesToCopy);
        l_buffer += leftBytesToCopy;
        l_size -= leftBytesToCopy;
        ap->offset += leftBytesToCopy;
        filled += leftBytesToCopy;
        uint8_t *r_src = ap->frame->data[1];
        int r_src_size = l_src_size;//af->frame->linesize[1];
        if (r_src) {
            const void *right_from = r_src + offset;
            int right_bytes_left = r_src_size - offset;
            
            //根据剩余数据长度和需要数据长度算出应当copy的长度
            int rightBytesToCopy = FFMIN(r_size, right_bytes_left);
            memcpy(r_buffer, right_from, rightBytesToCopy);
            r_buffer += rightBytesToCopy;
            r_size -= rightBytesToCopy;
        }
        
        [self updateAudioClock:ap percent:1.0 * ap->offset / data_size];
        
        if (leftBytesToCopy >= leftBytesLeft){
            //读取完毕，则清空；读取下一个包
            //av_log(NULL, AV_LOG_DEBUG, "packet sample:next frame\n");
            frame_queue_pop(&_sampq);
            self.audioFrameCount--;
        }
    }

    //没有取出采样桢，读包eof，解码也eof时标记为音频渲染完毕
    if(!ap && self.eof && self.audioDecoder.eof){
        self.audioClk.eof = YES;
        av_log(NULL, AV_LOG_INFO, "audio frame is eof\n");
        [self maybeReachEnds];
    }
    
    return filled;
}

- (void)maybeReachEnds
{
    if (!self.videoEnds) {
        if (self.audioClk.eof && self.videoClk.eof) {
            self.videoEnds = YES;
            MR_sync_main_queue(^{
                if (self.onVideoEndsBlock) {
                    self.onVideoEndsBlock();
                }
            });
        }
    }
}

- (void)performErrorResultOnMainThread
{
    MR_sync_main_queue(^{
        if (self.onErrorBlock) {
            self.onErrorBlock();
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

- (void)onPacketBufferFull:(dispatch_block_t)block
{
    self.onPacketBufferFullBlock = block;
}

- (void)onPacketBufferEmpty:(dispatch_block_t)block
{
    self.onPacketBufferEmptyBlock = block;
}

- (void)onVideoEnds:(dispatch_block_t)block
{
    self.onVideoEndsBlock = block;
}

- (MR_PACKET_SIZE)peekPacketBufferStatus
{
    return (MR_PACKET_SIZE){_videoq.nb_packets,_audioq.nb_packets,0};
}

@end
