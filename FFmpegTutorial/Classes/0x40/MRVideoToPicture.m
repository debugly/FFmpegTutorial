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
#import <ImageIO/ImageIO.h>

#if TARGET_OS_IOS
#import <MobileCoreServices/MobileCoreServices.h>
#endif

//视频时长；单位s
kMRMovieInfoKey kMRMovieDuration = @"kMRMovieDuration";
//视频格式
kMRMovieInfoKey kMRMovieContainerFmt = @"kMRMovieContainerFmt";
//视频宽；单位像素
kMRMovieInfoKey kMRMovieWidth = @"kMRMovieWidth";
//视频高；单位像素
kMRMovieInfoKey kMRMovieHeight = @"kMRMovieHeight";
//视频编码格式
kMRMovieInfoKey kMRMovieVideoFmt = @"kMRMovieVideoFmt";
//音频编码格式
kMRMovieInfoKey kMRMovieAudioFmt = @"kMRMovieAudioFmt";

@interface MRVideoToPicture ()<MRDecoderDelegate>
{
    //解码前的视频包缓存队列
    PacketQueue videoq;
    int64_t lastPkts;
    int lastSeekPos;
    int lastFramePts;//单位s
}

//读包线程
@property (nonatomic, strong) MRThread *workThread;
//视频解码器
@property (nonatomic, strong) MRDecoder *videoDecoder;
//音频解码器
@property (nonatomic, strong) MRDecoder *audioDecoder;
//图像格式转换/缩放器
@property (nonatomic, strong) MRVideoScale *videoScale;
//读包完毕？
@property (atomic, assign) BOOL readEOF;
@property (nonatomic, assign) int frameCount;
@property (nonatomic, assign) int pktCount;
@property (nonatomic, assign) int duration;

@end

@implementation  MRVideoToPicture

static int decode_interrupt_cb(void *ctx)
{
    MRVideoToPicture *player = (__bridge MRVideoToPicture *)ctx;
    return [player isAbort];
}

- (void)_stop
{
    //避免重复stop做无用功
    if (self.workThread) {
        
        videoq.abort_request = 1;
        
        [self.audioDecoder cancel];
        [self.videoDecoder cancel];
        [self.workThread cancel];
        
        self.audioDecoder = nil;
        self.videoDecoder = nil;
        
        [self.workThread join];
        self.workThread = nil;
        
        packet_queue_destroy(&videoq);
    }
}

- (void)dealloc
{
    [self _stop];
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        self.perferMaxCount = INT_MAX;
    }
    return self;
}

- (BOOL)isAbort
{
    return !self.workThread || [self.workThread isCanceled];
}

//准备
- (void)prepareToPlay
{
    if (self.workThread) {
        NSAssert(NO, @"不允许重复创建");
    }
    
    lastPkts = -1;
    lastSeekPos = -1;
    //初始化视频包队列
    packet_queue_init(&videoq);
    //初始化ffmpeg相关函数
    init_ffmpeg_once();

    self.workThread = [[MRThread alloc] initWithTarget:self selector:@selector(workFunc) object:nil];
    self.workThread.name = @"readPackets";
}

#pragma mark - 打开解码器创建解码线程

- (MRDecoder *)dumpStreamComponent:(AVFormatContext *)ic streamIdx:(int)idx
{
    MRDecoder *decoder = [MRDecoder new];
    decoder.ic = ic;
    decoder.streamIdx = idx;
    [decoder dumpStreamFormat];
    return decoder;
}

#pragma -mark 读包逻辑

- (int)seekTo:(AVFormatContext *)formatCtx sec:(int)sec
{
    if (sec < self.duration) {
        int64_t seek_pos = sec * AV_TIME_BASE;
        int64_t seek_target = seek_pos;
        int64_t seek_min    = INT64_MIN;
        int64_t seek_max    = INT64_MAX;
        av_log(NULL, AV_LOG_INFO,
               "seek to %d\n",sec);
        
        int ret = avformat_seek_file(formatCtx, -1, seek_min, seek_target, seek_max, AVSEEK_FLAG_ANY);
        if (ret < 0) {
            av_log(NULL, AV_LOG_ERROR,
                   "error while seek to %d\n",sec);
            return 1;
        } else {
            return 0;
        }
    } else {
        av_log(NULL, AV_LOG_ERROR,
               "ignore error seek to %d/%d\n",sec,self.duration);
        return -1;
    }
}

//读包循环
- (void)readPacketLoop:(AVFormatContext *)formatCtx
{
    AVPacket pkt1, *pkt = &pkt1;
    //循环读包，读满了就停止
    for (;;) {

        //调用了stop方法，则不再读包
        if ([self isAbort]) {
            break;
        }
        
        //已经读完了
        if (self.readEOF) {
            break;
        }
        
        /* 队列不满继续读，满了则休眠10 ms */
        if (videoq.size > 1 * 1024 * 1024
            || (stream_has_enough_packets(self.videoDecoder.stream, self.videoDecoder.streamIdx, &videoq))) {
            break;
        }
        //读包
        int ret = av_read_frame(formatCtx, pkt);
        //读包出错
        if (ret < 0) {
            //读到最后结束了
            if ((ret == AVERROR_EOF || avio_feof(formatCtx->pb)) && !self.readEOF) {
                //最后放一个空包进去
                if (self.videoDecoder.streamIdx >= 0) {
                    packet_queue_put_nullpacket(&videoq, self.videoDecoder.streamIdx);
                }
                //标志为读包结束
                av_log(NULL, AV_LOG_INFO,"real read eof\n");
                self.readEOF = YES;
                break;
            }
            
            if (formatCtx->pb && formatCtx->pb->error) {
                break;
            }
            break;
        } else {
            //视频包入视频队列
            if (pkt->stream_index == self.videoDecoder.streamIdx) {
                
                //gif 不能按关键帧处理
                if (![self.videoDecoder.codecName isEqualToString:@"gif"]) {
                    if (!(pkt->flags & AV_PKT_FLAG_KEY)) {
                        av_packet_unref(pkt);
                        continue;
                    }
                }
                
                //没有pts，则使用dts当做pts
                if (AV_NOPTS_VALUE == pkt->pts && AV_NOPTS_VALUE != pkt->dts) {
                    pkt->pts = pkt->dts;
                }
                
                //lastPkts记录上一个关键帧的时间戳，避免seek后出现回退，解码出一样的图片！
                if (AV_NOPTS_VALUE != pkt->pts) {

                    AVRational tb = self.videoDecoder.stream->time_base;
                    int64_t pts = lround(pkt->pts * av_q2d(tb));
                    
                    if (lastPkts < pts) {
                        lastPkts = pts;
                        
                        NSLog(@"xql pts:%lld",pts);
                        packet_queue_put(&videoq, pkt);
                        packet_queue_put_nullpacket(&videoq, pkt->stream_index);
                        self.pktCount ++;
                        if (!self.perferUseSeek) {
                            lastPkts += self.perferInterval;
                        }
                    } else {
                        av_packet_unref(pkt);
                    }
//                    packet_queue_put(&videoq, pkt);
//                    packet_queue_put_nullpacket(&videoq, pkt->stream_index);
//                    self.pktCount ++;
//                    if (!self.perferUseSeek) {
//                        lastPkts += self.perferInterval;
//                    }
                } else if(AV_NOPTS_VALUE != pkt->dts) {
                    if (lastPkts < pkt->dts) {
                        lastPkts = pkt->dts;
                        packet_queue_put(&videoq, pkt);
                        packet_queue_put_nullpacket(&videoq, pkt->stream_index);
                        self.pktCount ++;
                    } else {
                        av_packet_unref(pkt);
                    }
                } else {
                    packet_queue_put(&videoq, pkt);
                    packet_queue_put_nullpacket(&videoq, pkt->stream_index);
                    self.pktCount ++;
                }
                
                //当帧间隔大于10s时，时长大于 1min 才采用seek方案
                if (self.perferUseSeek && self.perferInterval > 10 && self.duration > 60) {
                    int sec = self.perferInterval * self.pktCount;
                    //对于seek间隔很小的视频，seek后很可能回退，因此要想办法避免回退，避免ABAB循环导致的seek死循环
                    if (sec <= lastSeekPos) {
                        sec = lastSeekPos + self.perferInterval;
                    }
                    lastSeekPos = sec;
                    if (-1 == [self seekTo:formatCtx sec:sec]) {
                        //标志为读包结束
                        av_log(NULL, AV_LOG_INFO,"logic read eof\n");
                        self.readEOF = YES;
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
        //这里设置为了丢弃所有帧，解码器里会进行修改！
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

- (void)createVideoScaleIfNeed
{
    if (self.videoScale) {
        return;
    }
    //未指定期望像素格式
    if (self.supportedPixelFormats == MR_PIX_FMT_MASK_NONE) {
        NSAssert(NO, @"supportedPixelFormats can't be none!");
        return;
    }
    
    //当前视频的像素格式
    const enum AVPixelFormat format = self.videoDecoder.pix_fmt;
    
    //测试过程中有的视频没有获取到像素格式，单视频实际上有，等到解码出来后再次走下这个逻辑
    if (format == AV_PIX_FMT_NONE) {
        return;
    }
    
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
        return;
    }
    
    if (firstSupportedFmt == MR_PIX_FMT_NONE) {
        NSAssert(NO, @"supportedPixelFormats is invalid!");
        return;
    }
    
    //创建像素格式转换上下文
    self.videoScale = [[MRVideoScale alloc] initWithSrcPixFmt:format dstPixFmt:MRPixelFormat2AV(firstSupportedFmt) picWidth:self.videoDecoder.picWidth picHeight:self.videoDecoder.picHeight];
}

- (void)workFunc
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
        if ([self isAbort]) {
            return;
        }
        NSError* error = _make_nserror_desc(FFPlayerErrorCode_OpenFileFailed, @"文件打开失败！");
        [self performErrorResultOnMainThread:error];
        return;
    }
    
    /* 刚才只是打开了文件，检测了下文件头而已，并不知道流信息；因此开始读包以获取流信息
     设置读包探测大小和最大时长，避免读太多的包！
    */
    formatCtx->probesize = 1024 * 1024;
    formatCtx->max_analyze_duration = 10 * AV_TIME_BASE;
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
    
    NSMutableDictionary *dumpDic = [NSMutableDictionary dictionary];
    const char *name = formatCtx->iformat->name;
    if (NULL != name) {
        NSString *format = [NSString stringWithCString:name encoding:NSUTF8StringEncoding];
        if (format) {
            [dumpDic setObject:format forKey:kMRMovieContainerFmt];
        }
    }
    self.duration = (int)(formatCtx->duration / 1000000);
    [dumpDic setObject:@(self.duration) forKey:kMRMovieDuration];
    
    //创建解码器
    if (st_index[AVMEDIA_TYPE_VIDEO] >= 0) {
        MRDecoder *videoDecoder = [self dumpStreamComponent:formatCtx streamIdx:st_index[AVMEDIA_TYPE_VIDEO]];
        
        [dumpDic setObject:@(videoDecoder.picWidth) forKey:kMRMovieWidth];
        [dumpDic setObject:@(videoDecoder.picHeight) forKey:kMRMovieHeight];
        
        if (videoDecoder.codecName) {
            [dumpDic setObject:videoDecoder.codecName forKey:kMRMovieVideoFmt];
        }
        
        if ([videoDecoder open]) {
            self.videoDecoder = videoDecoder;
            self.videoDecoder.delegate = self;
            self.videoDecoder.name = @"videoDecoder";
            [self createVideoScaleIfNeed];
        }
    }
    
    //创建解码器
    if (st_index[AVMEDIA_TYPE_AUDIO] >= 0) {
        MRDecoder *audioDecoder = [self dumpStreamComponent:formatCtx streamIdx:st_index[AVMEDIA_TYPE_AUDIO]];
        
        if (audioDecoder.codecName) {
            [dumpDic setObject:audioDecoder.codecName forKey:kMRMovieAudioFmt];
        }
        
        //目前抽帧没必要打开音频流解码器
//        if([audioDecoder open]){
//            self.audioDecoder = audioDecoder;
//            self.audioDecoder.delegate = self;
//            self.audioDecoder.name = @"audioDecoder";
//        } else {
//            av_log(NULL, AV_LOG_ERROR, "can't open audio stream.");
//        }
    }
    
    //这里采用同步目的是为了，让代理能够修改 vtp 的属性，比如根据视频时长修改perferInterval等
    dispatch_sync(dispatch_get_main_queue(), ^{
        if (self.delegate && [self.delegate respondsToSelector:@selector(vtp:videoOpened:)]) {
            [self.delegate vtp:self videoOpened:dumpDic];
        }
        if (self.onVideoOpenedBlock) {
            self.onVideoOpenedBlock(self, dumpDic);
        }
    });

    if (self.videoDecoder) {
        //视频解码线程开始工作，读包完全由解码器控制，解码后转成图片也由解码回调控制
        [self.videoDecoder start];
        //解码线程结束了，销毁下相关结构体
        avformat_close_input(&formatCtx);
    } else {
        //出错了，销毁下相关结构体
        avformat_close_input(&formatCtx);
        //有的视频只有一个头，没有包也不能打开解码器；有的是编码格式不支持
        NSString *videoFmt = dumpDic[kMRMovieVideoFmt];
        NSString *msg = [NSString stringWithFormat:@"can't open [%@] video stream",videoFmt];
        av_log(NULL, AV_LOG_ERROR, "%s\n",[msg UTF8String]);
        
        NSError* error = _make_nserror_desc(FFPlayerErrorCode_StreamOpenFailed, msg);
        [self performErrorResultOnMainThread:error];
    }
}

#pragma mark - MRDecoderDelegate

- (int)decoder:(MRDecoder *)decoder wantAPacket:(AVPacket *)pkt
{
    if ([self isAbort]) {
        return -1;
    }
    
    if (decoder == self.videoDecoder) {
        int ret = -1;
        do {
            int r = packet_queue_get(&videoq, pkt, 0);
            if (r == 1) {
                ret = 1;
                break;
            } else if (r == 0 && !self.readEOF) {
                //不能从队列里获取pkt，就去读取
                [self readPacketLoop:decoder.ic];
            } else {
                break;
            }
        } while (1);
        return ret;
    } else {
        return -1;
    }
}

- (void)decoder:(MRDecoder *)decoder reveivedAFrame:(AVFrame *)frame
{
    if (decoder == self.videoDecoder) {
        AVFrame *outP = nil;
        
        const enum AVPixelFormat format = self.videoDecoder.pix_fmt;
        
        //测试过程中有的视频没有获取到像素格式，单视频实际上有，等到解码出来后再次走下这个逻辑
        if (format == AV_PIX_FMT_NONE && frame->format != AV_PIX_FMT_NONE) {
            self.videoDecoder.pix_fmt = frame->format;
            [self createVideoScaleIfNeed];
        }
        
        if (self.videoScale) {
            if (![self.videoScale rescaleFrame:frame outFrame:&outP]) {
                NSError* error = _make_nserror_desc(FFPlayerErrorCode_RescaleFrameFailed, @"视频帧重转失败！");
                [self performErrorResultOnMainThread:error];
                return;
            }
        } else {
            outP = frame;
        }
        
        [self convertToPic:outP];
    }
}

- (BOOL)decoderHasMorePacket:(MRDecoder *)decoder
{
    if (videoq.nb_packets > 0) {
        return YES;
    } else {
        return !self.readEOF;
    }
}

- (void)decoderEOF:(MRDecoder *)decoder
{
    if (decoder == self.videoDecoder) {
        if (self.readEOF) {
            [self performErrorResultOnMainThread:nil];
        }
    }
}

- (BOOL)saveAsJpeg:(CGImageRef _Nonnull)img path:(NSString *)path
{
    CFStringRef imageUTType = kUTTypeJPEG;
    NSURL *fileUrl = [NSURL fileURLWithPath:path];
    CGImageDestinationRef destination = CGImageDestinationCreateWithURL((__bridge CFURLRef) fileUrl, imageUTType, 1, NULL);
    if (destination) {
        CGImageDestinationAddImage(destination, img, NULL);
        CGImageDestinationFinalize(destination);
        CFRelease(destination);
        return YES;
    }
    return NO;
}

- (NSString *)picSaveDir
{
    if (!_picSaveDir) {
        _picSaveDir = NSTemporaryDirectory();
    }
    return _picSaveDir;
}

- (NSString *)convertAngSaveAsJPEG:(AVFrame *)frame
{
    NSString *imgPath = nil;
    @autoreleasepool {
        CGImageRef img = [MRConvertUtil cgImageFromRGBFrame:frame];
        if (img) {
            int64_t time = [[NSDate date] timeIntervalSince1970] * 10000;
            NSString *fileName = [NSString stringWithFormat:@"%lld.jpg",time];
            NSString *_imgPath = [self.picSaveDir stringByAppendingPathComponent:fileName];
            if ([self saveAsJpeg:img path:_imgPath]) {
                imgPath = _imgPath;
            }
        }
    }
    return imgPath;
}

- (void)convertToPic:(AVFrame *)frame
{
    if (!self.videoDecoder) {
        return;
    }
    
    NSString * imgPath = nil;
    BOOL hasPts = YES;
    if (frame->pts != AV_NOPTS_VALUE) {
        int sec = (int)(frame->pts * av_q2d(self.videoDecoder.stream->time_base));
        if (lastFramePts < sec) {
            av_log(NULL, AV_LOG_DEBUG, "frame->pts:%ds\n",sec);
            imgPath = [self convertAngSaveAsJPEG:frame];
            lastFramePts = sec + self.perferInterval;
        } else {
            av_log(NULL, AV_LOG_DEBUG, "ignored frame->pts:%ds\n",sec);
        }
    } else {
        // 没有pts
        hasPts = NO;
        imgPath = [self convertAngSaveAsJPEG:frame];
    }
    
    if (!imgPath) {
        return;
    }
    
    dispatch_sync(dispatch_get_main_queue(), ^{
        self.frameCount++;
        
        if ([self.delegate respondsToSelector:@selector(vtp:convertAnImage:)]) {
            [self.delegate vtp:self convertAnImage:imgPath];
        }
        
        if (self.onConvertAnImageBlock) {
            self.onConvertAnImageBlock(self, imgPath);
        }
        
        //有pts的时候有保障，才提前停止
        if (hasPts && self.frameCount >= self.perferMaxCount) {
            [self stop];
            //主动回调下
            [self performErrorResultOnMainThread:nil];
        }
    });
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
        
        if (self.onConvertFinishedBlock) {
            self.onConvertFinishedBlock(self, error);
        }
    }
}

- (void)startConvert
{
    NSParameterAssert(self.contentPath);
    [self.workThread start];
}

- (void)stop
{
    [self _stop];
}

@end
