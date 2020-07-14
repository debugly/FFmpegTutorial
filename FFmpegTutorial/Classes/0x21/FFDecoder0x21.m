//
//  FFDecoder0x21.m
//  FFmpegTutorial
//
//  Created by Matt Reach on 2020/7/14.
//

#import "FFDecoder0x21.h"
#import "MRThread.h"
#include <libavcodec/avcodec.h>
#import <libavformat/avformat.h>

@interface FFDecoder0x21()

///解码线程
@property (nonatomic, strong) MRThread * workThread;
@property (nonatomic, assign, readwrite) AVStream * stream;
@property (nonatomic, assign) AVCodecContext * avctx;
@property (nonatomic, assign) int abort_request;
///for video
@property (nonatomic, assign, readwrite) int format;
@property (nonatomic, assign, readwrite) int picWidth;
@property (nonatomic, assign, readwrite) int picHeight;
///for audio
@property (nonatomic, assign, readwrite) int sampleRate;
@property (nonatomic, assign, readwrite) int channelLayout;

@end

@implementation FFDecoder0x21

- (void)dealloc
{
    //释放解码器上下文
    if (_avctx) {
        avcodec_free_context(&_avctx);
        _avctx = NULL;
    }
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _streamIdx = -1;
    }
    return self;
}

- (int)open
{
    if (self.ic == NULL) {
        return -1;
    }
    
    if (self.streamIdx < 0 || self.streamIdx >= self.ic->nb_streams){
        return -1;
    }
    
    AVStream *stream = self.ic->streams[self.streamIdx];
    
    //创建解码器上下文
    AVCodecContext *avctx = avcodec_alloc_context3(NULL);
    if (!avctx) {
        return AVERROR(ENOMEM);
    }
    
    //填充下相关参数
    if (avcodec_parameters_to_context(avctx, stream->codecpar)) {
        avcodec_free_context(&avctx);
        return -1;
    }
    
    av_codec_set_pkt_timebase(avctx, stream->time_base);
    
    //查找解码器
    AVCodec *codec = avcodec_find_decoder(avctx->codec_id);
    if (!codec){
        avcodec_free_context(&avctx);
        return -1;
    }
    
    avctx->codec_id = codec->id;
    
    //打开解码器
    if (avcodec_open2(avctx, codec, NULL)) {
        avcodec_free_context(&avctx);
        return -1;
    }
    
    stream->discard = AVDISCARD_DEFAULT;
    self.stream = stream;
    self.avctx = avctx;
    
    if (avctx->codec_type == AVMEDIA_TYPE_AUDIO) {
        self.format = avctx->sample_fmt;
        self.sampleRate = avctx->sample_rate;
        self.channelLayout = (int)avctx->channel_layout;
    } else if (avctx->codec_type == AVMEDIA_TYPE_VIDEO) {
        self.format = avctx->pix_fmt;
        self.picWidth = avctx->width;
        self.picHeight = avctx->height;
    } else {
        
    }
    
    self.workThread = [[MRThread alloc] initWithTarget:self selector:@selector(workFunc) object:nil];
    
    return 0;
}

#pragma mark - 音视频通用解码方法

- (int)decodeAFrame:(AVCodecContext *)avctx result:(AVFrame*)frame
{
    for (;;) {
        int ret;
        do {
            //停止时，直接返回
            if (self.abort_request){
                return -1;
            }
            
            //先尝试接收帧
            ret = avcodec_receive_frame(avctx, frame);
            
            //成功接收到一个解码帧
            if (ret >= 0){
                return 1;
            }
            
            //结束标志，此次并没有获取到frame！
            if (ret == AVERROR_EOF) {
                avcodec_flush_buffers(avctx);
                return AVERROR_EOF;
            }
            
        } while (ret != AVERROR(EAGAIN)/*需要更多packet数据*/);
        
        AVPacket pkt;
        
        //[阻塞等待]直到获取一个packet
        int r = -1;
        if ([self.delegate respondsToSelector:@selector(decoder:wantAPacket:)]) {
            r = [self.delegate decoder:self wantAPacket:&pkt];
        }
        
        if (r < 0)
        {
            return -1;
        }
        
        //发送给解码器去解码
        if (avcodec_send_packet(avctx, &pkt) == AVERROR(EAGAIN)) {
            av_log(avctx, AV_LOG_ERROR, "Receive_frame and send_packet both returned EAGAIN, which is an API violation.\n");
        }
        //释放内存
        av_packet_unref(&pkt);
    }
}

#pragma mark - 解码线程

- (void)workFunc
{
    //创建一个frame就行了，可以复用
    AVFrame *frame = av_frame_alloc();
    if (!frame) {
        av_log(NULL, AV_LOG_ERROR, "%s can't alloc a frame.\n",[self.name UTF8String]);
        return;
    }
    do {
        //使用通用方法解码音频队列
        int got_frame = [self decodeAFrame:self.avctx result:frame];
        //解码出错
        if (got_frame < 0) {
            if (got_frame == AVERROR_EOF) {
                av_log(NULL, AV_LOG_ERROR, "%s eof.\n",[self.name UTF8String]);
            } else if (self.abort_request){
                av_log(NULL, AV_LOG_ERROR, "%s cancel.\n",[self.name UTF8String]);
            } else {
                av_log(NULL, AV_LOG_ERROR, "%s decode err %d.\n",[self.name UTF8String],got_frame);
            }
            break;
        } else {
            //正常解码
            av_log(NULL, AV_LOG_VERBOSE, "decode a audio frame:%lld\n",frame->pts);
            if ([self.delegate respondsToSelector:@selector(decoder:reveivedAFrame:)]) {
                [self.delegate decoder:self reveivedAFrame:frame];
            }
        }
    } while (1);
    
    //释放内存
    if (frame) {
        av_frame_free(&frame);
    }
}

- (void)start
{
    if (self.workThread) {
        self.workThread.name = self.name;
        [self.workThread start];
    }
}

- (void)cancel
{
    self.abort_request = 1;
    if (self.workThread) {
        [self.workThread cancel];
    }
}

- (void)join
{
    [self.workThread join];
    self.workThread = nil;
}

@end
