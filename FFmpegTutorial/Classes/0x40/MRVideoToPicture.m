//
//  MRVideoToPicture.m
//  FFmpegTutorial
//
//  Created by qianlongxu on 2020/6/2.
//

#import "MRVideoToPicture.h"
#import "MRThread.h"
#import "FFPlayerInternalHeader.h"
#import "FFPlayerPacketHeader.h"
#import "FFPlayerFrameHeader.h"
#import "MRDecoder.h"
#import "MRVideoScale.h"
#import "MRConvertUtil.h"

//视频时长；单位s
 kMRMovieInfoKey kMRMovieDuration = @"kMRMovieDuration";
//视频格式
 kMRMovieInfoKey kMRMovieFormat = @"kMRMovieFormat";
//视频宽；单位像素
kMRMovieInfoKey kMRMovieWidth = @"kMRMovieWidth";
//视频高；单位像素
kMRMovieInfoKey kMRMovieHeight = @"kMRMovieHeight";

@interface MRVideoToPicture ()<MRDecoderDelegate>
{
    //解码前的视频包缓存队列
    PacketQueue videoq;
    //解码后的视频帧缓存队列
    FrameQueue pictq;
    //读包完毕？
    int readEOF;
}

//读包线程
@property (nonatomic, strong) MRThread *readThread;
@property (nonatomic, strong) MRThread *rendererThread;

//视频解码器
@property (nonatomic, strong) MRDecoder *videoDecoder;
//图像格式转换/缩放器
@property (nonatomic, strong) MRVideoScale *videoScale;

@property (atomic, assign) int abort_request;
@property (atomic, assign) BOOL packetBufferIsFull;
@property (atomic, assign) BOOL packetBufferIsEmpty;
@property (nonatomic, assign) int frameCount;
@property (nonatomic, assign) int64_t lastPkts;
@property (nonatomic, assign) int64_t lastInterval;

@end

@implementation  MRVideoToPicture

static int decode_interrupt_cb(void *ctx)
{
    MRVideoToPicture *player = (__bridge MRVideoToPicture *)ctx;
    return player.abort_request;
}

- (void)_stop
{
    //避免重复stop做无用功
    if (self.readThread) {
        
        self.abort_request = 1;
        videoq.abort_request = 1;
        pictq.abort_request = 1;
        
        [self.videoDecoder cancel];
        [self.readThread cancel];
        
        [self.videoDecoder join];
        self.videoDecoder = nil;
        
        [self.readThread join];
        self.readThread = nil;
        
        [self.rendererThread join];
        self.rendererThread = nil;
        
        packet_queue_destroy(&videoq);
        frame_queue_destory(&pictq);
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
    //初始化ffmpeg相关函数
    init_ffmpeg_once();
    
    //初始化视频帧队列
    frame_queue_init(&pictq, VIDEO_PICTURE_QUEUE_SIZE, "pictq", 0);
    
    self.readThread = [[MRThread alloc] initWithTarget:self selector:@selector(readPacketsFunc) object:nil];
    self.readThread.name = @"readPackets";
}

#pragma mark - 打开解码器创建解码线程

- (MRDecoder *)openStreamComponent:(AVFormatContext *)ic streamIdx:(int)idx
{
    MRDecoder *decoder = [MRDecoder new];
    decoder.ic = ic;
    decoder.streamIdx = idx;
    if ([decoder open] == 0) {
        return decoder;
    } else {
        return nil;
    }
}

#pragma -mark 读包线程

- (int)seekTo:(AVFormatContext *)formatCtx sec:(long)sec
{
    if (sec < self.videoDecoder.duration) {
        int64_t seek_pos = sec * AV_TIME_BASE;
        int64_t seek_target = seek_pos;
        int64_t seek_min    = INT64_MIN;
        int64_t seek_max    = INT64_MAX;
        av_log(NULL, AV_LOG_ERROR,
               "seek to %ld\n",sec);
        int ret = avformat_seek_file(formatCtx, -1, seek_min, seek_target, seek_max, AVSEEK_FLAG_ANY);
        if (ret < 0) {
            av_log(NULL, AV_LOG_ERROR,
                   "error while seek to %ld\n",sec);
            return 1;
        } else {
            return 0;
        }
    } else {
        return -1;
    }
}

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
        if (videoq.size > MAX_QUEUE_SIZE
            || (stream_has_enough_packets(self.videoDecoder.stream, self.videoDecoder.streamIdx, &videoq))) {
            
            if (!self.packetBufferIsFull) {
                self.packetBufferIsFull = YES;
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
            if ((ret == AVERROR_EOF || avio_feof(formatCtx->pb)) && !readEOF) {
                //最后放一个空包进去
                if (self.videoDecoder.streamIdx >= 0) {
                    packet_queue_put_nullpacket(&videoq, self.videoDecoder.streamIdx);
                }
                //标志为读包结束
                readEOF = 1;
                break;
            }
            
            if (formatCtx->pb && formatCtx->pb->error) {
                break;
            }
            /* wait 10 ms */
            mr_usleep(10000);
            continue;
        } else {
            //视频包入视频队列
            if (pkt->stream_index == self.videoDecoder.streamIdx) {
                //lastPkts记录上一个关键帧的时间戳，避免seek后出现回退，解码出一样的图片！
                if ((pkt->flags & AV_PKT_FLAG_KEY) && (self.lastPkts < pkt->pts)) {
                    packet_queue_put(&videoq, pkt);
                    packet_queue_put_nullpacket(&videoq, pkt->stream_index);
                    self.frameCount ++;
                    self.lastInterval = pkt->pts - self.lastPkts;
                    self.lastPkts = pkt->pts;
                    //当帧间隔大于0时，采用seek方案
                    if (self.perferInterval > 0) {
                        long sec = self.perferInterval * self.frameCount;
                        if (-1 == [self seekTo:formatCtx sec:sec]) {
                            //标志为读包结束
                            readEOF = 1;
                        }
                    }
                } else {
//                    if (self.lastInterval > 0) {
//                        int sec = (self.lastInterval + pkt->pts) * av_q2d(self.videoDecoder.stream->time_base);
//                        av_packet_unref(pkt);
//                        self.lastInterval *= 2;
//                        if (self.lastInterval * av_q2d(self.videoDecoder.stream->time_base) < 1) {
//                            
//                            self.lastInterval += (int64_t)( 1 / av_q2d(self.videoDecoder.stream->time_base));
//                        };
//                        if (-1 == [self seekTo:formatCtx sec:sec]) {
//                            //标志为读包结束
//                            readEOF = 1;
//                        }
//                    } else
                    {
                        av_packet_unref(pkt);
                    }
                }
            } else {
                //其他包释放内存忽略掉
                av_packet_unref(pkt);
            }
        }
    }
}

#pragma mark - 查找最优的音视频流
- (void)findBestStreams:(AVFormatContext *)formatCtx result:(int (*) [AVMEDIA_TYPE_NB])st_index
{
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

- (MRVideoScale *)createVideoScaleIfNeed
{
    //未指定期望像素格式
    if (self.supportedPixelFormats == MR_PIX_FMT_MASK_NONE) {
        NSAssert(NO, @"supportedPixelFormats can't be none!");
        return nil;
    }
    
    //当前视频的像素格式
    const enum AVPixelFormat format = self.videoDecoder.pix_fmt;
    
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
        return nil;
    }
    
    if (firstSupportedFmt == MR_PIX_FMT_NONE) {
        NSAssert(NO, @"supportedPixelFormats is invalid!");
        return nil;
    }
    
    //创建像素格式转换上下文
    MRVideoScale *scale = [[MRVideoScale alloc] initWithSrcPixFmt:format dstPixFmt:MRPixelFormat2AV(firstSupportedFmt) picWidth:self.videoDecoder.picWidth picHeight:self.videoDecoder.picHeight];
    return scale;
}

- (void)readPacketsFunc
{
    if (![self.contentPath hasPrefix:@"/"]) {
        _init_net_work_once();
    }
    
    AVFormatContext *formatCtx = avformat_alloc_context();
    
    if (!formatCtx) {
        NSError* error = _make_nserror_desc(FFPlayerErrorCode_AllocFmtCtxFailed, @"创建 AVFormatContext 失败！");
        [self performErrorResultOnMainThread:error];
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
        NSError* error = _make_nserror_desc(FFPlayerErrorCode_OpenFileFailed, @"文件打开失败！");
        [self performErrorResultOnMainThread:error];
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
        NSError* error = _make_nserror_desc(FFPlayerErrorCode_StreamNotFound, @"不能找到流！");
        [self performErrorResultOnMainThread:error];
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

    //打开视频解码器，创建解码线程
    if (st_index[AVMEDIA_TYPE_VIDEO] >= 0){
        self.videoDecoder = [self openStreamComponent:formatCtx streamIdx:st_index[AVMEDIA_TYPE_VIDEO]];
        if(self.videoDecoder){
            self.videoDecoder.delegate = self;
            self.videoDecoder.name = @"videoDecoder";
            self.videoScale = [self createVideoScaleIfNeed];
        } else {
            av_log(NULL, AV_LOG_ERROR, "can't open video stream.");
            NSError* error = _make_nserror_desc(FFPlayerErrorCode_StreamOpenFailed, @"视频流打开失败！");
            [self performErrorResultOnMainThread:error];
            //出错了，销毁下相关结构体
            avformat_close_input(&formatCtx);
            return;
        }
    }
    
    if (self.delegate && [self.delegate respondsToSelector:@selector(vtp:videoOpened:)]) {
        NSMutableDictionary *info = [NSMutableDictionary dictionary];
        const char *name = formatCtx->iformat->name;
        if (NULL != name) {
            NSString *format = [NSString stringWithCString:name encoding:NSUTF8StringEncoding];
            if (format) {
                [info setObject:format forKey:kMRMovieFormat];
            }
        }
        [info setObject:@(self.videoDecoder.duration) forKey:kMRMovieDuration];
        [info setObject:@(self.videoDecoder.picWidth) forKey:kMRMovieWidth];
        [info setObject:@(self.videoDecoder.picHeight) forKey:kMRMovieHeight];
        [self.delegate vtp:self videoOpened:info];
    }
    
    //视频解码线程开始工作
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

#pragma mark - MRDecoderDelegate

- (int)decoder:(MRDecoder *)decoder wantAPacket:(AVPacket *)pkt
{
    if (decoder == self.videoDecoder) {
        return packet_queue_get(&videoq, pkt, 1);
    } else {
        return -1;
    }
}

- (void)decoder:(MRDecoder *)decoder reveivedAFrame:(AVFrame *)frame
{
    if (decoder == self.videoDecoder) {
        FrameQueue *fq = &pictq;
        
        AVFrame *outP = nil;
        if (self.videoScale) {
            if (![self.videoScale rescaleFrame:frame outFrame:&outP]) {
                NSError* error = _make_nserror_desc(FFPlayerErrorCode_RescaleFrameFailed, @"视频帧重转失败！");
                [self performErrorResultOnMainThread:error];
                return;
            }
        } else {
            outP = frame;
        }
        frame_queue_push(fq, outP, 0.0);
    }
}

- (BOOL)decoderHasMorePacket:(MRDecoder *)decoder
{
    if (videoq.nb_packets > 0) {
        return YES;
    } else {
        return !readEOF;
    }
}

- (void)decoderEOF:(MRDecoder *)decoder
{
    if (decoder == self.videoDecoder) {
        if (readEOF) {
            [self performErrorResultOnMainThread:nil];
        }
    }
}

#pragma mark - RendererThread

- (void)prepareRendererThread
{
    self.rendererThread = [[MRThread alloc] initWithTarget:self selector:@selector(rendererThreadFunc) object:nil];
    self.rendererThread.name = @"renderer";
}

- (void)doDisplayVideoFrame:(Frame *)vp
{
    if ([self.delegate respondsToSelector:@selector(vtp:convertAnImage:)]) {
        @autoreleasepool {
            av_log(NULL, AV_LOG_ERROR, "frame->pts:%d\n",(int)(vp->frame->pts * av_q2d(self.videoDecoder.stream->time_base)));
            CGImageRef img = [MRConvertUtil cgImageFromRGBFrame:vp->frame];
            [self.delegate vtp:self convertAnImage:img];
        }
        if (self.maxCount > 1 && self.frameCount >= self.maxCount) {
            [[NSOperationQueue mainQueue] addOperationWithBlock:^{
                [self stop];
            }];
        }
    }
}

- (void)rendererThreadFunc
{
    //调用了stop方法，则不再渲染
    while (!self.abort_request) {
        if (frame_queue_nb_remaining(&pictq) > 0) {
            Frame *vp = frame_queue_peek(&pictq);
            [self doDisplayVideoFrame:vp];
            frame_queue_pop(&pictq);
        }
    }
}

- (void)performErrorResultOnMainThread:(NSError*)error
{
    if (![NSThread isMainThread]) {
        [[NSOperationQueue mainQueue] addOperationWithBlock:^{
            [self performErrorResultOnMainThread:error];
        }];
    } else {
        if ([self.delegate respondsToSelector:@selector(vtp:convertFinished:)]) {
            [self.delegate vtp:self convertFinished:error];
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

- (NSString *)peekPacketBufferStatus
{
    return [NSString stringWithFormat:@"Packet Buffer is%@Full，video(%d)",self.packetBufferIsFull ? @" " : @" not ",videoq.nb_packets];
}

@end
