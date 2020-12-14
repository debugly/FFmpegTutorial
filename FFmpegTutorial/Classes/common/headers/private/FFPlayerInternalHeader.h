//
//  FFPlayerInternalHeader.h
//  FFmpegTutorial
//
//  Created by Matt Reach on 2020/5/14.
//

#ifndef FFPlayerInternalHeader_h
#define FFPlayerInternalHeader_h

#include <libavformat/avformat.h>
#include <libavutil/pixdesc.h>

/* no AV sync correction is done if below the minimum AV sync threshold */
#define AV_SYNC_THRESHOLD_MIN 0.04
/* AV sync correction is done if above the maximum AV sync threshold */
#define AV_SYNC_THRESHOLD_MAX 0.1
/* If a frame duration is longer than this, it will not be duplicated to compensate AV sync */
#define AV_SYNC_FRAMEDUP_THRESHOLD 0.1
/* no AV correction is done if too big error */
#define AV_NOSYNC_THRESHOLD 10.0
/* polls for possible required screen refresh at least this often, should be less than 1/fps */
#define REFRESH_RATE 0.01


av_unused static MRPixelFormat AVPixelFormat2MR (enum AVPixelFormat avpf){
    switch (avpf) {
        case AV_PIX_FMT_YUV420P:
            return MR_PIX_FMT_YUV420P;
        case AV_PIX_FMT_NV12:
            return MR_PIX_FMT_NV12;
        case AV_PIX_FMT_NV21:
            return MR_PIX_FMT_NV21;
        case AV_PIX_FMT_RGB24:
            return MR_PIX_FMT_RGB24;
        case AV_PIX_FMT_RGBA:
            return MR_PIX_FMT_RGBA;
        case AV_PIX_FMT_ARGB:
            return MR_PIX_FMT_ARGB;
        case AV_PIX_FMT_0RGB:
            return MR_PIX_FMT_0RGB;
        case AV_PIX_FMT_RGB0:
            return MR_PIX_FMT_RGB0;
        case AV_PIX_FMT_RGB555LE:
            return MR_PIX_FMT_RGB555LE;
        case AV_PIX_FMT_RGB555BE:
            return MR_PIX_FMT_RGB555BE;
        case AV_PIX_FMT_BGR0:
            return MR_PIX_FMT_BGR0;
        case AV_PIX_FMT_BGRA:
            return MR_PIX_FMT_BGRA;
        case AV_PIX_FMT_ABGR:
            return MR_PIX_FMT_ABGR;
        case AV_PIX_FMT_0BGR:
            return MR_PIX_FMT_0BGR;
        case AV_PIX_FMT_BGR24:
            return MR_PIX_FMT_BGR24;
        default:
        {
            assert(0);
            return MR_PIX_FMT_NONE;
        }
            break;
    }
}

av_unused static enum AVPixelFormat MRPixelFormat2AV (MRPixelFormat mrpf){
    switch (mrpf) {
        case MR_PIX_FMT_YUV420P:
            return AV_PIX_FMT_YUV420P;
        case MR_PIX_FMT_NV12:
            return AV_PIX_FMT_NV12;
        case MR_PIX_FMT_NV21:
            return AV_PIX_FMT_NV21;
        case MR_PIX_FMT_RGB24:
            return AV_PIX_FMT_RGB24;
        case MR_PIX_FMT_0RGB:
            return AV_PIX_FMT_0RGB;
        case MR_PIX_FMT_RGB0:
            return AV_PIX_FMT_RGB0;
        case MR_PIX_FMT_RGBA:
            return AV_PIX_FMT_RGBA;
        case MR_PIX_FMT_ARGB:
            return AV_PIX_FMT_ARGB;
        case MR_PIX_FMT_RGB555LE:
            return AV_PIX_FMT_RGB555LE;
        case MR_PIX_FMT_RGB555BE:
            return AV_PIX_FMT_RGB555BE;
        case MR_PIX_FMT_BGR0:
            return AV_PIX_FMT_BGR0;
        case MR_PIX_FMT_BGRA:
            return AV_PIX_FMT_BGRA;
        case MR_PIX_FMT_ABGR:
            return AV_PIX_FMT_ABGR;
        case MR_PIX_FMT_0BGR:
            return AV_PIX_FMT_0BGR;
        case MR_PIX_FMT_BGR24:
            return AV_PIX_FMT_BGR24;
        case MR_PIX_FMT_NONE:
            return AV_PIX_FMT_NONE;
        case MR_PIX_FMT_EOF:
            return AV_PIX_FMT_NONE;
    }
}

av_unused static MRColorRange AVColorRange2MR (enum AVColorRange avcr){
    switch (avcr) {
        case AVCOL_RANGE_UNSPECIFIED:
            return MRCOL_RANGE_UNSPECIFIED;
        case AVCOL_RANGE_JPEG:
            return MRCOL_RANGE_JPEG;
        case AVCOL_RANGE_MPEG:
            return MRCOL_RANGE_MPEG;
        case AVCOL_RANGE_NB:
            return MRCOL_RANGE_NB;
        default:
        {
            assert(0);
            return MRCOL_RANGE_UNSPECIFIED;
        }
            break;
    }
}


av_unused static enum AVSampleFormat MRSampleFormat2AV (MRSampleFormat mrsf){
    switch (mrsf) {
        case MR_SAMPLE_FMT_S16:
            return AV_SAMPLE_FMT_S16;
        case MR_SAMPLE_FMT_FLT:
            return AV_SAMPLE_FMT_FLT;
        case MR_SAMPLE_FMT_S16P:
            return AV_SAMPLE_FMT_S16P;
        case MR_SAMPLE_FMT_FLTP:
            return AV_SAMPLE_FMT_FLTP;
        case MR_SAMPLE_FMT_EOF:
        case MR_SAMPLE_FMT_NONE:
        {
            return AV_SAMPLE_FMT_NONE;
        }
    }
}

av_unused static MRSampleFormat AVSampleFormat2MR (enum AVSampleFormat avsf){
    switch (avsf) {
        case AV_SAMPLE_FMT_S16:
            return MR_SAMPLE_FMT_S16;
        case AV_SAMPLE_FMT_FLT:
            return MR_SAMPLE_FMT_FLT;
        case AV_SAMPLE_FMT_S16P:
            return MR_SAMPLE_FMT_S16P;
        case AV_SAMPLE_FMT_FLTP:
            return MR_SAMPLE_FMT_FLTP;
        case AV_SAMPLE_FMT_NONE:
            return MR_SAMPLE_FMT_NONE;
        default:
            assert(0);
            return MR_SAMPLE_FMT_NONE;
    }
}

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
        //初始化网络模块
        avformat_network_init();
        flag = 1;
    }
}

static __inline__ void init_ffmpeg_once()
{
    static int flag = 0;
    if (flag == 0) {
        //只对av_log_default_callback有效
#if DEBUG
        av_log_set_level(AV_LOG_DEBUG);
#else
        av_log_set_level(AV_LOG_WARNING);
#endif
        //初始化 libavformat，注册所有的复用器，解复用器，协议协议！
        av_register_all();
        flag = 1;
    }
}

#endif /* FFPlayerInternalHeader_h */
