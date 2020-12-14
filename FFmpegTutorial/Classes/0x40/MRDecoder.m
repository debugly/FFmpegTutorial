//
//  MRDecoder.m
//  FFmpegTutorial
//
//  Created by Matt Reach on 2020/6/2.
//

#import "MRDecoder.h"
#include <libavcodec/avcodec.h>
#include <libavformat/avformat.h>

@interface MRDecoder()

//解码线程
@property (nonatomic, assign, readwrite) AVStream * stream;
@property (nonatomic, assign) AVCodecContext * avctx;
@property (nonatomic, assign) int abort_request;
//for video
@property (nonatomic, assign, readwrite) int picWidth;
@property (nonatomic, assign, readwrite) int picHeight;
@property (nonatomic, copy, readwrite) NSString * codecName;

@end

@implementation MRDecoder

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

- (void)dumpStreamFormat
{
    if (self.ic == NULL) {
        return;
    }
    
    if (self.streamIdx < 0 || self.streamIdx >= self.ic->nb_streams){
        return;
    }
    
    AVStream *stream = self.ic->streams[self.streamIdx];
    
    if (stream->codecpar) {
        self.pix_fmt   = stream->codecpar->format;
        self.picWidth  = stream->codecpar->width;
        self.picHeight = stream->codecpar->height;
        //解码器id
        enum AVCodecID codecID = stream->codecpar->codec_id;
        //根据解码器id找到对应名称
        const char *codecName = avcodec_get_name(codecID);
        self.codecName = [[NSString alloc] initWithUTF8String:codecName];
    }
}

- (BOOL)open
{
    if (self.ic == NULL) {
        return NO;
    }
    
    if (self.streamIdx < 0 || self.streamIdx >= self.ic->nb_streams){
        return NO;
    }
    
    AVStream *stream = self.ic->streams[self.streamIdx];
    
    //创建解码器上下文
    AVCodecContext *avctx = avcodec_alloc_context3(NULL);
    if (!avctx) {
        return NO;
    }
    
    //填充下相关参数
    if (avcodec_parameters_to_context(avctx, stream->codecpar)) {
        avcodec_free_context(&avctx);
        return NO;
    }
    
    //av_codec_set_pkt_timebase(avctx, stream->time_base);
    
    //查找解码器
    AVCodec *codec = avcodec_find_decoder(avctx->codec_id);
    if (!codec){
        avcodec_free_context(&avctx);
        return NO;
    }
    
    avctx->codec_id = codec->id;
    // important! 前面设置成了 AVDISCARD_ALL，这里必须修改下，否则可能导致读包失败；根据vtp的场景，这里使用丢弃非关键帧比较合适
    stream->discard = AVDISCARD_NONKEY;
    //打开解码器
    if (avcodec_open2(avctx, codec, NULL)) {
        avcodec_free_context(&avctx);
        return NO;
    }
    self.stream = stream;
    self.avctx = avctx;
    
    return YES;
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

#pragma mark - 解码开始

- (void)start
{
    //创建一个frame就行了，可以复用
    AVFrame *frame = av_frame_alloc();
    if (!frame) {
        av_log(NULL, AV_LOG_ERROR, "%s can't alloc a frame.\n",[self.name UTF8String]);
        return;
    }
    do {
        //使用通用方法解码一帧
        int got_frame = [self decodeAFrame:self.avctx result:frame];
        //解码出错
        if (got_frame < 0) {
            if (got_frame == AVERROR_EOF) {
                BOOL hasMorePkt = NO;
                if ([self.delegate respondsToSelector:@selector(decoderHasMorePacket:)]) {
                    hasMorePkt = [self.delegate decoderHasMorePacket:self];
                }
                if (hasMorePkt) {
                    av_log(NULL, AV_LOG_INFO, "has more pkt need decode.\n");
                    continue;
                } else {
                    av_log(NULL, AV_LOG_ERROR, "%s eof.\n",[self.name UTF8String]);
                    break;
                }
            } else if (self.abort_request){
                av_log(NULL, AV_LOG_ERROR, "%s cancel.\n",[self.name UTF8String]);
            } else {
                av_log(NULL, AV_LOG_ERROR, "%s decode err %d.\n",[self.name UTF8String],got_frame);
            }
            break;
        } else {
            //正常解码
            if (frame->pts != AV_NOPTS_VALUE) {
                av_log(NULL, AV_LOG_VERBOSE, "decode a frame:%lld\n",frame->pts);
            } else {
                #warning todo fill pts
            }
            if ([self.delegate respondsToSelector:@selector(decoder:reveivedAFrame:)]) {
                [self.delegate decoder:self reveivedAFrame:frame];
            }
        }
    } while (1);
    
    //释放内存
    if (frame) {
        av_frame_free(&frame);
    }
    
    if ([self.delegate respondsToSelector:@selector(decoderEOF:)]) {
        [self.delegate decoderEOF:self];
    }
}

- (void)cancel
{
    self.abort_request = 1;
}


@end
