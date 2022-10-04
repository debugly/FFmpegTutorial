//
//  MR0x30AudioQueueRenderer.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/9/26.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x30AudioQueueRenderer.h"
#import <AVFoundation/AVFoundation.h>

#define QUEUE_BUFFER_SIZE 3
#define MIN_SIZE_PER_FRAME 4096

@interface MR0x30AudioQueueRenderer ()
{
    AudioQueueBufferRef audioQueueBuffers[QUEUE_BUFFER_SIZE];
}

@property (nonatomic,copy) MRFetchSamples fetchBlock;
//音频渲染
@property (nonatomic,assign) AudioQueueRef audioQueue;
//音频信息结构体
@property (nonatomic,assign) AudioStreamBasicDescription outputFormat;

@end

@implementation MR0x30AudioQueueRenderer

- (void)dealloc
{
    [self stop];
}

- (NSString *)name
{
    return @"AudioQueue";
}

- (void)onFetchSamples:(MRFetchSamples)block
{
    self.fetchBlock = block;
}

- (void)setupAudioRender:(MRSampleFormat)fmt sampleRate:(Float64)sampleRate
{
    {
        AudioStreamBasicDescription outputFormat;
        //设置采样率
        outputFormat.mSampleRate = sampleRate;
        /**不使用视频的原声道数_audioCodecCtx->channels;
         mChannelsPerFrame 这个值决定了后续AudioUnit索要数据时 ioData->mNumberBuffers 的值！
         如果写成1会影响Planar类型，就不会开两个buffer了！！因此这里写死为2！
         */
        outputFormat.mChannelsPerFrame = 2;
        outputFormat.mFormatID = kAudioFormatLinearPCM;
        outputFormat.mReserved = 0;
        
        bool isFloat  = MR_Sample_Fmt_Is_FloatX(fmt);
        bool isS16    = MR_Sample_Fmt_Is_S16X(fmt);
        bool isPlanar = MR_Sample_Fmt_Is_Planar(fmt);
        
        if (isS16){
            outputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger;
            outputFormat.mFramesPerPacket = 1;
            outputFormat.mBitsPerChannel = sizeof(SInt16) * 8;
        } else if (isFloat){
            outputFormat.mFormatFlags = kAudioFormatFlagIsFloat;
            outputFormat.mFramesPerPacket = 1;
            outputFormat.mBitsPerChannel = sizeof(float) * 8;
        } else {
            NSAssert(NO, @"不支持的音频采样格式%d",fmt);
        }
        
        if (isPlanar) {
            NSAssert(NO, @"Audio Queue Support packet fmt only!");
            outputFormat.mFormatFlags |= kAudioFormatFlagIsNonInterleaved;
            outputFormat.mBytesPerFrame = outputFormat.mBitsPerChannel / 8;
            outputFormat.mBytesPerPacket = outputFormat.mBytesPerFrame * outputFormat.mFramesPerPacket;
        } else {
            outputFormat.mFormatFlags |= kAudioFormatFlagIsPacked;
            outputFormat.mBytesPerFrame = (outputFormat.mBitsPerChannel / 8) * outputFormat.mChannelsPerFrame;
            outputFormat.mBytesPerPacket = outputFormat.mBytesPerFrame * outputFormat.mFramesPerPacket;
        }
        
        OSStatus status = AudioQueueNewOutput(&outputFormat, MRAudioQueueOutputCallback, (__bridge void *)self, CFRunLoopGetCurrent(), kCFRunLoopCommonModes, 0, &self->_audioQueue);
                
        NSAssert(noErr == status, @"AudioQueueNewOutput");
        
        //初始化音频缓冲区--audioQueueBuffers为结构体数组
        for (int i = 0; i < QUEUE_BUFFER_SIZE; i++) {
            int result = AudioQueueAllocateBuffer(self.audioQueue,MIN_SIZE_PER_FRAME, &self->audioQueueBuffers[i]);
            NSAssert(noErr == result, @"AudioQueueAllocateBuffer");
        }
    }
}

//音频渲染回调；
static void MRAudioQueueOutputCallback(
                                 void * __nullable       inUserData,
                                 AudioQueueRef           inAQ,
                                 AudioQueueBufferRef     inBuffer)
{
    MR0x30AudioQueueRenderer *am = (__bridge MR0x30AudioQueueRenderer *)inUserData;
    [am renderFramesToBuffer:inBuffer queue:inAQ];
}

- (UInt32)renderFramesToBuffer:(AudioQueueBufferRef) inBuffer queue:(AudioQueueRef)inAQ
{
    //1、填充数据
    uint8_t * buffer[2] = { 0 };
    buffer[0] = inBuffer->mAudioData;
    UInt32 gotBytes = [self fillBuffers:buffer byteSize:inBuffer->mAudioDataBytesCapacity];
    inBuffer->mAudioDataByteSize = gotBytes;
    
    // 2、通知 AudioQueue 有可以播放的 buffer 了
    AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
    return gotBytes;
}

- (UInt32)fillBuffers:(uint8_t *[2])buffer
           byteSize:(UInt32)bufferSize
{
    UInt32 filled = 0;
    if (self.fetchBlock) {
        filled = self.fetchBlock(buffer,bufferSize);
    }
    return filled;
}

- (void)play
{
    for(int i = 0; i < QUEUE_BUFFER_SIZE;i++){
        AudioQueueBufferRef ref = self->audioQueueBuffers[i];
        [self renderFramesToBuffer:ref queue:self.audioQueue];
    }
    
    OSStatus status = AudioQueueStart(self.audioQueue, NULL);
    NSAssert(noErr == status, @"AudioOutputUnitStart");
}

- (void)pause
{
    if (self.audioQueue) {
        AudioQueuePause(self.audioQueue);
    }
}

- (void)stop
{
    if (self.audioQueue) {
        AudioQueueDispose(self.audioQueue, YES);
        self.audioQueue = NULL;
    }
}

@end
