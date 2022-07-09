//
//  FFPlayerHeader.c
//  FFmpegTutorial
//
//  Created by qianlongxu on 2022/7/9.
//

#include "FFPlayerHeader.h"
#import <libavutil/frame.h>
#import <libavutil/imgutils.h>

char * av_pixel_fmt_to_string(int fmt)
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
