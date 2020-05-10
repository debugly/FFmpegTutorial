//
//  FFPlayer0x03.m
//  FFmpegTutorial
//
//  Created by qianlongxu on 2020/4/27.
//

#import "FFPlayer0x03.h"
#import "MRRWeakProxy.h"
#import "FFPlayerInternalHeader.h"

#include <libavformat/avformat.h>
#include <libavutil/pixdesc.h>


@interface  FFPlayer0x03 ()
{
    PacketQueue videoq;
    PacketQueue audioq;
    
    int audio_stream;
    int video_stream;
    
    AVStream *audio_st;
    AVStream *video_st;
    //读包完毕？
    int eof;
}

///读包线程
@property (nonatomic, strong) NSThread *readThread;
@property (nonatomic, assign) int abort_request;
@property (nonatomic, copy) dispatch_block_t onErrorBlock;
@property (nonatomic, copy) dispatch_block_t onPacketBufferFullBlock;
@property (nonatomic, copy) dispatch_block_t onPacketBufferEmptyBlock;
@property (atomic, assign) BOOL packetBufferIsFull;
@property (atomic, assign) BOOL packetBufferIsEmpty;

@end

@implementation  FFPlayer0x03

- (void)_stop
{
    if ([self.readThread isExecuting]) {
        [self.readThread cancel];
        self.readThread = nil;
    }
}

- (void)dealloc
{
    [self _stop];
}

static void _init_net_work_once()
{
    static int flag = 0;
    if (flag == 0) {
        ///初始化网络模块
        avformat_network_init();
        flag = 1;
    }
}

static void init_ffmpeg_once()
{
    static int flag = 0;
    if (flag == 0) {
        //只对av_log_default_callback有效
        av_log_set_level(AV_LOG_VERBOSE);
        ///初始化 libavformat，注册所有的复用器，解复用器，协议协议！
        av_register_all();
        flag = 1;
    }
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

#pragma -mark 读包线程

static int decode_interrupt_cb(void *ctx)
{
    FFPlayer0x03 *player = (__bridge FFPlayer0x03 *)ctx;
    return player.abort_request;
}

- (void)readPacketsFunc
{
    NSParameterAssert(self.contentPath);
    
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
    //遍历所有的流
    for (NSInteger i = 0; i < formatCtx->nb_streams; i++) {
        
        AVStream *stream = formatCtx->streams[i];
        
        AVCodecContext *codecCtx = avcodec_alloc_context3(NULL);
        if (!codecCtx){
            continue;
        }
        
        int ret = avcodec_parameters_to_context(codecCtx, stream->codecpar);
        if (ret < 0){
            avcodec_free_context(&codecCtx);
            continue;
        }
        
        av_codec_set_pkt_timebase(codecCtx, stream->time_base);
        
        //AVCodecContext *codec = stream->codec;
        enum AVMediaType codec_type = codecCtx->codec_type;
        switch (codec_type) {
                ///音频流
            case AVMEDIA_TYPE_AUDIO:
            {
                audio_stream = stream->index;
                audio_st = stream;
            }
                break;
                ///视频流
            case AVMEDIA_TYPE_VIDEO:
            {
                video_stream = stream->index;
                video_st = stream;
            }
                break;
            case AVMEDIA_TYPE_ATTACHMENT:
            {
                NSLog(@"附加信息流:%ld",i);
            }
                break;
            default:
            {
                NSLog(@"其他流:%ld",i);
            }
                break;
        }
        
        avcodec_free_context(&codecCtx);
    }
    
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
            /* wait 10 ms */
//            SDL_LockMutex(wait_mutex);
//            SDL_CondWaitTimeout(is->continue_read_thread, wait_mutex, 10);
//            SDL_UnlockMutex(wait_mutex);
            if (!self.packetBufferIsFull) {
                self.packetBufferIsFull = YES;
                if (self.onPacketBufferFullBlock) {
                    self.onPacketBufferFullBlock();
                }
            }
            
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
            
//            SDL_LockMutex(wait_mutex);
//            SDL_CondWaitTimeout(is->continue_read_thread, wait_mutex, 10);
//            SDL_UnlockMutex(wait_mutex);
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

- (void)consumePackets
{
    AVPacket audio_pkt;
    int audio_not_empty = packet_queue_get(&audioq, &audio_pkt, NULL);
    if (audio_not_empty) {
        av_packet_unref(&audio_pkt);
    }
    AVPacket video_pkt;
    int video_not_empty = packet_queue_get(&videoq, &video_pkt, NULL);
    if (video_not_empty) {
        av_packet_unref(&video_pkt);
    }
    self.packetBufferIsFull = NO;
    if (!self.packetBufferIsEmpty) {
        if (!audio_not_empty && !video_not_empty) {
            if (self.onPacketBufferEmptyBlock) {
                self.onPacketBufferEmptyBlock();
            }
            self.packetBufferIsEmpty = YES;
        }
    }
}

- (void)consumeAllPackets
{
    packet_queue_flush(&audioq);
    packet_queue_flush(&videoq);
    self.packetBufferIsFull = NO;
    if (!self.packetBufferIsEmpty) {
        if (self.onPacketBufferEmptyBlock) {
            self.onPacketBufferEmptyBlock();
        }
        self.packetBufferIsEmpty = YES;
    }
}

@end
