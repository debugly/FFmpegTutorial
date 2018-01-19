//
//  MRVideoPlayer.m
//  FFmpeg004
//
//  Created by 许乾隆 on 2018/1/19.
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


//是否使用ffmpeg3新的解密函数
#define use_v3 1


#define OPENGL 1
#define IMAGE  2
#define LAYER  3

#define RENDER OPENGL

@interface MRVideoPlayer()

@property (assign, nonatomic) AVFormatContext *formatCtx;
@property (assign, nonatomic) AVCodecContext *codecCtx;

@property (assign, nonatomic) enum AVCodecID codecId_video;
@property (assign, nonatomic) unsigned int stream_index_video;
@property (assign, nonatomic) enum AVPixelFormat pix_fmt;
@property (assign, nonatomic) CGSize videoDimensions;

@property (strong, nonatomic) dispatch_queue_t io_queue;

@property (assign, nonatomic) CVPixelBufferPoolRef pixelBufferPool;
@property (strong, nonatomic) UIImageView *render;
@property (strong, nonatomic) AVSampleBufferDisplayLayer *sampleBufferDisplayLayer;
@property (weak, nonatomic) OpenGLView20 *glView;
@property (assign, nonatomic) CGFloat videoTimeBase;
@property (assign, nonatomic) CGFloat fps;
@property (weak, nonatomic) NSTimer *readFramesTimer;
@property (strong, nonatomic) NSMutableArray *videoFrames;

@end

@implementation MRVideoPlayer

static void fflog(void *context, int level, const char *format, va_list args){
    @autoreleasepool {
        NSString* message = [[NSString alloc] initWithFormat: [NSString stringWithUTF8String: format] arguments: args];
        
        //        NSLog(@"ff:%d%@",level,message);
    }
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
    if (self.readFramesTimer) {
        [self.readFramesTimer invalidate];
    }
}

- (void)addRenderToSuperView:(UIView *)superView
{
#if RENDER == OPENGL
    OpenGLView20 *glView = [[OpenGLView20 alloc]initWithFrame:superView.bounds];
    [superView addSubview:glView];
    self.glView = glView;
    
    if (!CGSizeEqualToSize(_videoDimensions, CGSizeZero)) {
        CGSize vSize = superView.bounds.size;
        CGFloat vh = vSize.width * _videoDimensions.height / _videoDimensions.width;
        self.glView.frame = CGRectMake(0, (vSize.height-vh)/2, vSize.width , vh);
    }
#elif RENDER == IMAGE
    if (superView) {
        self.render = [[UIImageView alloc]init];
        self.render.frame = superView.bounds;
        self.render.contentMode = UIViewContentModeScaleAspectFit;
        [superView addSubview:self.render];
    }
#elif RENDER == LAYER
    self.sampleBufferDisplayLayer = [[AVSampleBufferDisplayLayer alloc] init];
    self.sampleBufferDisplayLayer.frame = superView.bounds;
    self.sampleBufferDisplayLayer.position = CGPointMake(CGRectGetMidX(superView.bounds), CGRectGetMidY(superView.bounds));
    self.sampleBufferDisplayLayer.videoGravity = AVLayerVideoGravityResizeAspect;
    self.sampleBufferDisplayLayer.opaque = YES;
    [superView.layer addSublayer:self.sampleBufferDisplayLayer];
#endif
}

- (void)removeRenderFromSuperView
{
#if RENDER == OPENGL
    [self.glView removeFromSuperview];
    self.glView = nil;
#elif RENDER == IMAGE
    [self.render removeFromSuperview];
    self.render = nil;
#elif RENDER == LAYER
    [self.sampleBufferDisplayLayer removeFromSuperlayer];
    self.sampleBufferDisplayLayer = nil;
#endif
}

- (void)playURLString:(NSString *)url
{
    [self openStram:url];
    [self tick];
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

- (void)tick
{
    MRVideoFrame *frame = nil;
    @synchronized(self) {
        
        //如果没有缓冲好，那么就每隔0.1s过来看下buffer
        if ([self.videoFrames count] < 3) {
            _weakSelf_SL
            dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(0.1 * NSEC_PER_SEC)), dispatch_get_main_queue(), ^{
                _strongSelf_SL
                [self tick];
            });
            return;
        }
        
        frame = [self.videoFrames firstObject];
        [self.videoFrames removeObjectAtIndex:0];
    }
    
    float interval = frame.duration;
    [self displayVideoFrame:frame];
    const NSTimeInterval time = MAX(interval, 0.01);
//    NSLog(@"after %fs tick",time);
    
    dispatch_time_t popTime = dispatch_time(DISPATCH_TIME_NOW, time * NSEC_PER_SEC);
    dispatch_after(popTime, dispatch_get_main_queue(), ^(void){
        [self tick];
    });
}

- (void)openStram:(NSString *)moviePath
{
    av_log_set_callback(fflog);//日志比较多，打开日志后会阻塞当前线程
    av_log_set_flags(AV_LOG_PANIC);
    
    ///初始化libavformat，注册所有文件格式，编解码库；这不是必须的，如果你能确定需要打开什么格式的文件，使用哪种编解码类型，也可以单独注册！
    av_register_all();
    
    if ([moviePath hasPrefix:@"http"]) {
        //Using network protocols without global network initialization. Please use avformat_network_init(), this will become mandatory later.
        //播放网络视频的时候，要首先初始化下网络模块。
        avformat_network_init();
    }
    
    AVFormatContext *formatCtx = NULL;
    
    /*
     打开输入流，读取文件头信息，不会打开解码器；
     */
    ///低版本是 av_open_input_file 方法
    if (0 != avformat_open_input(&formatCtx, [moviePath cStringUsingEncoding:NSUTF8StringEncoding], NULL, NULL)) {
        ///关闭，释放内存，置空
        avformat_close_input(&formatCtx);
    }
    
    /* 刚才只是打开了文件，检测了下文件头而已，并没有去找流信息；因此开始读包以获取流信息*/
    if (0 != avformat_find_stream_info(formatCtx, NULL)) {
        avformat_close_input(&formatCtx);
    }
    
    ///用于查看详细信息，调试的时候打出来看下很有必要
    av_dump_format(formatCtx, 0, [moviePath.lastPathComponent cStringUsingEncoding: NSUTF8StringEncoding], false);
    
    /* 接下来，尝试找到我们关系的信息*/
    
    NSMutableString *text = [[NSMutableString alloc]init];
    
    /*AVFormatContext 的 streams 变量是个数组，里面存放了 nb_streams 个元素，每个元素都是一个 AVStream */
    [text appendFormat:@"共%u个流，%llds",formatCtx->nb_streams,formatCtx->duration/AV_TIME_BASE];
    //遍历所有的流
    for (unsigned int i = 0; i < formatCtx->nb_streams; i++) {
        
        AVStream *stream = formatCtx->streams[i];
        
        switch (stream->codecpar->codec_type) {
                ///音频流
            case AVMEDIA_TYPE_AUDIO:
            {
                //取出来流信息结构体
                AVCodecParameters *codecpar = stream->codecpar;
                //采样率
                int sample_rate = codecpar->sample_rate;
                //声道数
                int channels = codecpar->channels;
                //比特率
                int64_t brate = codecpar->bit_rate;
                //时长
                // int64_t duration = stream->duration;
                //解码器id
                enum AVCodecID codecID = codecpar->codec_id;
                //根据解码器id找到对应名称
                const char *codecDesc = avcodec_get_name(codecID);
                //音频采样格式
                enum AVSampleFormat format = codecpar->format;
                //获取音频采样格式名称
                const char * formatDesc = av_get_sample_fmt_name(format);
                
                [text appendFormat:@"\n\nAudio\n%d Kbps，%.1f KHz， %d channels，%s，%s",(int)(brate/1000.0),sample_rate/1000.0,channels,codecDesc,formatDesc];
            }
                break;
                ///视频流
            case AVMEDIA_TYPE_VIDEO:
            {
                //保存视频strema index.
                _stream_index_video = i;
                
                avStreamFPSTimeBase(stream, 0.04, &_fps, &_videoTimeBase);
                /*
                 老的获取方式
                 AVCodecContext *codecCtx = stream->codec;
                 codecCtx->width
                 codecCtx->height
                 codecCtx->codec_type
                 */
                //取出来流信息结构体
                AVCodecParameters *codecpar = stream->codecpar;
                ///画面宽度，单位像素
                int vwidth = codecpar->width;
                ///画面高度，单位像素
                int vheight = codecpar->height;
                //比特率
                int64_t brate = codecpar->bit_rate;
                //解码器id
                _codecId_video = codecpar->codec_id;
                //根据解码器id找到对应名称
                const char *codecDesc = avcodec_get_name(_codecId_video);
                //视频像素格式
                enum AVPixelFormat format = codecpar->format;
                //获取视频像素格式名称
                const char * formatDesc = av_get_pix_fmt_name(format);
                ///帧率
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
                
                _pix_fmt = format;
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
    }
    
    _formatCtx = formatCtx;
    
    const AVCodec *pCodec = NULL;
    //根据编码id找到编码器
    pCodec = avcodec_find_decoder(_codecId_video);
    if (pCodec == NULL) {
        NSLog(@"不支持的编码格式！");
        return ;
    }
    
    const AVCodecParameters * codecpar = _formatCtx->streams[_stream_index_video]->codecpar;
    
    _codecCtx = avcodec_alloc_context3(pCodec);
    
    avcodec_parameters_to_context(_codecCtx, codecpar);
    
    //打开吧！
    if (F_OK != avcodec_open2(_codecCtx, pCodec, NULL)) {
        ///打开失败？释放下内存
        avcodec_free_context(&_codecCtx);
        NSLog(@"无法打开流！");
        return ;
    }
    
    int width = codecpar->width;
    int height = codecpar->height;
    
    _videoDimensions = CGSizeMake(width, height);
#if RENDER == OPENGL
    if (self.glView) {
        UIView *superView = self.glView.superview;
        CGSize vSize = superView.bounds.size;
        CGFloat vh = vSize.width * height / width;
        self.glView.frame = CGRectMake(0, (vSize.height-vh)/2, vSize.width , vh);
    }
#endif
    
    _weakSelf_SL
    self.readFramesTimer = [NSTimer mr_scheduledWithTimeInterval:0.01 repeats:YES block:^{
        _strongSelf_SL
        [self readFrame];
    }];
}

#pragma mark - read frame loop

- (void)readFrame
{
    if (!self.io_queue) {
        dispatch_queue_t io_queue = dispatch_queue_create("read-io", DISPATCH_QUEUE_SERIAL);
        self.io_queue = io_queue;
    }
    
    BOOL buffered = NO;
    
    @synchronized(self) {
        buffered = [self.videoFrames count] > 10;
    }
    
    if (buffered) {
        return;
    }
    
    _weakSelf_SL
    dispatch_async(self.io_queue, ^{
        
        AVPacket pkt;
        _strongSelf_SL
        if (av_read_frame(_formatCtx,&pkt) >= 0) {
            if (pkt.stream_index == _stream_index_video) {
                
                _weakSelf_SL
                [self handleVideoPacket:&pkt completion:^(AVFrame *video_frame) {
                    _strongSelf_SL
                    
                    const double frameDuration = av_frame_get_pkt_duration(video_frame) * _videoTimeBase;
                    MRVideoFrame *frame = [[MRVideoFrame alloc]init];
                    frame.duration = frameDuration;
                    frame.frame = video_frame;
                    
                    @synchronized(self) {
                        [self.videoFrames addObject:frame];
                    }
                }];
            }
        }else{
            NSLog(@"eof,stop read more frame!");
            if (self.readFramesTimer) {
                [self.readFramesTimer invalidate];
            }
        }
        ///释放内存
        av_packet_unref(&pkt);
    });
}

#pragma mark - decode video packet

- (void)handleVideoPacket:(AVPacket *)packet completion:(void(^)(AVFrame *video_frame))completion
{
    if (!completion) {
        return;
    }
#if use_v3
    int ret = avcodec_send_packet(_codecCtx, packet);
    if (ret != 0) {
        printf("avcodec_send_packet failed.\n");
    }
    AVFrame *video_frame = av_frame_alloc();//老版本是 avcodec_alloc_frame
    
    ret = avcodec_receive_frame(_codecCtx, video_frame);
    switch (ret) {
        case 0:
            while (ret==0) {
                completion(video_frame);
                ret = avcodec_receive_frame(_codecCtx, video_frame);
            }
            break;
        case AVERROR(EAGAIN):
            printf("Resource temporarily unavailable\n");
            break;
        case AVERROR_EOF:
            printf("End of file\n");
            break;
        default:
            printf("other error.. code: %d\n", AVERROR(ret));
            break;
    }
    av_frame_free(&video_frame);
    video_frame = NULL;
#else
    int gotframe = 0;
    AVFrame *video_frame = av_frame_alloc();//老版本是 avcodec_alloc_frame
    
    int len = avcodec_decode_video2(_codecCtx, video_frame, &gotframe, packet);
    if (len < 0) {
        NSLog(@"decode video error, skip packet");
    }
    if (gotframe) {
        completion(video_frame);
    }
    //用完后记得释放掉
    av_frame_unref(video_frame);
#endif
}

#pragma mark - display video frame

- (void)displayVideoFrame:(MRVideoFrame *)frame
{
    AVFrame *video_frame = frame.frame;
#if RENDER == OPENGL
    [self displayUseOpenGL:video_frame];
#elif RENDER == IMAGE
    [self displayUseImage:video_frame];
#elif RENDER == LAYER
    [self displayUseCVPixelBuffer:video_frame];
#endif
}

- (void)displayUseOpenGL:(AVFrame *)video_frame
{
    [self.glView displayYUV420pData:video_frame];
}

- (void)displayUseImage:(AVFrame *)video_frame
{
    if (video_frame->format == AV_PIX_FMT_YUV420P || video_frame->format == AV_PIX_FMT_YUVJ420P) {
        unsigned char *nv12 = NULL;
        int nv12Size = AVFrameConvertToNV12Buffer(video_frame,&nv12);
        //        int nv12Size = AVFrameConvertTo420pBuffer(video_frame, &nv12);
        if (nv12Size > 0){
            
            UIImage *image = [self NV12toUIImage:_codecCtx->width h:_codecCtx->height buffer:nv12];
            dispatch_sync(dispatch_get_main_queue(), ^{
                [self.render setImage:image];
            });
            
            free(nv12);
            nv12 = NULL;
        }
    }
}

- (void)displayUseCVPixelBuffer:(AVFrame *)video_frame
{
    if (video_frame->format == AV_PIX_FMT_YUV420P || video_frame->format == AV_PIX_FMT_YUVJ420P) {
        unsigned char *nv12 = NULL;
        int nv12Size = AVFrameConvertToNV12Buffer(video_frame,&nv12);
        if (nv12Size > 0){
            [self useCVPixelBufferRefRender:_codecCtx->width h:_codecCtx->height linesize:video_frame->linesize[0] buffer:nv12 size:nv12Size];
            free(nv12);
            nv12 = NULL;
        }
    }
}

- (void)useCVPixelBufferRefRender:(int)w h:(int)h linesize:(int)linesize buffer:(unsigned char *)buffer size:(int)nv12Size
{
    CVReturn theError;
    if (!self.pixelBufferPool){
        NSMutableDictionary* attributes = [NSMutableDictionary dictionary];
        [attributes setObject:[NSNumber numberWithInt:kCVPixelFormatType_420YpCbCr8BiPlanarFullRange] forKey:(NSString*)kCVPixelBufferPixelFormatTypeKey];
        [attributes setObject:[NSNumber numberWithInt:w] forKey: (NSString*)kCVPixelBufferWidthKey];
        [attributes setObject:[NSNumber numberWithInt:h] forKey: (NSString*)kCVPixelBufferHeightKey];
        [attributes setObject:@(linesize) forKey:(NSString*)kCVPixelBufferBytesPerRowAlignmentKey];
        [attributes setObject:[NSDictionary dictionary] forKey:(NSString*)kCVPixelBufferIOSurfacePropertiesKey];
        
        theError = CVPixelBufferPoolCreate(kCFAllocatorDefault, NULL, (__bridge CFDictionaryRef) attributes, &_pixelBufferPool);
        if (theError != kCVReturnSuccess){
            NSLog(@"CVPixelBufferPoolCreate Failed");
        }
    }
    
    CVPixelBufferRef pixelBuffer = nil;
    theError = CVPixelBufferPoolCreatePixelBuffer(NULL, self.pixelBufferPool, &pixelBuffer);
    if(theError != kCVReturnSuccess){
        NSLog(@"CVPixelBufferPoolCreatePixelBuffer Failed");
    }
    
    CVPixelBufferLockBaseAddress(pixelBuffer, 0);
    void* base = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    memcpy(base, buffer, nv12Size);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    //不设置具体时间信息
    CMSampleTimingInfo timing = {kCMTimeInvalid, kCMTimeInvalid, kCMTimeInvalid};
    //获取视频信息
    CMVideoFormatDescriptionRef videoInfo = NULL;
    OSStatus result = CMVideoFormatDescriptionCreateForImageBuffer(NULL, pixelBuffer, &videoInfo);
    NSParameterAssert(result == 0 && videoInfo != NULL);
    
    CMSampleBufferRef sampleBuffer = NULL;
    result = CMSampleBufferCreateForImageBuffer(kCFAllocatorDefault,pixelBuffer, true, NULL, NULL, videoInfo, &timing, &sampleBuffer);
    NSParameterAssert(result == 0 && sampleBuffer != NULL);
    CFRelease(pixelBuffer);
    CFRelease(videoInfo);
    
    CFArrayRef attachments = CMSampleBufferGetSampleAttachmentsArray(sampleBuffer, YES);
    CFMutableDictionaryRef dict = (CFMutableDictionaryRef)CFArrayGetValueAtIndex(attachments, 0);
    CFDictionarySetValue(dict, kCMSampleAttachmentKey_DisplayImmediately, kCFBooleanTrue);
    
    dispatch_async(dispatch_get_main_queue(), ^{
        [self.sampleBufferDisplayLayer enqueueSampleBuffer:sampleBuffer];
        CFRelease(sampleBuffer);
    });
}

#pragma mark - avframe to nv12

int AVFrameConvertToNV12Buffer(AVFrame *pFrame,unsigned char **nv12)
{
    if ((pFrame->format == AV_PIX_FMT_YUV420P) || (pFrame->format == AV_PIX_FMT_NV12) || (pFrame->format == AV_PIX_FMT_NV21) || (pFrame->format == AV_PIX_FMT_YUVJ420P)){
        
        int height = pFrame->height;
        int width = pFrame->width;
        //计算需要分配的内存大小
        int needSize = height * width * 1.5;
        
        if (*nv12 == NULL) {
            //申请内存
            *nv12 = malloc(needSize);
        }
        unsigned char *buf = *nv12;
        unsigned char *y = pFrame->data[0];
        unsigned char *u = pFrame->data[1];
        unsigned char *v = pFrame->data[2];
        
        unsigned int ys = pFrame->linesize[0];
        
        //先写入Y（height * width 个 Y 数据）
        int offset=0;
        for (int i=0; i < height; i++)
        {
            memcpy(buf+offset,y + i * ys, width);
            offset+=width;
        }
        
        ///一个U一个V交替着排列（一共有 width * height / 4 个 [U + V] ）
        for (int i = 0; i < width * height / 4; i++)
        {
            memcpy(buf+offset,u + i, 1);
            offset++;
            memcpy(buf+offset,v + i, 1);
            offset++;
        }
        return needSize;
    }
    
    return -1;
}

#pragma mark - avframe to 420p

//yyyy yyyy
//uu
//vv
//https://www.cnblogs.com/lidabo/p/3326502.html
int AVFrameConvertTo420pBuffer(AVFrame *pFrame,unsigned char **yuv420p)
{
    if ((pFrame->format == AV_PIX_FMT_YUV420P) || (pFrame->format == AV_PIX_FMT_NV12) || (pFrame->format == AV_PIX_FMT_NV21) || (pFrame->format == AV_PIX_FMT_YUVJ420P)){
        
        int height = pFrame->height;
        int width = pFrame->width;
        //计算需要分配的内存大小
        int needSize = height * width * 1.5;
        
        if (*yuv420p == NULL) {
            //申请内存
            *yuv420p = malloc(needSize);
        }
        unsigned char *buf = *yuv420p;
        
        unsigned char *y = pFrame->data[0];
        unsigned char *u = pFrame->data[1];
        unsigned char *v = pFrame->data[2];
        
        unsigned int ys = pFrame->linesize[0];
        unsigned int us = pFrame->linesize[1];
        unsigned int vs = pFrame->linesize[2];
        
        //先写入Y（height * width 个 Y 数据）
        int offset=0;
        for (int i=0; i < height; i++)
        {
            memcpy(buf+offset,y + i * ys, width);
            offset+=width;
        }
        
        int uOffset = offset;
        int vOffset = offset + height/2 * width/2;
        
        int width_2 = width/2;
        
        ///按行写 U 和 V，写次写半行，V 从 5/4 处开始写
        for (int i = 0; i < height/2; i++)
        {
            ///由于对齐原因，有可能 us 比 width/2大，大的话就丢弃不要了
            memcpy(buf + uOffset,u + i * us, width_2);
            uOffset += width_2;
            
            memcpy(buf + vOffset,v + i * vs, width_2);
            vOffset += width_2;
        }
        
        return needSize;
    }
    
    return -1;
}


#pragma mark - yuv420p to yuv420sp

//http://blog.csdn.net/subfate/article/details/47305391

/**
 yyyy yyyy
 uu
 vv
 ->
 yyyy yyyy
 uv    uv
 */
void yuv420p_to_yuv420sp(unsigned char* yuv420p, unsigned char* yuv420sp, int width, int height)
{
    int i, j;
    int y_size = width * height;
    
    unsigned char* y = yuv420p;
    unsigned char* u = yuv420p + y_size;
    unsigned char* v = yuv420p + y_size * 5 / 4;
    
    unsigned char* y_tmp = yuv420sp;
    unsigned char* uv_tmp = yuv420sp + y_size;
    
    // y
    memcpy(y_tmp, y, y_size);
    
    // u
    for (j = 0, i = 0; j < y_size/2; j+=2, i++)
    {
        // 此处可调整U、V的位置，变成NV12或NV21
#if 01
        uv_tmp[j] = u[i];
        uv_tmp[j+1] = v[i];
#else
        uv_tmp[j] = v[i];
        uv_tmp[j+1] = u[i];
#endif
    }
}

#pragma mark - YUV(NV12)-->CIImage--->UIImage
//https://stackoverflow.com/questions/25659671/how-to-convert-from-yuv-to-ciimage-for-ios
-(UIImage *)NV12toUIImage:(int)w h:(int)h buffer:(unsigned char *)buffer
{
    //YUV(NV12)-->CIImage--->UIImage Conversion
    NSDictionary *pixelAttributes = @{(NSString*)kCVPixelBufferIOSurfacePropertiesKey:@{}};
    
    CVPixelBufferRef pixelBuffer = NULL;
    
    CVReturn result = CVPixelBufferCreate(kCFAllocatorDefault,
                                          w,
                                          h,
                                          kCVPixelFormatType_420YpCbCr8BiPlanarFullRange,
                                          (__bridge CFDictionaryRef)(pixelAttributes),
                                          &pixelBuffer);
    
    CVPixelBufferLockBaseAddress(pixelBuffer,0);
    unsigned char *yDestPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 0);
    
    // Here y_ch0 is Y-Plane of YUV(NV12) data.
    unsigned char *y_ch0 = buffer;
    unsigned char *y_ch1 = buffer + w * h;
    memcpy(yDestPlane, y_ch0, w * h);
    unsigned char *uvDestPlane = CVPixelBufferGetBaseAddressOfPlane(pixelBuffer, 1);
    
    // Here y_ch1 is UV-Plane of YUV(NV12) data.
    memcpy(uvDestPlane, y_ch1, w * h/2);
    CVPixelBufferUnlockBaseAddress(pixelBuffer, 0);
    
    if (result != kCVReturnSuccess) {
        NSLog(@"Unable to create cvpixelbuffer %d", result);
    }
    
    // CIImage Conversion
    CIImage *coreImage = [CIImage imageWithCVPixelBuffer:pixelBuffer];
    
    CIContext *context = [CIContext contextWithOptions:nil];
    
    
    ///引发内存泄露? https://stackoverflow.com/questions/32520082/why-is-cicontext-createcgimage-causing-a-memory-leak
    CGImageRef cgImage = [context createCGImage:coreImage
                                       fromRect:CGRectMake(0, 0, w, h)];
    
    // UIImage Conversion
    UIImage *uiImage = [[UIImage alloc] initWithCGImage:cgImage
                                                  scale:1.0
                                            orientation:UIImageOrientationUp];
    
    CVPixelBufferRelease(pixelBuffer);
    CGImageRelease(cgImage);
    
    return uiImage;
}

#pragma mark - test

- (void)readFrame2
{
    if (!self.io_queue) {
        dispatch_queue_t io_queue = dispatch_queue_create("read-io", DISPATCH_QUEUE_SERIAL);
        self.io_queue = io_queue;
    }
    
    dispatch_async(self.io_queue, ^{
        
        AVFrame *pFrame = av_frame_alloc();//老版本是 avcodec_alloc_frame
        if(pFrame == NULL){
            return;
        }
        
        AVFrame *pFrameRGB = av_frame_alloc();
        
        uint8_t *buffer;
        
        int numBytes;
        
        // Determine required buffer size and allocate buffer
        numBytes= av_image_get_buffer_size(AV_PIX_FMT_YUV420P, _codecCtx->width, _codecCtx->height, 1);
        //        numBytes= avpicture_get_size(AV_PIX_FMT_RGB24, _codecCtx->width,_codecCtx->height);
        
        buffer=(uint8_t *)av_malloc(numBytes*sizeof(uint8_t));
        
        AVPacket packet;
        int i = 0;
        
        if (av_read_frame(_formatCtx,&packet) >= 0) {
            if (packet.stream_index == _stream_index_video) {
                //                int succ = avcodec_send_packet(_codecCtx, &packet);
                int gotframe = 0;
                
                //                while (succ >= 0) {
                //                    succ = avcodec_receive_frame(_codecCtx, pFrame);
                //                    if (succ == AVERROR(EAGAIN) || succ == AVERROR_EOF) {
                //                        break;
                //                    }
                //                }
                
                int len = avcodec_decode_video2(_codecCtx, pFrame, &gotframe, &packet);
                if (len < 0) {
                    NSLog(@"decode video error, skip packet");
                    [self readFrame];
                }
                if (gotframe) {
                    
                    avpicture_fill((AVPicture *)pFrameRGB,buffer, AV_PIX_FMT_RGB24, _codecCtx->width, _codecCtx->height);
                    
                    SaveFrame(pFrameRGB, _codecCtx->width,_codecCtx->height, i);
                    i++;
                    
                    av_packet_unref(&packet);
                }else{
                    //                    av_free_packet(&packet);
                    [self readFrame];
                }
                
            }
        }else{
            av_frame_free(&pFrame);
            NSLog(@"eof");
        }
    });
}

void SaveFrame(AVFrame *pFrame, int width, int height, int iFrame) {
    
    FILE *pFile;
    int y;
    
    // Open file
    NSString *fileName = [NSString stringWithFormat:@"frame%d.ppm",iFrame];
    NSString *path = [NSHomeDirectory() stringByAppendingPathComponent:fileName];
    
    //    sprintf(szFilename, [path UTF8String], iFrame);
    
    pFile=fopen([path UTF8String], "wb");
    
    if(pFile==NULL)
        
        return;
    
    // Write header
    
    fprintf(pFile, "P6\n%d %d\n255\n", width, height);
    
    // Write pixel data
    
    for(y=0; y<height; y++)
        
        fwrite(pFrame->data[0]+y*pFrame->linesize[0], 1, width*3, pFile);
    
    // Close file
    
    fclose(pFile);
    
}

@end
