//
//  ViewController.m
//  FFmpeg002
//
//  Created by 许乾隆 on 2017/9/18.
//  Copyright © 2017年 许乾隆. All rights reserved.
//

#import "ViewController.h"
#import <libavutil/log.h>
#import <libavformat/avformat.h>
#import <libavcodec/avcodec.h>
#import <libavutil/pixdesc.h>
#import <libavutil/samplefmt.h>

@interface ViewController ()

@property (nonatomic, assign) AVFormatContext *formatCtx;
@property (weak, nonatomic) IBOutlet UITextView *tv;

@end

@implementation ViewController

static void fflog(void *context, int level, const char *format, va_list args){
    @autoreleasepool {
        NSString* message = [[NSString alloc] initWithFormat: [NSString stringWithUTF8String: format] arguments: args];
        
        NSLog(@"ff:%d%@",level,message);
    }
}

- (void)viewDidLoad {
    [super viewDidLoad];
    // Do any additional setup after loading the view, typically from a nib.
    
//    av_log_set_callback(fflog);//日志比较多，打开日志后会阻塞当前线程
    av_log_set_flags(AV_LOG_SKIP_REPEATED);
    av_register_all();
    
    NSString *moviePath = [[NSBundle mainBundle]pathForResource:@"test" ofType:@"mp4"];
    ///该地址可以是网络的也可以是本地的；
    moviePath = @"http://debugly.github.io/repository/test.mp4";
    
    if ([moviePath hasPrefix:@"http"]) {
        //Using network protocols without global network initialization. Please use avformat_network_init(), this will become mandatory later.
        avformat_network_init();
    }
    
    AVFormatContext *formatCtx = NULL;
    if (0 != avformat_open_input(&formatCtx, [moviePath cStringUsingEncoding:NSUTF8StringEncoding], NULL, NULL)) {
        if (formatCtx)
            avformat_free_context(formatCtx);
    }
    
    if (0 != avformat_find_stream_info(formatCtx, NULL)) {
        avformat_close_input(&formatCtx);
    }
    
//    av_dump_format(formatCtx, 0, [moviePath.lastPathComponent cStringUsingEncoding: NSUTF8StringEncoding], false);
    
    NSMutableString *text = [[NSMutableString alloc]init];
    
    [text appendFormat:@"共%u个流，%llds",formatCtx->nb_streams,formatCtx->duration/AV_TIME_BASE];
    
    for (NSInteger i = 0; i < formatCtx->nb_streams; i++) {
        
        AVStream *stream = formatCtx->streams[i];
/*
 AVCodecContext *codecCtx = stream->codec;
 codecCtx->width
 codecCtx->height
 codecCtx->codec_type
 */
        switch (stream->codecpar->codec_type) {
            case AVMEDIA_TYPE_AUDIO:
            {
                NSLog(@"音频流:%ld",i);
                int sample_rate = stream->codecpar->sample_rate;
                int channels = stream->codecpar->channels;
                int64_t brate = stream->codecpar->bit_rate;
//                int64_t duration = stream->duration;
                
                enum AVCodecID codecID = stream->codecpar->codec_id;
                const char *codecDesc = avcodec_get_name(codecID);
                
                enum AVSampleFormat format = stream->codecpar->format;
                const char * formatDesc = av_get_sample_fmt_name(format);
                
                [text appendFormat:@"\n\nAudio\n%d Kbps，%.1f KHz， %d channels，%s，%s",(int)(brate/1000.0),sample_rate/1000.0,channels,codecDesc,formatDesc];
            }
                break;
            case AVMEDIA_TYPE_VIDEO:
            {
                NSLog(@"视频流:%ld",i);
                int vwidth = stream->codecpar->width;
                int vheight = stream->codecpar->height;
                enum AVCodecID codecID = stream->codecpar->codec_id;
                const char *codecDesc = avcodec_get_name(codecID);
                
                CGFloat fps, timebase = 0.04;
                enum AVPixelFormat format = stream->codecpar->format;
                const char * formatDesc = av_get_pix_fmt_name(format);
                
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
                
                int64_t brate = stream->codecpar->bit_rate;
                
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
    
    _formatCtx = formatCtx;
    
    self.tv.text = [text copy];;
}


- (void)didReceiveMemoryWarning {
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}


@end
