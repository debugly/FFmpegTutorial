//
//  MRVideoPlayer.m
//  FFmpeg004
//
//  Created by Matt Reach on 2018/2/10.
//  Copyright © 2018年 Awesome FFmpeg Study Demo. All rights reserved.
//

#import "MRVideoPlayer.h"
#import <libavutil/log.h>
#import <libavformat/avformat.h>
#import <libavcodec/avcodec.h>
#import <libavutil/pixdesc.h>
#import <libavutil/pixfmt.h>
#import <libavutil/samplefmt.h>
#import <libavutil/imgutils.h>

#import <AVFoundation/AVSampleBufferDisplayLayer.h>
#import "OpenGLView20.h"
#import "NSTimer+Util.h"
#import "MRVideoFrame.h"

#ifndef _weakSelf_SL
#define _weakSelf_SL     __weak   __typeof(self) $weakself = self;
#endif

#ifndef _strongSelf_SL
#define _strongSelf_SL   __strong __typeof($weakself) self = $weakself;
#endif

@interface MRVideoPlayer()

@property (assign, nonatomic) AVFormatContext *formatCtx;
@property (assign, nonatomic) AVCodecContext *codecCtx;

@property (assign, nonatomic) enum AVCodecID codecId_video;
@property (assign, nonatomic) unsigned int stream_index_video;
@property (assign, nonatomic) enum AVPixelFormat pix_fmt;
@property (assign, nonatomic) CGSize videoDimensions;

@property (strong, nonatomic) dispatch_queue_t io_queue;

@property (weak, nonatomic) OpenGLView20 *glView;
@property (assign, nonatomic) CGFloat videoTimeBase;
@property (strong, nonatomic) NSMutableArray *videoFrames;

@property (nonatomic,assign) AVCodecContext *videoCodecCtx;
@property (nonatomic,assign) unsigned int width;
@property (nonatomic,assign) unsigned int height;
@property (nonatomic,assign) BOOL bufferOk;

@property (copy, nonatomic) dispatch_block_t onBufferBlock;
@property (copy, nonatomic) dispatch_block_t onBufferOKBlock;

@end

@implementation MRVideoPlayer

static void fflog(void *context, int level, const char *format, va_list args){
//    @autoreleasepool {
//        NSString* message = [[NSString alloc] initWithFormat: [NSString stringWithUTF8String: format] arguments: args];
//        NSLog(@"ff:%d%@",level,message);
//    }
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _videoFrames = [NSMutableArray array];
    }
    return self;
}

- (void)dealloc
{
    if (NULL != _formatCtx) {
        avformat_close_input(&_formatCtx);
    }
}

- (void)addRenderToSuperView:(UIView *)superView
{
    OpenGLView20 *glView = [[OpenGLView20 alloc]initWithFrame:superView.bounds];
    [superView addSubview:glView];
    self.glView = glView;
    
    if (!CGSizeEqualToSize(_videoDimensions, CGSizeZero)) {
        CGSize vSize = superView.bounds.size;
        CGFloat vh = vSize.width * _videoDimensions.height / _videoDimensions.width;
        self.glView.frame = CGRectMake(0, (vSize.height-vh)/2, vSize.width , vh);
    }
}

- (void)removeRenderFromSuperView
{
    [self.glView removeFromSuperview];
    self.glView = nil;
}

- (void)playURLString:(NSString *)url
{
    _stream_index_video = -1;
    _videoFrames = [NSMutableArray array];
    
    av_log_set_callback(fflog);//日志比较多，打开日志后会阻塞当前线程
    //av_log_set_flags(AV_LOG_SKIP_REPEATED);

    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        
        ///初始化libavformat，注册所有文件格式，编解码库；这不是必须的，如果你能确定需要打开什么格式的文件，使用哪种编解码类型，也可以单独注册！
        av_register_all();
        
        NSString *moviePath = nil;//[[NSBundle mainBundle]pathForResource:@"test" ofType:@"mp4"];
        ///该地址可以是网络的也可以是本地的；
        moviePath = @"http://debugly.cn/repository/test.mp4";
        moviePath = @"http://192.168.3.2/ffmpeg-test/test.mp4";
        if ([moviePath hasPrefix:@"http"]) {
            //Using network protocols without global network initialization. Please use avformat_network_init(), this will become mandatory later.
            //播放网络视频的时候，要首先初始化下网络模块。
            avformat_network_init();
        }
        
        [self openStreamWithPath:moviePath completion:^(AVFormatContext *formatCtx){
            
            if(formatCtx){
                
                self.formatCtx = formatCtx;
                
                [self openVideoStream];
                [self startReadFrames];
                [self videoTick];
            }else{
                NSLog(@"不能打开流");
            }
        }];
    });
}

- (void)openVideoStream
{
    AVStream *stream = _formatCtx->streams[_stream_index_video];
    [self openVideoStream:stream];
}

- (void)openVideoStream:(AVStream *)stream
{
    AVCodecContext *codecCtx = stream->codec;
    // find the decoder for the video stream
    AVCodec *codec = avcodec_find_decoder(codecCtx->codec_id);
    if (!codec)
        return;
    // open codec
    if (avcodec_open2(codecCtx, codec, NULL) < 0)
        return;
    
    _videoCodecCtx = codecCtx;
    
    self.width = codecCtx->width;
    self.height = codecCtx->height;
    double fps = 0;
    avStreamFPSTimeBase(stream, 0.04, &fps, &_videoTimeBase);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.glView) {
            UIView *superView = self.glView.superview;
            CGSize vSize = superView.bounds.size;
            CGFloat vh = vSize.width * self.height / self.width;
            self.glView.frame = CGRectMake(0, (vSize.height-vh)/2, vSize.width , vh);
        }
    });
}

/**
 avformat_open_input 是个耗时操作因此放在异步线程里完成
 
 @param moviePath 视频地址
 @param completion open之后获取信息，然后回调
 */
- (void)openStreamWithPath:(NSString *)moviePath completion:(void(^)(AVFormatContext *formatCtx))completion
{
    AVFormatContext *formatCtx = NULL;
    
    /*
     打开输入流，读取文件头信息，不会打开解码器；
     */
    ///低版本是 av_open_input_file 方法
    if (0 != avformat_open_input(&formatCtx, [moviePath cStringUsingEncoding:NSUTF8StringEncoding], NULL, NULL)) {
        ///关闭，释放内存，置空
        avformat_close_input(&formatCtx);
        if (completion) {
            completion(NULL);
        }
    }else{
        /* 刚才只是打开了文件，检测了下文件头而已，并没有去找流信息；因此开始读包以获取流信息*/
        if (0 != avformat_find_stream_info(formatCtx, NULL)) {
            avformat_close_input(&formatCtx);
            if (completion) {
                completion(NULL);
            }
        }else{
            ///用于查看详细信息，调试的时候打出来看下很有必要
            av_dump_format(formatCtx, 0, [moviePath.lastPathComponent cStringUsingEncoding: NSUTF8StringEncoding], false);
            
            /* 接下来，尝试找到我们关心的信息*/
            
            NSMutableString *text = [[NSMutableString alloc]init];
            
            /*AVFormatContext 的 streams 变量是个数组，里面存放了 nb_streams 个元素，每个元素都是一个 AVStream */
            [text appendFormat:@"共%u个流，%llds",formatCtx->nb_streams,formatCtx->duration/AV_TIME_BASE];
            //遍历所有的流
            for (unsigned int  i = 0; i < formatCtx->nb_streams; i++) {
                
                AVStream *stream = formatCtx->streams[i];
                AVCodecContext *codec = stream->codec;
                
                switch (codec->codec_type) {
                        ///视频流
                    case AVMEDIA_TYPE_VIDEO:
                    {
                        _stream_index_video = i;
                    }
                        break;
                    default:
                    {
                        
                    }
                        break;
                }
            }
            
            if (completion) {
                completion(formatCtx);
            }
        }
    }
}

static void avStreamFPSTimeBase(AVStream *st, CGFloat defaultTimeBase, CGFloat *pFPS, CGFloat *pTimeBase)
{
    CGFloat fps, timebase;
    
    if (st->time_base.den && st->time_base.num)
        timebase = av_q2d(st->time_base);
    else if(st->codec->time_base.den && st->codec->time_base.num)
        timebase = av_q2d(st->codec->time_base);
    else
        timebase = defaultTimeBase;
    
    if (st->codec->ticks_per_frame != 1) {
        //timebase *= st->codec->ticks_per_frame;
    }
    
    if (st->avg_frame_rate.den && st->avg_frame_rate.num)
        fps = av_q2d(st->avg_frame_rate);
    else if (st->r_frame_rate.den && st->r_frame_rate.num)
        fps = av_q2d(st->r_frame_rate);
    else
        fps = 1.0 / timebase;
    
    if (pFPS)
        *pFPS = fps;
    if (pTimeBase)
        *pTimeBase = timebase;
}

# pragma mark - 播放速度控制

- (BOOL)checkIsBufferOK
{
    float buffedDuration = 0.0;
    static float kMinBufferDuration = 3;
    
    //如果没有缓冲好，那么就每隔0.1s过来看下buffer
    for (MRVideoFrame *frame in self.videoFrames) {
        buffedDuration += frame.duration;
        if (buffedDuration >= kMinBufferDuration) {
            break;
        }
    }
    
    return buffedDuration >= kMinBufferDuration;
}

- (void)videoTick
{
    if (self.bufferOk) {
        MRVideoFrame *videoFrame = nil;
        @synchronized(self) {
            videoFrame = [self.videoFrames firstObject];
            if (videoFrame) {
                [self.videoFrames removeObjectAtIndex:0];
            }
        }
        if (videoFrame) {
            
            [self handleOnBufferOK];
            
            float interval = videoFrame.duration;
            [self displayVideoFrame:videoFrame];
            const NSTimeInterval time = MAX(interval, 0.01);
            NSLog(@"after %fs tick",time);
            
            dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, time * NSEC_PER_SEC);
            dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
                [self videoTick];
            });
            return;
        }
    }
    
    {
        self.bufferOk = NO;
        [self handleOnBuffer];
        _weakSelf_SL
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
            _strongSelf_SL
            [self videoTick];
        });
    }
}

#pragma mark - read frame loop

- (void)startReadFrames
{
    if (!self.io_queue) {
        dispatch_queue_t io_queue = dispatch_queue_create("read-io", DISPATCH_QUEUE_SERIAL);
        self.io_queue = io_queue;
    }
    
    _weakSelf_SL
    dispatch_async(self.io_queue, ^{
        
        while (1) {
            
            AVPacket pkt;
            _strongSelf_SL
            if (av_read_frame(_formatCtx,&pkt) >= 0) {
                if (pkt.stream_index == _stream_index_video) {
                    
                    _weakSelf_SL
                    [self handleVideoPacket:&pkt completion:^(AVFrame *video_frame) {
                        _strongSelf_SL
                        
                        
                        if (video_frame->format == AV_PIX_FMT_YUV420P || video_frame->format == AV_PIX_FMT_YUVJ420P) {
                            
                            const double frameDuration = av_frame_get_pkt_duration(video_frame) * self.videoTimeBase;
                            MRVideoFrame *frame = [[MRVideoFrame alloc]init];
                            frame.duration = frameDuration;
                            frame.frame = video_frame;
                            
                            @synchronized(self) {
                                [self.videoFrames addObject:frame];
                                if (!self.bufferOk) {
                                    self.bufferOk = [self checkIsBufferOK];
                                }
                            }
                        }
                    }];
                }
            }else{
                NSLog(@"eof,stop read more frame!");
            }
            ///释放内存
            av_packet_unref(&pkt);
        }
    });
}

#pragma mark - decode video packet

- (void)handleVideoPacket:(AVPacket *)packet completion:(void(^)(AVFrame *video_frame))completion
{
    if (!completion) {
        return;
    }
    
    int gotframe = 0;
    AVFrame *video_frame = av_frame_alloc();//老版本是 avcodec_alloc_frame
    
    int len = avcodec_decode_video2(_videoCodecCtx, video_frame, &gotframe, packet);
    if (len < 0) {
        NSLog(@"decode video error, skip packet");
    }
    if (gotframe) {
        completion(video_frame);
    }
    //用完后记得释放掉
    av_frame_unref(video_frame);
}

#pragma mark - display video frame

- (void)displayVideoFrame:(MRVideoFrame *)frame
{
    NSTimeInterval begin = CFAbsoluteTimeGetCurrent();
    AVFrame *video_frame = frame.frame;
    [self.glView displayYUV420pData:video_frame];
    NSTimeInterval end = CFAbsoluteTimeGetCurrent();
    NSLog(@"displayVideoFrame an image cost :%g",end-begin);
}

- (void)handleOnBuffer
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.onBufferBlock) {
            self.onBufferBlock();
        }
    });
}

- (void)handleOnBufferOK
{
    dispatch_async(dispatch_get_main_queue(), ^{
        if (self.onBufferOKBlock) {
            self.onBufferOKBlock();
        }
    });
}

- (void)onBuffer:(dispatch_block_t)block
{
    self.onBufferBlock = block;
}

- (void)onBufferOK:(dispatch_block_t)block
{
    self.onBufferOKBlock = block;
}
@end
