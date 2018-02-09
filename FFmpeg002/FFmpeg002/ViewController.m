//
//  ViewController.m
//  FFmpeg002
//
//  Created by Matt Reach on 2017/9/18.
//  Copyright © 2017年 Awesome FFmpeg Study Demo. All rights reserved.
//  开源地址: https://github.com/debugly/StudyFFmpeg
//

#import "ViewController.h"
#import <libavutil/log.h>
#import <libavformat/avformat.h>
#import <libavcodec/avcodec.h>
#import <libavutil/pixdesc.h>
#import <libavutil/samplefmt.h>

@interface ViewController ()

@property (weak, nonatomic) IBOutlet UITextView *tv;
@property (weak, nonatomic) UIActivityIndicatorView *indicatorView;

@end

@implementation ViewController

static void fflog(void *context, int level, const char *format, va_list args){
    @autoreleasepool {
        NSString* message = [[NSString alloc] initWithFormat: [NSString stringWithUTF8String: format] arguments: args];
        
        NSLog(@"ff:%d%@",level,message);
    }
}

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    UIActivityIndicatorView *indicatorView = [[UIActivityIndicatorView alloc]initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
    [self.view addSubview:indicatorView];
    indicatorView.center = self.view.center;
    indicatorView.hidesWhenStopped = YES;
    [indicatorView sizeToFit];
    _indicatorView = indicatorView;
    
    [indicatorView startAnimating];
    
    //av_log_set_callback(fflog);//日志比较多，打开日志后会阻塞当前线程
    //av_log_set_flags(AV_LOG_SKIP_REPEATED);
    
    ///初始化libavformat，注册所有文件格式，编解码库；这不是必须的，如果你能确定需要打开什么格式的文件，使用哪种编解码类型，也可以单独注册！
    av_register_all();
    
    NSString *moviePath = nil;//[[NSBundle mainBundle]pathForResource:@"test" ofType:@"mp4"];
    ///该地址可以是网络的也可以是本地的；
    moviePath = @"http://debugly.github.io/repository/test.mp4";
    
    if ([moviePath hasPrefix:@"http"]) {
        //Using network protocols without global network initialization. Please use avformat_network_init(), this will become mandatory later.
        //播放网络视频的时候，要首先初始化下网络模块。
        avformat_network_init();
    }
    
    dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
        [self openStreamWithPath:moviePath completion:^(NSString *text){
            dispatch_async(dispatch_get_main_queue(), ^{
                
                self.tv.text = text;
                [_indicatorView stopAnimating];
                [_indicatorView removeFromSuperview];
            });
        }];
    });
}

/**
 avformat_open_input 是个耗时操作因此放在异步线程里完成

 @param moviePath 视频地址
 @param completion open之后获取信息，然后回调
 */
- (void)openStreamWithPath:(NSString *)moviePath completion:(void(^)(NSString *text))completion
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
            completion(@"不能打开流！");
        }
    }else{
     
        /* 刚才只是打开了文件，检测了下文件头而已，并没有去找流信息；因此开始读包以获取流信息*/
        if (0 != avformat_find_stream_info(formatCtx, NULL)) {
            avformat_close_input(&formatCtx);
            if (completion) {
                completion(@"不能找到流！");
            }
        }else{
         
            ///用于查看详细信息，调试的时候打出来看下很有必要
            av_dump_format(formatCtx, 0, [moviePath.lastPathComponent cStringUsingEncoding: NSUTF8StringEncoding], false);
            
            /* 接下来，尝试找到我们关心的信息*/
            
            NSMutableString *text = [[NSMutableString alloc]init];
            
            /*AVFormatContext 的 streams 变量是个数组，里面存放了 nb_streams 个元素，每个元素都是一个 AVStream */
            [text appendFormat:@"共%u个流，%llds",formatCtx->nb_streams,formatCtx->duration/AV_TIME_BASE];
            //遍历所有的流
            for (NSInteger i = 0; i < formatCtx->nb_streams; i++) {
                
                AVStream *stream = formatCtx->streams[i];
                AVCodecContext *codec = stream->codec;
                enum AVMediaType codec_type = codec->codec_type;
                switch (codec_type) {
                        ///音频流
                    case AVMEDIA_TYPE_AUDIO:
                    {
                        //采样率
                        int sample_rate = codec->sample_rate;
                        //声道数
                        int channels = codec->channels;
                        //平均比特率
                        int64_t brate = codec->bit_rate;
                        //时长
                        int64_t duration = stream->duration;
                        //解码器id
                        enum AVCodecID codecID = codec->codec_id;
                        //根据解码器id找到对应名称
                        const char *codecDesc = avcodec_get_name(codecID);
                        //音频采样格式
                        enum AVSampleFormat format = codec->sample_fmt;
                        //获取音频采样格式名称
                        const char * formatDesc = av_get_sample_fmt_name(format);
                        
                        [text appendFormat:@"\n\nAudio\n%d Kbps，%.1f KHz， %d channels，%s，%s，duration:%lld",(int)(brate/1000.0),sample_rate/1000.0,channels,codecDesc,formatDesc,duration];
                    }
                        break;
                        ///视频流
                    case AVMEDIA_TYPE_VIDEO:
                    {
                        ///画面宽度，单位像素
                        int vwidth = codec->width;
                        ///画面高度，单位像素
                        int vheight = codec->height;
                        //比特率
                        int64_t brate = codec->bit_rate;
                        //解码器id
                        enum AVCodecID codecID = codec->codec_id;
                        //根据解码器id找到对应名称
                        const char *codecDesc = avcodec_get_name(codecID);
                        //视频像素格式
                        enum AVPixelFormat format = codec->pix_fmt;
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
                        
                        [text appendFormat:@"\n\nVideo:\n%dKbps，%d*%d，at %.3fps， %s， %s",(int)(brate/1024.0),vwidth,vheight,fps,codecDesc,formatDesc];
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
            
            avformat_close_input(&formatCtx);
            
            if (completion) {
                completion([text copy]);
            }
        }
    }
}

- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
