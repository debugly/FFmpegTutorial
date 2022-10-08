//
//  FFTDecoder0x20.m
//  FFmpegTutorial
//
//  Created by Matt Reach on 2022/7/10.
//

#import "FFTDecoder0x20.h"
#import <libavcodec/avcodec.h>
#import <libavformat/avformat.h>

@interface FFTDecoder0x20()
{
    //创建一个frame就行了，可以复用
    AVFrame *_frame;
}

@property (nonatomic, assign, readwrite) AVStream * stream;
@property (nonatomic, assign) AVCodecContext * avctx;
//for video
@property (nonatomic, assign, readwrite) int format;
@property (nonatomic, assign, readwrite) int picWidth;
@property (nonatomic, assign, readwrite) int picHeight;
//for audio
@property (nonatomic, assign, readwrite) int sampleRate;
@property (nonatomic, assign, readwrite) int channelLayout;

@end

@implementation FFTDecoder0x20

- (void)dealloc
{
    //释放解码器上下文
    if (_avctx) {
        avcodec_free_context(&_avctx);
        _avctx = NULL;
    }
    //释放内存
    if (_frame) {
        av_frame_free(&_frame);
    }
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _streamIdx = -1;
        _frame = av_frame_alloc();
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
    
    avctx->pkt_timebase = stream->time_base;
    
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
    return 0;
}

#pragma mark - 音视频通用解码方法

- (int)decoder_decode_frame:(AVCodecContext *)avctx pkt:(AVPacket *)pkt frame:(AVFrame*)frame
{
    int ret = 0;
    
    for (;;) {
        do {
            //先尝试接收帧
            ret = avcodec_receive_frame(avctx, frame);
            
            //成功接收到一个解码帧
            if (ret >= 0){
                if ([self.delegate respondsToSelector:@selector(decoder:reveivedAFrame:)]) {
                    [self.delegate decoder:self reveivedAFrame:frame];
                }
                av_frame_unref(frame);
                continue;
            }
            
            //结束标志，此次并没有获取到frame！
            if (ret == AVERROR_EOF) {
                avcodec_flush_buffers(avctx);
                goto end;
            }
            
        } while (ret != AVERROR(EAGAIN)/*需要更多packet数据*/);
        
        if (pkt) {
            //发送给解码器去解码
            if (avcodec_send_packet(avctx, pkt) == AVERROR(EAGAIN)) {
                av_log(avctx, AV_LOG_ERROR, "Receive_frame and send_packet both returned EAGAIN, which is an API violation.\n");
            }
            pkt = NULL;
            continue;
        } else {
            break;
        }
    }
end:
    return ret;
}

- (int)sendPacket:(AVPacket *)pkt
{
    int r = [self decoder_decode_frame:_avctx pkt:pkt frame:_frame];
    return r;
}

@end
