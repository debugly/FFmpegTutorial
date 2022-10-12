//
//  FFTPlayer0x05.m
//  FFmpegTutorial
//
//  Created by qianlongxu on 2020/5/14.
//

#import "FFTPlayer0x05.h"
#import <libavutil/pixdesc.h>
#import <libavformat/avformat.h>
#import "FFTThread.h"
#import "FFTDispatch.h"
#import "FFTAbstractLogger.h"

@interface  FFTPlayer0x05 ()
{
    //音频流索引
    int _audio_stream;
    //视频流索引
    int _video_stream;
    
    //音频流解码器上下文
    AVCodecContext *_audioCodecCtx;
    //视频流解码器上下文
    AVCodecContext *_videoCodecCtx;
    
    //读包完毕？
    int _eof;
}

//读包线程
@property (nonatomic, strong) FFTThread *readThread;
@property (atomic, assign) int abort_request;
@property (nonatomic, copy) dispatch_block_t onErrorBlock;
@property (atomic, assign, readwrite) int videoPktCount;
@property (atomic, assign, readwrite) int audioPktCount;
@property (atomic, assign, readwrite) int videoFrameCount;
@property (atomic, assign, readwrite) int audioFrameCount;

@end

@implementation  FFTPlayer0x05

static int decode_interrupt_cb(void *ctx)
{
    FFTPlayer0x05 *player = (__bridge FFTPlayer0x05 *)ctx;
    return player.abort_request;
}

- (void)_stop
{
    //避免重复stop做无用功
    if (self.readThread) {
        self.abort_request = 1;
        [self.readThread cancel];
        [self.readThread join];
    }
    [self performSelectorOnMainThread:@selector(didStop:) withObject:self waitUntilDone:YES];
}

- (void)didStop:(id)sender
{
    //释放解码器上下文
    if (_audioCodecCtx) {
        avcodec_free_context(&_audioCodecCtx);
        _audioCodecCtx = NULL;
    }
    
    if (_videoCodecCtx) {
        avcodec_free_context(&_videoCodecCtx);
        _videoCodecCtx = NULL;
    }
    
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
    _video_stream = _audio_stream = -1;
    
    
    self.readThread = [[FFTThread alloc] initWithTarget:self selector:@selector(readPacketsFunc) object:nil];
    self.readThread.name = @"mr-read";
}

#pragma mark - 打开解码器创建解码线程

- (int)openStreamComponent:(AVFormatContext *)ic streamIdx:(int)idx
{
    if (ic == NULL) {
        return -1;
    }
    
    if (idx < 0 || idx >= ic->nb_streams){
        return -1;
    }
    
    AVStream *stream = ic->streams[idx];
    
    //创建解码器上下文
    AVCodecContext *avctx = avcodec_alloc_context3(NULL);
    if (!avctx) {
        return AVERROR(ENOMEM);
    }
    
    //填充下相关参数
    if (avcodec_parameters_to_context(avctx, stream->codecpar)) {
        avcodec_free_context(&avctx);
        return -1;
    }
    
    avctx->pkt_timebase = stream->time_base;
    
    //查找解码器
    AVCodec *codec = avcodec_find_decoder(avctx->codec_id);
    if (!codec){
        avcodec_free_context(&avctx);
        return -1;
    }
    
    avctx->codec_id = codec->id;
    
    //打开解码器
    if (avcodec_open2(avctx, codec, NULL)) {
        avcodec_free_context(&avctx);
        return -1;
    }
    
    stream->discard = AVDISCARD_DEFAULT;
    
    //根据流类型，准备相关线程
    switch (avctx->codec_type) {
        case AVMEDIA_TYPE_AUDIO:
        {
            _audio_stream = idx;
            _audioCodecCtx = avctx;
        }
            break;
        case AVMEDIA_TYPE_VIDEO:
        {
            _video_stream = stream->index;
            _videoCodecCtx = avctx;
        }
            break;
        default:
            break;
    }
    return 0;
}

#pragma -mark 读包线程

- (void)decodePkt:(AVFormatContext *)formatCtx frame:(AVFrame *)frame pkt:(AVPacket *)pkt
{
    AVStream *stream = formatCtx->streams[pkt->stream_index];
    switch (stream->codecpar->codec_type) {
        case AVMEDIA_TYPE_VIDEO:
        {
            if (pkt->data != NULL) {
                self.videoPktCount++;
            }
            int got_frame = [self decodeVideoPacket:pkt frame:frame];
            if (got_frame > 0) {
                self.videoFrameCount += got_frame;
                if (self.onDecoderFrame) {
                    self.onDecoderFrame(self.audioFrameCount,self.videoFrameCount);
                }
            }
        }
            break;
        case AVMEDIA_TYPE_AUDIO:
        {
            if (pkt->data != NULL) {
                self.audioPktCount++;
            }
            int got_frame = [self decodeAudioPacket:pkt frame:frame];
            if (got_frame > 0) {
                self.audioFrameCount += got_frame;
                if (self.onDecoderFrame) {
                    self.onDecoderFrame(self.audioFrameCount,self.videoFrameCount);
                }
            }
        }
            break;
        default:
            break;
    }
}

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
                pkt->stream_index = _video_stream;
                
                [self decodePkt:formatCtx frame:frame pkt:pkt];
                pkt->stream_index = _audio_stream;
                [self decodePkt:formatCtx frame:frame pkt:pkt];
                break;
            }
            
            if (formatCtx->pb && formatCtx->pb->error) {
                break;
            }
            
            /* wait 10 ms */
            mr_msleep(10);
            continue;
        } else {
            //解码
            [self decodePkt:formatCtx frame:frame pkt:pkt];
            //释放内存
            av_packet_unref(pkt);
            
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
        if([self openStreamComponent:formatCtx streamIdx:st_index[AVMEDIA_TYPE_AUDIO]]){
            av_log(NULL, AV_LOG_ERROR, "can't open audio stream.");
            self.error = _make_nserror_desc(FFPlayerErrorCode_StreamOpenFailed, @"音频流打开失败！");
            [self performErrorResultOnMainThread];
            //出错了，销毁下相关结构体
            avformat_close_input(&formatCtx);
            return;
        }
    }
    
    if (st_index[AVMEDIA_TYPE_VIDEO] >= 0){
        if([self openStreamComponent:formatCtx streamIdx:st_index[AVMEDIA_TYPE_VIDEO]]){
            av_log(NULL, AV_LOG_ERROR, "can't open video stream.");
            self.error = _make_nserror_desc(FFPlayerErrorCode_StreamOpenFailed, @"视频流打开失败！");
            [self performErrorResultOnMainThread];
            //出错了，销毁下相关结构体
            avformat_close_input(&formatCtx);
            return;
        }
    }
    
    //循环读包
    [self readPacketLoop:formatCtx];
    //读包线程结束了，销毁下相关结构体
    avformat_close_input(&formatCtx);
}

#pragma mark - 音视频通用解码方法

- (int)decoder_decode_frame:(AVCodecContext *)avctx pkt:(AVPacket *)pkt frame:(AVFrame*)frame count:(int *)outCount
{
    int frame_count = 0;
    int ret = 0;
    
    for (;;) {
        do {
            //停止时，直接返回
            if (self.abort_request){
                ret = -1;
                goto end;
            }
            //先尝试接收帧
            ret = avcodec_receive_frame(avctx, frame);
            
            //成功接收到一个解码帧
            if (ret >= 0){
                frame_count++;
                av_frame_unref(frame);
                continue;
            }
            
            //结束标志，此次并没有获取到frame！
            if (ret == AVERROR_EOF) {
                avcodec_flush_buffers(avctx);
                goto end;
            }
            
        } while (ret != AVERROR(EAGAIN)/*需要更多packet数据*/);
        
        if (pkt) {
            //发送给解码器去解码
            if (avcodec_send_packet(avctx, pkt) == AVERROR(EAGAIN)) {
                av_log(avctx, AV_LOG_ERROR, "Receive_frame and send_packet both returned EAGAIN, which is an API violation.\n");
            }
            pkt = NULL;
            continue;
        } else {
            break;
        }
    }
end:
    if (outCount) {
        *outCount = frame_count;
    }
    return ret;
}

#pragma mark - 音频解码

- (BOOL)decodeAudioPacket:(AVPacket *)pkt frame:(AVFrame *)frame
{
    //使用通用方法解码音频
    int got_frame;
    int r = [self decoder_decode_frame:_audioCodecCtx pkt:pkt frame:frame count:&got_frame];
    //解码出错
    if (r < 0) {
        if (r == AVERROR_EOF) {
            av_log(NULL, AV_LOG_ERROR, "audio decoder eof.\n");
        } else if (self.abort_request){
            av_log(NULL, AV_LOG_ERROR, "audio decoder cancel.\n");
        } else {
            av_log(NULL, AV_LOG_ERROR, "audio decoder decode err %d.\n",got_frame);
        }
    }
    return got_frame;
}

#pragma mark - 视频解码

- (int)decodeVideoPacket:(AVPacket *)pkt frame:(AVFrame *)frame
{
    //使用通用方法解码视频
    int got_frame;
    int r = [self decoder_decode_frame:_videoCodecCtx pkt:pkt frame:frame count:&got_frame];
    //解码出错
    if (r < 0) {
        if (r == AVERROR_EOF) {
            av_log(NULL, AV_LOG_ERROR, "video decoder eof.\n");
        } else if (self.abort_request){
            av_log(NULL, AV_LOG_ERROR, "video decoder cancel.\n");
        } else {
            av_log(NULL, AV_LOG_ERROR, "video decoder err %d.\n",got_frame);
        }
    }
    return got_frame;
}

- (void)performErrorResultOnMainThread
{
    mr_sync_main_queue(^{
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

@end
