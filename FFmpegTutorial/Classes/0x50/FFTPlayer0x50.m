//
//  FFTPlayer0x50.m
//  FFmpegTutorial
//
//  Created by qianlongxu on 2022/1/10.
//

#import "FFTPlayer0x50.h"
#import "FFTThread.h"
#import "FFTConvertUtil.h"
#import "FFTDispatch.h"
#import <CoreVideo/CVPixelBufferPool.h>

@interface FFTPlayer0x50 ()

//渲染线程
@property (nonatomic, strong) FFTThread *rendererThread;
//PixelBuffer池可提升效率
@property (assign, nonatomic) CVPixelBufferPoolRef pixelBufferPool;
@property (atomic, assign) int abort_request;
@property (nonatomic, copy) dispatch_block_t onErrorBlock;
@property (assign, nonatomic) CGSize videoSize;

@end

@implementation  FFTPlayer0x50

- (void)_stop
{
    self.abort_request = 1;
    if (self.rendererThread) {
        [self.rendererThread cancel];
        [self.rendererThread join];
    }
    [self performSelectorOnMainThread:@selector(didStop:) withObject:self waitUntilDone:YES];
}

- (void)didStop:(id)sender
{
    self.rendererThread = nil;
    if (self.pixelBufferPool){
        CVPixelBufferPoolRelease(self.pixelBufferPool);
        self.pixelBufferPool = NULL;
    }
}

- (void)dealloc
{
    PRINT_DEALLOC;
}

- (void)prepareRendererThread
{
    self.rendererThread = [[FFTThread alloc] initWithTarget:self selector:@selector(rendererThreadFunc) object:nil];
    self.rendererThread.name = @"mr-renderer";
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
                    case FFTPlayer0x50VideoGrayType:
                    {
                        static int loopCount = 0;
                        static int op = 1;
                        static int barNum = 1;
                        int delta = 20;
                        
                        loopCount++;
                        if (loopCount % delta == 0) {
                            loopCount = 0;
                            barNum += op;
                            if (barNum >= 500 || barNum <= 0) {
                                op *= -1;
                                barNum += op;
                            }
                        }
                        sample = [FFTConvertUtil grayColorBarPixelBuffer:self.videoSize.width h:self.videoSize.height barNum:barNum opt:self.pixelBufferPool];
                    }
                        break;
                    case FFTPlayer0x50VideoSnowType:
                    {
                        sample = [FFTConvertUtil snowPixelBuffer:self.videoSize.width h:self.videoSize.height opt:self.pixelBufferPool];
                    }
                        break;
                    case FFTPlayer0x50Video3ballType:
                    {
                        sample = [FFTConvertUtil ball3PixelBuffer:self.videoSize.width h:self.videoSize.height opt:self.pixelBufferPool];
                    }
                        break;
                }
                
                if (sample) {
                    [self.delegate reveiveFrameToRenderer:[FFTConvertUtil cmSampleBufferRefFromCVPixelBufferRef:sample]];
                }
            }
        }
        
        NSTimeInterval end = CFAbsoluteTimeGetCurrent();
        int cost = (end - begin) * 1000;
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
    mr_sync_main_queue(^{
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

- (void)asyncStop
{
    [self performSelectorInBackground:@selector(_stop) withObject:self];
}

- (void)onError:(dispatch_block_t)block
{
    self.onErrorBlock = block;
}

@end
