//
//  FFPlayerInternalHeader.h
//  FFmpegTutorial
//
//  Created by Matt Reach on 2020/5/14.
//

#ifndef FFPlayerInternalHeader_h
#define FFPlayerInternalHeader_h

#import <libavformat/avformat.h>

static __inline__ NSError * _make_nserror(int code)
{
    return [NSError errorWithDomain:@"com.debugly.fftutorial" code:(NSInteger)code userInfo:nil];
}

static __inline__ NSError * _make_nserror_desc(int code,NSString *desc)
{
    if (!desc || desc.length == 0) {
        desc = @"";
    }
    
    return [NSError errorWithDomain:@"com.debugly.fftutorial" code:(NSInteger)code userInfo:@{
        NSLocalizedDescriptionKey:desc
    }];
}

static __inline__ void _init_net_work_once()
{
    static int flag = 0;
    if (flag == 0) {
        ///初始化网络模块
        avformat_network_init();
        flag = 1;
    }
}

static __inline__ void init_ffmpeg_once()
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

#endif /* FFPlayerInternalHeader_h */
