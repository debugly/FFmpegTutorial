//
//  FFPlayer0x40.m
//  FFmpegTutorial
//
//  Created by qianlongxu on 2022/1/10.
//

#import "FFPlayer0x40.h"
#import "MRThread.h"
#import "MRConvertUtil.h"
#import "FFPlayerInternalHeader.h"
#import <CoreVideo/CVPixelBufferPool.h>

@interface FFPlayer0x40 ()

//渲染线程
@property (nonatomic, strong) MRThread *rendererThread;
//PixelBuffer池可提升效率
@property (assign, nonatomic) CVPixelBufferPoolRef pixelBufferPool;
@property (atomic, assign) int abort_request;
@property (nonatomic, copy) dispatch_block_t onErrorBlock;
@property (assign, nonatomic) CGSize videoSize;

@end

@implementation  FFPlayer0x40

- (void)_stop
{
    self.abort_request = 1;
    if (self.rendererThread) {
        [self.rendererThread cancel];
        [self.rendererThread join];
        self.rendererThread = nil;
    }
    
    if (self.pixelBufferPool){
        CVPixelBufferPoolRelease(self.pixelBufferPool);
        self.pixelBufferPool = NULL;
    }
}

- (void)dealloc
{
    [self _stop];
}

- (void)prepareRendererThread
{
    self.rendererThread = [[MRThread alloc] initWithTarget:self selector:@selector(rendererThreadFunc) object:nil];
    self.rendererThread.name = @"renderer";
}

- (void)rendererThreadFunc
{
    //调用了stop方法，则不再渲染
    while (!self.abort_request) {
        
        NSTimeInterval begin = CFAbsoluteTimeGetCurrent();
        
        if ([self.delegate respondsToSelector:@selector(reveiveFrameToRenderer:)]) {
            @autoreleasepool {
                
                CVPixelBufferRef sample = NULL;
                switch (self.videoType) {
                    case FFPlayer0x40VideoGrayType:
                    {
                        sample = [MRConvertUtil grayColorBarPixelBuffer:self.videoSize.width h:self.videoSize.height opt:self.pixelBufferPool];
                    }
                        break;
                    case FFPlayer0x40VideoSnowType:
                    {
                        sample = [MRConvertUtil snowPixelBuffer:self.videoSize.width h:self.videoSize.height opt:self.pixelBufferPool];
                    }
                        break;
                }
                
                if (sample) {
                    [self.delegate reveiveFrameToRenderer:[MRConvertUtil cmSampleBufferRefFromCVPixelBufferRef:sample]];
                }
            }
        }
        
        NSTimeInterval end = CFAbsoluteTimeGetCurrent();
        int cost = (end - begin) * 1000;
        av_log(NULL, AV_LOG_DEBUG, "render video frame cost:%dms\n", cost);
        int delay = 40 - cost;
        if (delay > 0) {
            mr_msleep(delay);
        }
    }
}

- (void)prapareWithSize:(CGSize)size
{
    self.videoSize = size;
    //准备渲染线程
    [self prepareRendererThread];
}

- (void)performErrorResultOnMainThread
{
    MR_sync_main_queue(^{
        if (self.onErrorBlock) {
            self.onErrorBlock();
        }
    });
}

- (void)play
{
    //渲染线程开始工作
    [self.rendererThread start];
}

- (void)stop
{
    [self _stop];
}

- (void)onError:(dispatch_block_t)block
{
    self.onErrorBlock = block;
}

@end
