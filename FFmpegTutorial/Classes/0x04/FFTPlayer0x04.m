//
//  FFTPlayer0x04.m
//  FFmpegTutorial
//
//  Created by qianlongxu on 2020/5/10.
//

#import "FFTPlayer0x04.h"
#import "FFTThread.h"
#import "FFTAbstractLogger.h"
#import "FFTDispatch.h"
#import <libavformat/avformat.h>

@interface FFTPlayer0x04 ()

//读包线程
@property (nonatomic, strong) FFTThread *readThread;
@property (atomic, assign) int abort_request;
@property (nonatomic, copy) dispatch_block_t onErrorBlock;
@property (atomic, assign, readwrite) int videoPktCount;
@property (atomic, assign, readwrite) int audioPktCount;

@end

@implementation  FFTPlayer0x04

static int decode_interrupt_cb(void *ctx)
{
    FFTPlayer0x04 *player = (__bridge FFTPlayer0x04 *)ctx;
    return player.abort_request;
}

- (void)_stop
{
    //避免重复stop做无用功
    if (self.readThread) {
        self.abort_request = 1;
        [self.readThread cancel];
        [self.readThread join];
    }
    [self performSelectorOnMainThread:@selector(didStop:) withObject:self waitUntilDone:YES];
}

- (void)didStop:(id)sender
{
    self.readThread = nil;
}

- (void)dealloc
{
    PRINT_DEALLOC;
}

//准备
- (void)prepareToPlay
{
    if (self.readThread) {
        NSAssert(NO, @"不允许重复创建");
    }
    
    
    self.readThread = [[FFTThread alloc] initWithTarget:self selector:@selector(readPacketsFunc) object:nil];
    self.readThread.name = @"mr-read";
}

#pragma -mark 读包线程

//读包循环
- (void)readPacketLoop:(AVFormatContext *)formatCtx
{
    AVPacket pkt1, *pkt = &pkt1;
    //循环读包
    for (;;) {
        
        //调用了stop方法，则不再读包
        if (self.abort_request) {
            break;
        }
        
        //读包
        int ret = av_read_frame(formatCtx, pkt);
        //读包出错
        if (ret < 0) {
            //读到最后结束了
            if ((ret == AVERROR_EOF || avio_feof(formatCtx->pb))) {
                //标志为读包结束
                av_log(NULL, AV_LOG_DEBUG, "stream eof:%s\n",formatCtx->url);
                break;
            }
            
            if (formatCtx->pb && formatCtx->pb->error) {
                break;
            }
            
            /* wait 10 ms */
            mr_msleep(10);
            continue;
        } else {
            //音频包入音频队列
            AVStream *stream = formatCtx->streams[pkt->stream_index];
            switch (stream->codecpar->codec_type) {
                case AVMEDIA_TYPE_VIDEO:
                {
                    self.videoPktCount++;
                }
                    break;
                case AVMEDIA_TYPE_AUDIO:
                {
                    self.audioPktCount++;
                }
                    break;
                default:
                    break;
            }
            //释放内存
            av_packet_unref(pkt);
            
            if (self.onReadPkt) {
                self.onReadPkt(self.audioPktCount,self.videoPktCount);
            }
        }
    }
}

- (void)readPacketsFunc
{
    NSParameterAssert(self.contentPath);
    
    if (![self.contentPath hasPrefix:@"/"]) {
            avformat_network_init();
        }
        
        AVFormatContext *formatCtx = avformat_alloc_context();
        
        if (!formatCtx) {
            self.error = _make_nserror_desc(FFPlayerErrorCode_AllocFmtCtxFailed, @"创建 AVFormatContext 失败！");
            [self performErrorResultOnMainThread];
            return;
        }
        
        formatCtx->interrupt_callback.callback = decode_interrupt_cb;
        formatCtx->interrupt_callback.opaque = (__bridge void *)self;
        
        /*
         打开输入流，读取文件头信息，不会打开解码器；
         */
        //低版本是 av_open_input_file 方法
        const char *moviePath = [self.contentPath cStringUsingEncoding:NSUTF8StringEncoding];
        
        //打开文件流，读取头信息；
        if (0 != avformat_open_input(&formatCtx, moviePath , NULL, NULL)) {
            
            //释放内存
            avformat_free_context(formatCtx);
            
            //当取消掉时，不给上层回调
            if (self.abort_request) {
                return;
            }
            self.error = _make_nserror_desc(FFPlayerErrorCode_OpenFileFailed, @"文件打开失败！");
            [self performErrorResultOnMainThread];
            return;
        }
        
        /* 刚才只是打开了文件，检测了下文件头而已，并不知道流信息；因此开始读包以获取流信息
         设置读包探测大小和最大时长，避免读太多的包！
        */
        formatCtx->probesize = 500 * 1024;
        formatCtx->max_analyze_duration = 5 * AV_TIME_BASE;
    #if DEBUG
        NSTimeInterval begin = [[NSDate date] timeIntervalSinceReferenceDate];
    #endif
        if (0 != avformat_find_stream_info(formatCtx, NULL)) {
            avformat_close_input(&formatCtx);
            self.error = _make_nserror_desc(FFPlayerErrorCode_StreamNotFound, @"不能找到流！");
            [self performErrorResultOnMainThread];
            //出错了，销毁下相关结构体
            avformat_close_input(&formatCtx);
            return;
        }
        
    #if DEBUG
        NSTimeInterval end = [[NSDate date] timeIntervalSinceReferenceDate];
        //用于查看详细信息，调试的时候打出来看下很有必要
        av_dump_format(formatCtx, 0, moviePath, false);
        MRFF_DEBUG_LOG(@"avformat_find_stream_info coast time:%g",end-begin);
    #endif
        
        //循环读包
        [self readPacketLoop:formatCtx];
        //读包线程结束了，销毁下相关结构体
        avformat_close_input(&formatCtx);
}

- (void)performErrorResultOnMainThread
{
    mr_sync_main_queue(^{
        if (self.onErrorBlock) {
            self.onErrorBlock();
        }
    });
}

- (void)play
{
    [self.readThread start];
}

- (void)asyncStop
{
    [self performSelectorInBackground:@selector(_stop) withObject:self];
}

- (void)onError:(dispatch_block_t)block
{
    self.onErrorBlock = block;
}

@end
