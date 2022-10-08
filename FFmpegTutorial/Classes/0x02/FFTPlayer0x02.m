//
//  FFTPlayer0x02.m
//  FFmpegTutorial
//
//  Created by qianlongxu on 2020/4/26.
//

#import "FFTPlayer0x02.h"
#import "FFTThread.h"
#import "FFTDispatch.h"
#import "FFTAbstractLogger.h"
#import <libavutil/pixdesc.h>
#import <libavformat/avformat.h>

@interface FFTPlayer0x02 ()
//读包线程
@property (nonatomic, strong) FFTThread *readThread;
@property (nonatomic, copy) void (^completionBlock)(NSError * _Nullable, NSString * _Nullable);

@end

@implementation FFTPlayer0x02

- (void)_stop
{
    if (self.readThread) {
        [self.readThread cancel];
        [self.readThread join];
    }
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

- (void)prepareToPlay
{
    if (self.readThread) {
        NSAssert(NO, @"不允许重复创建");
    }
    
    
    
    __weak __typeof(self)weakSelf = self;
    self.readThread = [[FFTThread alloc] initWithBlock:^{
        [weakSelf openStreamFunc];
    }];
    
    self.readThread.name = @"openStream";
}

#pragma -mark 读包线程

- (void)openStreamFunc
{
    NSParameterAssert(self.contentPath);
    if (![self.contentPath hasPrefix:@"/"]) {
        avformat_network_init();
    }
    
    AVFormatContext *formatCtx = NULL;
    /*
     打开输入流，读取文件头信息，不会打开解码器；
     */
    //低版本是 av_open_input_file 方法
    const char *moviePath = [self.contentPath cStringUsingEncoding:NSUTF8StringEncoding];
    
    //打开文件流，读取头信息；
    if (0 != avformat_open_input(&formatCtx, moviePath , NULL, NULL)) {
        //关闭，释放内存，置空
        avformat_close_input(&formatCtx);
        self.error = _make_nserror_desc(FFPlayerErrorCode_OpenFileFailed, @"文件打开失败！");
        [self performResultOnMainThread:nil];
    } else {
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
            [self performResultOnMainThread:nil];
        } else {
#if DEBUG
            NSTimeInterval end = [[NSDate date] timeIntervalSinceReferenceDate];
            //用于查看详细信息，调试的时候打出来看下很有必要
            av_dump_format(formatCtx, 0, moviePath, false);
            MRFF_DEBUG_LOG(@"avformat_find_stream_info coast time:%g",end-begin);
#endif
            /* 接下来，尝试找到我们关心的信息*/
            NSMutableString *text = [[NSMutableString alloc]init];
            
            /*AVFormatContext 的 streams 变量是个数组，里面存放了 nb_streams 个元素，每个元素都是一个 AVStream */
            [text appendFormat:@"共 %u 个流，总时长: %lld 秒",formatCtx->nb_streams,formatCtx->duration/AV_TIME_BASE];
            //遍历所有的流
            for (int i = 0; i < formatCtx->nb_streams; i++) {
                
                AVStream *stream = formatCtx->streams[i];
                
                AVCodecContext *codecCtx = avcodec_alloc_context3(NULL);
                if (!codecCtx) {
                    continue;
                }
                
                int ret = avcodec_parameters_to_context(codecCtx, stream->codecpar);
                if (ret < 0) {
                    avcodec_free_context(&codecCtx);
                    continue;
                }
                
                //AVCodecContext *codec = stream->codec;
                enum AVMediaType codec_type = codecCtx->codec_type;
                switch (codec_type) {
                        //音频流
                    case AVMEDIA_TYPE_AUDIO:
                    {
                        //采样率
                        int sample_rate = codecCtx->sample_rate;
                        //声道数
                        int channels = codecCtx->channels;
                        //平均比特率
                        int64_t brate = codecCtx->bit_rate;
                        //时长
                        int duration = stream->duration * av_q2d(stream->time_base);
                        //解码器id
                        enum AVCodecID codecID = codecCtx->codec_id;
                        //根据解码器id找到对应名称
                        const char *codecDesc = avcodec_get_name(codecID);
                        //音频采样格式
                        enum AVSampleFormat format = codecCtx->sample_fmt;
                        //获取音频采样格式名称
                        const char * formatDesc = av_get_sample_fmt_name(format);
                        
                        [text appendFormat:@"\n\nAudio Stream：\n%d/%d；%d Kbps，%.1f KHz， %d channels，%s，%s，duration:%ds",stream->time_base.num,stream->time_base.den,(int)(brate/1000.0),sample_rate/1000.0,channels,codecDesc,formatDesc,duration];
                    }
                        break;
                        //视频流
                    case AVMEDIA_TYPE_VIDEO:
                    {
                        //画面宽度，单位像素
                        int vwidth = codecCtx->width;
                        //画面高度，单位像素
                        int vheight = codecCtx->height;
                        //比特率
                        int64_t brate = codecCtx->bit_rate;
                        //解码器id
                        enum AVCodecID codecID = codecCtx->codec_id;
                        //根据解码器id找到对应名称
                        const char *codecDesc = avcodec_get_name(codecID);
                        //视频像素格式
                        enum AVPixelFormat format = codecCtx->pix_fmt;
                        //获取视频像素格式名称
                        const char * formatDesc = av_get_pix_fmt_name(format);
                        //帧率
                        CGFloat fps, timebase = 0.04;
                        if (stream->time_base.den && stream->time_base.num) {
                            timebase = av_q2d(stream->time_base);
                        }
                        
                        if (stream->avg_frame_rate.den && stream->avg_frame_rate.num) {
                            fps = av_q2d(stream->avg_frame_rate);
                        }else if (stream->r_frame_rate.den && stream->r_frame_rate.num){
                            fps = av_q2d(stream->r_frame_rate);
                        }else{
                            fps = 1.0 / timebase;
                        }
                        //时长
                        int duration = stream->duration * av_q2d(stream->time_base);
                        [text appendFormat:@"\n\nVideo Stream：\n%d/%d；%dKbps，%d*%d，%dfps， %s， %s，duration:%ds",stream->time_base.num,stream->time_base.den,(int)(brate/1024.0),vwidth,vheight,(int)fps,codecDesc,formatDesc,duration];
                    }
                        break;
                    case AVMEDIA_TYPE_ATTACHMENT:
                    {
                        MRFF_DEBUG_LOG(@"附加信息流:%d",i);
                    }
                        break;
                    default:
                    {
                        MRFF_DEBUG_LOG(@"其他流:%d",i);
                    }
                        break;
                }
                avcodec_free_context(&codecCtx);
            }
            //关闭流
            avformat_close_input(&formatCtx);
            if (![[self readThread] isCanceled]) {
                [self performResultOnMainThread:text];
            }
        }
    }
}

- (void)performResultOnMainThread:(NSString *)info
{
    mr_sync_main_queue(^{
        if (self.completionBlock) {
            self.completionBlock(self.error, info);
        }
    });
}

- (void)openStream:(void (^)(NSError * _Nullable, NSString * _Nullable))completion
{
    self.completionBlock = completion;
    [self.readThread start];
}

- (void)asyncStop
{
    [self performSelectorInBackground:@selector(_stop) withObject:self];
}

@end
