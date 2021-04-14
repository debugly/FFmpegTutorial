//
//  FFPlayer0x21.m
//  FFmpegTutorial
//
//  Created by qianlongxu on 2020/7/14.
//

#import "FFPlayer0x21.h"
#import "MRThread.h"
#import "FFPlayerInternalHeader.h"
#import "FFPlayerPacketHeader.h"
#import "FFPlayerFrameHeader.h"
#import "FFDecoder0x21.h"
#import "FFVideoScale0x21.h"
#import "FFAudioResample0x21.h"
#import "MRConvertUtil.h"
#import <CoreVideo/CVPixelBufferPool.h>

//是否使用POOL
#define USE_PIXEL_BUFFER_POOL 1

@interface FFPlayer0x21 ()<FFDecoderDelegate0x21>
{
    //解码前的音频包缓存队列
    PacketQueue audioq;
    //解码前的视频包缓存队列
    PacketQueue videoq;
    
    //解码后的音频帧缓存队列
    FrameQueue sampq;
    //解码后的视频帧缓存队列
    FrameQueue pictq;
    
    //读包完毕？
    int eof;
}

//读包线程
@property (nonatomic, strong) MRThread *readThread;
//渲染线程
@property (nonatomic, strong) MRThread *rendererThread;

//音频解码器
@property (nonatomic, strong) FFDecoder0x21 *audioDecoder;
//视频解码器
@property (nonatomic, strong) FFDecoder0x21 *videoDecoder;
//图像格式转换/缩放器
@property (nonatomic, strong) FFVideoScale0x21 *videoScale;
//音频格式转换器
@property (nonatomic, strong) FFAudioResample0x21 *audioResample;

//PixelBuffer池可提升效率
@property (assign, nonatomic) CVPixelBufferPoolRef pixelBufferPool;
@property (atomic, assign) int abort_request;
@property (nonatomic, copy) dispatch_block_t onErrorBlock;
@property (nonatomic, copy) dispatch_block_t onPacketBufferFullBlock;
@property (nonatomic, copy) dispatch_block_t onPacketBufferEmptyBlock;
@property (atomic, assign) BOOL packetBufferIsFull;
@property (atomic, assign) BOOL packetBufferIsEmpty;

@end

@implementation  FFPlayer0x21

static int decode_interrupt_cb(void *ctx)
{
    FFPlayer0x21 *player = (__bridge FFPlayer0x21 *)ctx;
    return player.abort_request;
}

- (void)_stop
{
    //避免重复stop做无用功
    if (self.readThread) {
        
        self.abort_request = 1;
        audioq.abort_request = 1;
        videoq.abort_request = 1;
        sampq.abort_request = 1;
        pictq.abort_request = 1;
        
        [self.audioDecoder cancel];
        [self.videoDecoder cancel];
        [self.readThread cancel];
        [self.rendererThread cancel];
        
        [self.audioDecoder join];
        self.audioDecoder = nil;
        
        [self.videoDecoder join];
        self.videoDecoder = nil;
        
        [self.readThread join];
        self.readThread = nil;
        
        [self.rendererThread join];
        self.rendererThread = nil;
        
        packet_queue_destroy(&audioq);
        packet_queue_destroy(&videoq);
        
        frame_queue_destory(&pictq);
        frame_queue_destory(&sampq);
    }
    
    if (self.pixelBufferPool){
        CVPixelBufferPoolRelease(self.pixelBufferPool);
        self.pixelBufferPool = NULL;
    }
}

- (void)dealloc
{
    [self _stop];
}

//准备
- (void)prepareToPlay
{
    if (self.readThread) {
        NSAssert(NO, @"不允许重复创建");
    }
    
    //初始化视频包队列
    packet_queue_init(&videoq);
    //初始化音频包队列
    packet_queue_init(&audioq);
    //初始化ffmpeg相关函数
    init_ffmpeg_once();
    
    //初始化视频帧队列
    frame_queue_init(&pictq, VIDEO_PICTURE_QUEUE_SIZE, "pictq", 0);
    //初始化音频帧队列
    frame_queue_init(&sampq, SAMPLE_QUEUE_SIZE, "sampq", 0);
    
    self.readThread = [[MRThread alloc] initWithTarget:self selector:@selector(readPacketsFunc) object:nil];
    self.readThread.name = @"readPackets";
}

#pragma mark - 打开解码器创建解码线程

- (FFDecoder0x21 *)openStreamComponent:(AVFormatContext *)ic streamIdx:(int)idx
{
    FFDecoder0x21 *decoder = [FFDecoder0x21 new];
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
- (void)readPacketLoop:(AVFormatContext *)formatCtx {
    AVPacket pkt1, *pkt = &pkt1;
    //循环读包
    for (;;) {
        
        //调用了stop方法，则不再读包
        if (self.abort_request) {
            break;
        }
        
        /* 队列不满继续读，满了则休眠10 ms */
        if (audioq.size + videoq.size > MAX_QUEUE_SIZE
            || (stream_has_enough_packets(self.audioDecoder.stream, self.audioDecoder.streamIdx, &audioq) &&
                stream_has_enough_packets(self.videoDecoder.stream, self.videoDecoder.streamIdx, &videoq))) {
            
            if (!self.packetBufferIsFull) {
                self.packetBufferIsFull = YES;
                if (self.onPacketBufferFullBlock) {
                    self.onPacketBufferFullBlock();
                }
            }
            /* wait 10 ms */
            mr_usleep(10000);
            continue;
        }
        
        self.packetBufferIsFull = NO;
        //读包
        int ret = av_read_frame(formatCtx, pkt);
        //读包出错
        if (ret < 0) {
            //读到最后结束了
            if ((ret == AVERROR_EOF || avio_feof(formatCtx->pb)) && !eof) {
                //最后放一个空包进去
                if (self.audioDecoder.streamIdx >= 0) {
                    packet_queue_put_nullpacket(&audioq, self.audioDecoder.streamIdx);
                }
                    
                if (self.videoDecoder.streamIdx >= 0) {
                    packet_queue_put_nullpacket(&videoq, self.videoDecoder.streamIdx);
                }
                //标志为读包结束
                eof = 1;
            }
            
            if (formatCtx->pb && formatCtx->pb->error) {
                break;
            }
            /* wait 10 ms */
            mr_usleep(10000);
            continue;
        } else {
            //音频包入音频队列
            if (pkt->stream_index == self.audioDecoder.streamIdx) {
                packet_queue_put(&audioq, pkt);
            }
            //视频包入视频队列
            else if (pkt->stream_index == self.videoDecoder.streamIdx) {
                packet_queue_put(&videoq, pkt);
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

- (FFVideoScale0x21 *)createVideoScaleIfNeed
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
    
    //创建像素格式转换上下文
    FFVideoScale0x21 *scale = [[FFVideoScale0x21 alloc] initWithSrcPixFmt:format dstPixFmt:MRPixelFormat2AV(firstSupportedFmt) picWidth:self.videoDecoder.picWidth picHeight:self.videoDecoder.picHeight];
    return scale;
}

- (FFAudioResample0x21 *)createAudioResampleIfNeed
{
    //未指定期望音频格式
    if (self.supportedSampleFormats == MR_SAMPLE_FMT_MASK_NONE) {
        NSAssert(NO, @"supportedSampleFormats can't be none!");
        return nil;
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
    FFAudioResample0x21 *resample = [[FFAudioResample0x21 alloc] initWithSrcSampleFmt:format
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
    
    NSLog(@"avformat_find_stream_info coast time:%g",end-begin);
#endif
    
    //确定最优的音视频流
    int st_index[AVMEDIA_TYPE_NB];
    memset(st_index, -1, sizeof(st_index));
    [self findBestStreams:formatCtx result:&st_index];
    
    //打开音频解码器，创建解码线程
    if (st_index[AVMEDIA_TYPE_AUDIO] >= 0){
        
        self.audioDecoder = [self openStreamComponent:formatCtx streamIdx:st_index[AVMEDIA_TYPE_AUDIO]];
        
        if(self.audioDecoder){
            self.audioDecoder.delegate = self;
            self.audioDecoder.name = @"audioDecoder";
            self.audioResample = [self createAudioResampleIfNeed];
        } else {
            av_log(NULL, AV_LOG_ERROR, "can't open audio stream.\n");
            self.error = _make_nserror_desc(FFPlayerErrorCode_StreamOpenFailed, @"音频流打开失败！");
            [self performErrorResultOnMainThread];
            //出错了，销毁下相关结构体
            avformat_close_input(&formatCtx);
            return;
        }
        
        if ([self.delegate respondsToSelector:@selector(onInitAudioRender:)]) {
            if (self.audioResample) {
                [self.delegate onInitAudioRender:AVSampleFormat2MR(self.audioResample.out_sample_fmt)];
            } else {
                [self.delegate onInitAudioRender:AVSampleFormat2MR(self.audioDecoder.format)];
            }
        }
    }

    //打开视频解码器，创建解码线程
    if (st_index[AVMEDIA_TYPE_VIDEO] >= 0){
        self.videoDecoder = [self openStreamComponent:formatCtx streamIdx:st_index[AVMEDIA_TYPE_VIDEO]];
        if(self.videoDecoder){
            self.videoDecoder.delegate = self;
            self.videoDecoder.name = @"videoDecoder";
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

#pragma mark - FFDecoderDelegate0x21

- (int)decoder:(FFDecoder0x21 *)decoder wantAPacket:(AVPacket *)pkt
{
    if (decoder == self.audioDecoder) {
        return packet_queue_get(&audioq, pkt, 1);
    } else if (decoder == self.videoDecoder) {
        return packet_queue_get(&videoq, pkt, 1);
    } else {
        return -1;
    }
}

- (void)decoder:(FFDecoder0x21 *)decoder reveivedAFrame:(AVFrame *)frame
{
    if (decoder == self.audioDecoder) {
        FrameQueue *fq = &sampq;
        
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
        frame_queue_push(fq, outP, 0.0);
    } else if (decoder == self.videoDecoder) {
        FrameQueue *fq = &pictq;
        
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
        frame_queue_push(fq, outP, 0.0);
    }
}

#pragma mark - RendererThread

- (void)prepareRendererThread
{
    self.rendererThread = [[MRThread alloc] initWithTarget:self selector:@selector(rendererThreadFunc) object:nil];
    self.rendererThread.name = @"renderer";
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
    if ([self.delegate respondsToSelector:@selector(reveiveFrameToRenderer:)]) {
        @autoreleasepool {
            CVPixelBufferRef pixelBuffer = [self pixelBufferFromAVFrame:vp->frame];
            if (pixelBuffer) {
                [self.delegate reveiveFrameToRenderer:pixelBuffer];
            }
        }
    }
}

- (void)rendererThreadFunc
{
    //调用了stop方法，则不再渲染
    while (!self.abort_request) {
        
        NSTimeInterval begin = CFAbsoluteTimeGetCurrent();
        
        if (frame_queue_nb_remaining(&pictq) > 0) {
            Frame *vp = frame_queue_peek(&pictq);
            [self doDisplayVideoFrame:vp];
            frame_queue_pop(&pictq);
        }
        
        NSTimeInterval end = CFAbsoluteTimeGetCurrent();
        int cost = (end - begin) * 1000;
        av_log(NULL, AV_LOG_DEBUG, "render video frame cost:%dms\n", cost);
        mr_usleep(1000 * (40-cost));
    }
}

- (UInt32)fetchPacketSample:(uint8_t *)buffer
                  wantBytes:(UInt32)bufferSize
{
    UInt32 filled = 0;
    while (bufferSize > 0) {
        Frame *ap = NULL;
        //队列里缓存帧大于0，则取出
        if (frame_queue_nb_remaining(&sampq) > 0) {
            ap = frame_queue_peek(&sampq);
            av_log(NULL, AV_LOG_VERBOSE, "render audio frame %lld\n", ap->frame->pts);
        }
        
        if (NULL == ap) {
            return filled;
        }
        
        uint8_t *src = ap->frame->data[0];
        const int fmt = ap->frame->format;
        assert(0 == av_sample_fmt_is_planar(fmt));
        
        int data_size = av_samples_get_buffer_size(ap->frame->linesize, 2, ap->frame->nb_samples, fmt, 1);
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
        if (leftBytesToCopy >= left){
            //读取完毕，则清空；读取下一个包
            av_log(NULL, AV_LOG_DEBUG, "packet sample:next frame\n");
            frame_queue_pop(&sampq);
        }
    }
    return filled;
}

- (UInt32)fetchPlanarSample:(uint8_t *)l_buffer
                   leftSize:(UInt32)l_size
                      right:(uint8_t *)r_buffer
                  rightSize:(UInt32)r_size
{
    UInt32 filled = 0;
    while (l_size > 0 || r_size > 0) {
        Frame *ap = NULL;
        //队列里缓存帧大于0，则取出
        if (frame_queue_nb_remaining(&sampq) > 0) {
            ap = frame_queue_peek(&sampq);
            av_log(NULL, AV_LOG_VERBOSE, "render audio frame %lld\n", ap->frame->pts);
        }
        
        if (NULL == ap) {
            return filled;
        }
        
        uint8_t *l_src = ap->frame->data[0];
        const int fmt  = ap->frame->format;
        assert(av_sample_fmt_is_planar(fmt));
        
        int data_size = av_samples_get_buffer_size(ap->frame->linesize, 1, ap->frame->nb_samples, fmt, 1);
        
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
        
        if (leftBytesToCopy >= leftBytesLeft){
            //读取完毕，则清空；读取下一个包
            av_log(NULL, AV_LOG_DEBUG, "packet sample:next frame\n");
            frame_queue_pop(&sampq);
        }
    }
    return filled;
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

- (void)stop
{
    [self _stop];
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

- (NSString *)peekPacketBufferStatus
{
    return [NSString stringWithFormat:@"Packet Buffer is%@Full，audio(%d)，video(%d)",self.packetBufferIsFull ? @" " : @" not ",audioq.nb_packets,videoq.nb_packets];
}

@end
