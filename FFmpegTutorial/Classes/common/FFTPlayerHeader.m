//
//  FFTPlayerHeader.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/7/27.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//


#import "FFTPlayerHeader.h"
#import <libavutil/frame.h>
#import <libavutil/imgutils.h>

const char * av_pixel_fmt_to_string(int fmt)
{
    enum AVPixelFormat avpf = fmt;
    switch (avpf) {
        case AV_PIX_FMT_YUV420P:
            return "YUV420P";
        case AV_PIX_FMT_NV12:
            return "NV12";
        case AV_PIX_FMT_NV21:
            return "NV21";
        case AV_PIX_FMT_NV16:
            return "NV16";
        case AV_PIX_FMT_UYVY422:
            return "UYVY422";
        case AV_PIX_FMT_YUV444P10:
            return "YUV444P10";
        case AV_PIX_FMT_YUYV422:
            return "YUYV422";
        case AV_PIX_FMT_RGB24:
            return "RGB24";
        case AV_PIX_FMT_RGBA:
            return "RGBA";
        case AV_PIX_FMT_ARGB:
            return "ARGB";
        case AV_PIX_FMT_0RGB:
            return "0RGB";
        case AV_PIX_FMT_RGB0:
            return "RGB0";
        case AV_PIX_FMT_RGB555:
            return "RGB555";
        case AV_PIX_FMT_BGR0:
            return "BGR0";
        case AV_PIX_FMT_BGRA:
            return "BGRA";
        case AV_PIX_FMT_ABGR:
            return "ABGR";
        case AV_PIX_FMT_0BGR:
            return "0BGR";
        case AV_PIX_FMT_BGR24:
            return "BGR24";
        default:
        {
            return "unknow";
        }
            break;
    }
}

const char * av_sample_fmt_to_string(int format)
{
    if (AV_SAMPLE_FMT_S16 == format) {
        return "s16";
    } else if (AV_SAMPLE_FMT_S16P == format) {
        return "s16p";
    } else if (AV_SAMPLE_FMT_FLT == format) {
        return "float";
    } else if (AV_SAMPLE_FMT_FLTP == format) {
        return "floatp";
    } else {
        return "unknow";
    }
}

enum AVSampleFormat MRSampleFormat2AV (MRSampleFormat mrsf){
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

MRSampleFormat AVSampleFormat2MR (enum AVSampleFormat avsf){
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

MRPixelFormat AVPixelFormat2MR (enum AVPixelFormat avpf){
    switch (avpf) {
        case AV_PIX_FMT_YUV420P:
            return MR_PIX_FMT_YUV420P;
        case AV_PIX_FMT_NV12:
            return MR_PIX_FMT_NV12;
        case AV_PIX_FMT_NV21:
            return MR_PIX_FMT_NV21;
        case AV_PIX_FMT_NV16:
            return MR_PIX_FMT_NV16;
        case AV_PIX_FMT_UYVY422:
            return MR_PIX_FMT_UYVY422;
        case AV_PIX_FMT_YUV444P10:
            return MR_PIX_FMT_YUV444P10;
        case AV_PIX_FMT_YUYV422:
            return MR_PIX_FMT_YUYV422;
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

enum AVPixelFormat MRPixelFormat2AV (MRPixelFormat mrpf){
    switch (mrpf) {
        case MR_PIX_FMT_YUV420P:
            return AV_PIX_FMT_YUV420P;
        case MR_PIX_FMT_NV12:
            return AV_PIX_FMT_NV12;
        case MR_PIX_FMT_NV21:
            return AV_PIX_FMT_NV21;
        case MR_PIX_FMT_NV16:
            return AV_PIX_FMT_NV16;
        case MR_PIX_FMT_UYVY422:
            return AV_PIX_FMT_UYVY422;
        case MR_PIX_FMT_YUV444P10:
            return AV_PIX_FMT_YUV444P10;
        case MR_PIX_FMT_YUYV422:
            return AV_PIX_FMT_YUYV422;
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

int audio_buffer_size(AVFrame *frame)
{
    const int fmt = frame->format;
    int chanels = av_sample_fmt_is_planar(fmt) ? 1 : 2;
    //self.frame->linesize[i] 比 data_size 要大，所以有杂音
    int data_size = av_samples_get_buffer_size(frame->linesize, chanels, frame->nb_samples, fmt, 1);
    return data_size;
}
