//
//  FFPlayer0x04.m
//  FFmpegTutorial
//
//  Created by qianlongxu on 2020/5/10.
//

#import "FFPlayer0x04.h"
#import "MRRWeakProxy.h"
#import "FFPlayerInternalHeader.h"
#import "FFPlayerPacketHeader.h"

#include <libavutil/pixdesc.h>


@interface  FFPlayer0x04 ()
{
    //解码前的音频包缓存队列
    PacketQueue audioq;
    //解码前的视频包缓存队列
    PacketQueue videoq;
    
    //音频流索引
    int audio_stream;
    //视频流索引
    int video_stream;
    
    //音频流
    AVStream *audio_st;
    //视频流
    AVStream *video_st;
    
    //音频流解码器上下文
    AVCodecContext *audioCodecCtx;
    //视频流解码器上下文
    AVCodecContext *videoCodecCtx;
    
    //读包完毕？
    int eof;
}

///读包线程
@property (nonatomic, strong) NSThread *readThread;

///视频解码线程
@property (nonatomic, strong) NSThread *videoDecodeThread;

///音频解码线程
@property (nonatomic, strong) NSThread *audioDecodeThread;

@property (nonatomic, assign) int abort_request;
@property (nonatomic, copy) dispatch_block_t onErrorBlock;
@property (nonatomic, copy) dispatch_block_t onPacketBufferFullBlock;
@property (nonatomic, copy) dispatch_block_t onPacketBufferEmptyBlock;
@property (atomic, assign) BOOL packetBufferIsFull;
@property (atomic, assign) BOOL packetBufferIsEmpty;

@end

@implementation  FFPlayer0x04

static int decode_interrupt_cb(void *ctx)
{
    FFPlayer0x04 *player = (__bridge FFPlayer0x04 *)ctx;
    return player.abort_request;
}

- (void)_stop
{
    [self.readThread cancel];
    self.readThread = nil;
    
    [self.audioDecodeThread cancel];
    self.audioDecodeThread = nil;
       
    [self.videoDecodeThread cancel];
    self.videoDecodeThread = nil;
    
    self.abort_request = 1;
    audioq.abort_request = 1;
    videoq.abort_request = 1;
}

- (void)dealloc
{
    [self _stop];
}

///准备
- (void)prepareToPlay
{
    if (self.readThread) {
        NSAssert(NO, @"不允许重复创建");
    }
    video_stream = audio_stream = -1;
    ///初始化视频包队列
    packet_queue_init(&videoq);
    ///初始化音频包队列
    packet_queue_init(&audioq);
    ///初始化ffmpeg相关函数
    init_ffmpeg_once();
    
    ///避免NSThread和self相互持有，外部释放self时，NSThread延长self的生命周期，带来副作用！
    MRRWeakProxy *weakProxy = [MRRWeakProxy weakProxyWithTarget:self];
    ///不允许重复准备
    self.readThread = [[NSThread alloc] initWithTarget:weakProxy selector:@selector(readPacketsFunc) object:nil];
}

#pragma mark - Open Stream

- (int)openStreamComponent:(AVFormatContext *)ic streamIdx:(int)idx
{
    if (ic == NULL) {
        return -1;
    }
    if (idx < 0 || idx >= ic->nb_streams){
        return -1;
    }
    
    AVStream *stream = ic->streams[idx];
    AVCodecContext *avctx = avcodec_alloc_context3(NULL);
    if (!avctx) {
        return AVERROR(ENOMEM);
    }
    
    if (avcodec_parameters_to_context(avctx, stream->codecpar)) {
        avcodec_free_context(&avctx);
        return -1;
    }
    
    av_codec_set_pkt_timebase(avctx, stream->time_base);
    
    AVCodec *codec = avcodec_find_decoder(avctx->codec_id);
    if (!codec){
        avcodec_free_context(&avctx);
        return -1;
    }
    
    avctx->codec_id = codec->id;
    
    if (avcodec_open2(avctx, codec, NULL)) {
        avcodec_free_context(&avctx);
        return -1;
    }
    
    stream->discard = AVDISCARD_DEFAULT;
    
    switch (avctx->codec_type) {
        case AVMEDIA_TYPE_AUDIO:
        {
            audio_stream = idx;
            audio_st = stream;
            audioCodecCtx = avctx;
            [self prepareAudioDecodeThread];
        }
            break;
        case AVMEDIA_TYPE_VIDEO:
        {
            video_stream = stream->index;
            video_st = stream;
            videoCodecCtx = avctx;
            [self prepareVideoDecodeThread];
        }
            break;
        default:
            break;
    }
    return 0;
}

#pragma -mark 读包线程

- (void)readPacketsFunc
{
    if ([[NSThread currentThread] isCancelled]) {
        return;
    }
    
    NSParameterAssert(self.contentPath);
    
    @autoreleasepool {
        
        [[NSThread currentThread] setName:@"readPacket"];
        
        if (![self.contentPath hasPrefix:@"/"]) {
            _init_net_work_once();
        }
        
        AVFormatContext *formatCtx = avformat_alloc_context();
        
        if (!formatCtx) {
            self.error = _make_nserror_desc(FFPlayerErrorCode_AllocFmtCtxFailed, @"Could not allocate context.");
            [self performErrorResultOnMainThread];
            return;
        }
        
        formatCtx->interrupt_callback.callback = decode_interrupt_cb;
        formatCtx->interrupt_callback.opaque = (__bridge void *)self;
        
        /*
         打开输入流，读取文件头信息，不会打开解码器；
         */
        ///低版本是 av_open_input_file 方法
        const char *moviePath = [self.contentPath cStringUsingEncoding:NSUTF8StringEncoding];
        
        //打开文件流，读取头信息；
        if (0 != avformat_open_input(&formatCtx, moviePath , NULL, NULL)) {
            ///释放内存
            //当取消掉时，不给上层回调
            if (self.abort_request) {
                return;
            }
            avformat_free_context(formatCtx);
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
            return;
        }
        
    #if DEBUG
        NSTimeInterval end = [[NSDate date] timeIntervalSinceReferenceDate];
        ///用于查看详细信息，调试的时候打出来看下很有必要
        av_dump_format(formatCtx, 0, moviePath, false);
        
        NSLog(@"avformat_find_stream_info coast time:%g",end-begin);
    #endif
        
        int st_index[AVMEDIA_TYPE_NB];
        memset(st_index, -1, sizeof(st_index));
        
        int first_video_stream = -1;
        int first_h264_stream = -1;
        
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
        
        if (st_index[AVMEDIA_TYPE_VIDEO] < 0) {
            st_index[AVMEDIA_TYPE_VIDEO] = first_h264_stream != -1 ? first_h264_stream : first_video_stream;
        }
        
        st_index[AVMEDIA_TYPE_VIDEO] = av_find_best_stream(formatCtx, AVMEDIA_TYPE_VIDEO, st_index[AVMEDIA_TYPE_VIDEO], -1, NULL, 0);
        
        st_index[AVMEDIA_TYPE_AUDIO] = av_find_best_stream(formatCtx, AVMEDIA_TYPE_AUDIO, st_index[AVMEDIA_TYPE_AUDIO], st_index[AVMEDIA_TYPE_VIDEO], NULL, 0);
        
        
        if (st_index[AVMEDIA_TYPE_AUDIO] >= 0){
            if([self openStreamComponent:formatCtx streamIdx:st_index[AVMEDIA_TYPE_AUDIO]]){
                av_log(NULL, AV_LOG_ERROR, "can't open audio stream.");
                self.error = _make_nserror_desc(FFPlayerErrorCode_StreamOpenFailed, @"音频流打开失败！");
                [self performErrorResultOnMainThread];
                return;
            }
        }
        
        if (st_index[AVMEDIA_TYPE_VIDEO] >= 0){
            if([self openStreamComponent:formatCtx streamIdx:st_index[AVMEDIA_TYPE_VIDEO]]){
                av_log(NULL, AV_LOG_ERROR, "can't open video stream.");
                self.error = _make_nserror_desc(FFPlayerErrorCode_StreamOpenFailed, @"视频流打开失败！");
                [self performErrorResultOnMainThread];
                return;
            }
        }
        
        [self.audioDecodeThread start];
        [self.videoDecodeThread start];
        
        AVPacket pkt1, *pkt = &pkt1;
        ///循环读包
        for (;;) {
            
            ///调用了stop方法，线程被标记为取消了，则不再读包
            if ([[NSThread currentThread] isCancelled]) {
                break;
            }
            
            ///
            if (self.abort_request) {
                break;
            }
            
            /* 队列不满继续读，满了则休眠 */
            if (audioq.size + videoq.size > MAX_QUEUE_SIZE
                || (stream_has_enough_packets(audio_st, audio_stream, &audioq) &&
                    stream_has_enough_packets(video_st, video_stream, &videoq))) {
                
                if (!self.packetBufferIsFull) {
                    self.packetBufferIsFull = YES;
                    if (self.onPacketBufferFullBlock) {
                        self.onPacketBufferFullBlock();
                    }
                }
                /* wait 10 ms */
                usleep(10000);
                continue;
            }
            
            self.packetBufferIsFull = NO;
            ///读包
            int ret = av_read_frame(formatCtx, pkt);
            ///读包出错
            if (ret < 0) {
                //读到最后结束了
                if ((ret == AVERROR_EOF || avio_feof(formatCtx->pb)) && !eof) {
                    ///最后放一个空包进去
                    if (video_stream >= 0) {
                        packet_queue_put_nullpacket(&videoq, video_stream);
                    }
                        
                    if (audio_stream >= 0) {
                        packet_queue_put_nullpacket(&audioq, audio_stream);
                    }
                    //标志为读包结束
                    eof = 1;
                }
                
                if (formatCtx->pb && formatCtx->pb->error) {
                    break;
                }
                /* wait 10 ms */
                usleep(10000);
                continue;
            } else {
                //音频包入音频队列
                if (pkt->stream_index == audio_stream) {
                    audioq.serial ++;
                    packet_queue_put(&audioq, pkt);
                }
                //视频包入视频队列
                else if (pkt->stream_index == video_stream) {
                    videoq.serial ++;
                    packet_queue_put(&videoq, pkt);
                }
                //其他包释放内存忽略掉
                else {
                    av_packet_unref(pkt);
                }
            }
        }
        ///读包线程结束了，销毁下相关结构体
        avformat_close_input(&formatCtx);
    }
}

#pragma mark - 通用解码方法

- (int)decoder_decode_frame:(AVCodecContext *)avctx queue:(PacketQueue *)queue frame:(AVFrame*)frame {
    
    for (;;) {
        int ret;
        do {
            if (self.abort_request){
                return -1;
            }

            ret = avcodec_receive_frame(avctx, frame);
            
            if (ret >= 0){
                return 1;
            }
            
            if (ret == AVERROR_EOF) {
                avcodec_flush_buffers(avctx);
                return AVERROR_EOF;
            }
            
        } while (ret != AVERROR(EAGAIN));

        AVPacket pkt;
               
        int r = packet_queue_get(queue, &pkt, NULL, 1);
       
        if (r < 0)
        {
            return -1;
        }
        
        if (avcodec_send_packet(avctx, &pkt) == AVERROR(EAGAIN)) {
            av_log(avctx, AV_LOG_ERROR, "Receive_frame and send_packet both returned EAGAIN, which is an API violation.\n");
        }
        
        av_packet_unref(&pkt);
    }
}

#pragma mark - AudioDecodeThread

- (void)prepareAudioDecodeThread
{
    ///避免NSThread和self相互持有，外部释放self时，NSThread延长self的生命周期，带来副作用！
    MRRWeakProxy *weakProxy = [MRRWeakProxy weakProxyWithTarget:self];
    ///不允许重复准备
    self.audioDecodeThread = [[NSThread alloc] initWithTarget:weakProxy selector:@selector(audioDecodeFunc) object:nil];
}

- (void)audioDecodeFunc
{
    if ([[NSThread currentThread] isCancelled]) {
       return;
    }
       
    @autoreleasepool {
        [[NSThread currentThread] setName:@"audio_decode"];
        
        AVFrame *frame = av_frame_alloc();
        if (!frame) {
            av_log(NULL, AV_LOG_ERROR, "can't alloc a frame.");
            return;
        }
        do {
            int got_frame = [self decoder_decode_frame:audioCodecCtx queue:&audioq frame:frame];
            
            if (got_frame < 0) {
                if (got_frame == AVERROR_EOF) {
                    av_log(NULL, AV_LOG_ERROR, "decode frame eof.");
                } else {
                    av_log(NULL, AV_LOG_ERROR, "can't decode frame.");
                }
                break;
            } else {
                //
                av_log(NULL, AV_LOG_VERBOSE, "decode a audio frame:%lld\n",frame->pts);
                sleep(1);
            }
        } while (1);
        
        if (frame) {
            av_frame_free(&frame);
        }
        
        if (audioCodecCtx) {
            avcodec_free_context(&audioCodecCtx);
            audioCodecCtx = NULL;
        }

    }
}

#pragma mark - VideoDecodeThread

- (void)prepareVideoDecodeThread
{
    ///避免NSThread和self相互持有，外部释放self时，NSThread延长self的生命周期，带来副作用！
    MRRWeakProxy *weakProxy = [MRRWeakProxy weakProxyWithTarget:self];
    ///不允许重复准备
    self.videoDecodeThread = [[NSThread alloc] initWithTarget:weakProxy selector:@selector(videoDecodeFunc) object:nil];
}

- (void)videoDecodeFunc
{
    if ([[NSThread currentThread] isCancelled]) {
       return;
    }
       
    @autoreleasepool {
        [[NSThread currentThread] setName:@"video_decode"];
        AVFrame *frame = av_frame_alloc();
        if (!frame) {
            av_log(NULL, AV_LOG_ERROR, "can't alloc a frame.\n");
            return;
        }
        do {
            int got_frame = [self decoder_decode_frame:videoCodecCtx queue:&videoq frame:frame];
            
            if (got_frame < 0) {
                if (got_frame == AVERROR_EOF) {
                    av_log(NULL, AV_LOG_ERROR, "decode frame eof.\n");
                } else {
                    av_log(NULL, AV_LOG_ERROR, "can't decode frame.\n");
                }
                break;
            } else {
                //
                av_log(NULL, AV_LOG_VERBOSE, "decode a video frame:%lld\n",frame->pts);
                
                sleep(2);
            }
        } while (1);
        
        if (frame) {
            av_frame_free(&frame);
        }
        
        if (videoCodecCtx) {
            avcodec_free_context(&videoCodecCtx);
            videoCodecCtx = NULL;
        }
    }
}

- (void)performErrorResultOnMainThread
{
    if (![NSThread isMainThread]) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            if (self.onErrorBlock) {
                self.onErrorBlock();
            }
        }];
    } else {
        if (self.onErrorBlock) {
            self.onErrorBlock();
        }
    }
}

- (void)readPacket
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
