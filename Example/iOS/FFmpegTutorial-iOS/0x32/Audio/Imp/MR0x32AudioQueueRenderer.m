//
//  MR0x32AudioQueueRenderer.m
//  FFmpegTutorial-iOS
//
//  Created by Matt Reach on 2020/8/4.
//  Copyright © 2020 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x32AudioQueueRenderer.h"
#import <AVFoundation/AVFoundation.h>

#define QUEUE_BUFFER_SIZE 3
#define MIN_SIZE_PER_FRAME 4096


@interface MR0x32AudioQueueRenderer ()
{
    AudioQueueBufferRef audioQueueBuffers[QUEUE_BUFFER_SIZE];
}

@property (nonatomic,copy) MRFetchPacketSample fetchBlock;
//音频渲染
@property (nonatomic,assign) AudioQueueRef audioQueue;
//音频信息结构体
@property (nonatomic,assign) AudioStreamBasicDescription outputFormat;

@end

@implementation MR0x32AudioQueueRenderer

- (void)dealloc
{
    if(_audioQueue){
        AudioQueueDispose(_audioQueue, YES);
        _audioQueue = NULL;
    }
}

- (void)onFetchPacketSample:(MRFetchPacketSample)block
{
    self.fetchBlock = block;
}

- (void)setup:(int)sampleRate isFloatFmt:(BOOL)isFloat
{
    // ----- Audio Queue Setup -----
    _outputFormat.mSampleRate = sampleRate;
    _outputFormat.mChannelsPerFrame = 2;
    _outputFormat.mFormatID = kAudioFormatLinearPCM;
    _outputFormat.mReserved = 0;
    
   if (isFloat) {
        _outputFormat.mFormatFlags = kAudioFormatFlagIsFloat;
        _outputFormat.mFramesPerPacket = 1;
        _outputFormat.mBitsPerChannel = sizeof(float) * 8;
    } else {
        _outputFormat.mFormatFlags |= kAudioFormatFlagIsSignedInteger;
        _outputFormat.mFramesPerPacket = 1;
        _outputFormat.mBitsPerChannel = sizeof(SInt16) * 8;
    }
    
    //packed only!
    _outputFormat.mFormatFlags |= kAudioFormatFlagIsPacked;
    _outputFormat.mBytesPerFrame = (_outputFormat.mBitsPerChannel / 8) * _outputFormat.mChannelsPerFrame;
    _outputFormat.mBytesPerPacket = _outputFormat.mBytesPerFrame * _outputFormat.mFramesPerPacket;
    
    OSStatus status = AudioQueueNewOutput(&self->_outputFormat, MRAudioQueueOutputCallback, (__bridge void *)self, CFRunLoopGetCurrent(), kCFRunLoopCommonModes, 0, &self->_audioQueue);
    
    NSAssert(noErr == status, @"AudioQueueNewOutput");
    
    //初始化音频缓冲区--audioQueueBuffers为结构体数组
    for(int i = 0; i < QUEUE_BUFFER_SIZE;i++){
        int result = AudioQueueAllocateBuffer(self.audioQueue,MIN_SIZE_PER_FRAME, &self->audioQueueBuffers[i]);
        NSAssert(noErr == result, @"AudioQueueAllocateBuffer");
    }
}

//音频渲染回调；
static void MRAudioQueueOutputCallback(
                                 void * __nullable       inUserData,
                                 AudioQueueRef           inAQ,
                                 AudioQueueBufferRef     inBuffer)
{
    MR0x32AudioQueueRenderer *am = (__bridge MR0x32AudioQueueRenderer *)inUserData;
    [am renderFramesToBuffer:inBuffer queue:inAQ];
}

- (UInt32)renderFramesToBuffer:(AudioQueueBufferRef) inBuffer queue:(AudioQueueRef)inAQ
{
    //1、填充数据
    UInt32 gotBytes = [self fetchPacketSample:inBuffer->mAudioData wantBytes:inBuffer->mAudioDataBytesCapacity];
    inBuffer->mAudioDataByteSize = gotBytes;
    
    // 2、通知 AudioQueue 有可以播放的 buffer 了
    AudioQueueEnqueueBuffer(inAQ, inBuffer, 0, NULL);
    return gotBytes;
}

- (UInt32)fetchPacketSample:(uint8_t*)buffer
                  wantBytes:(UInt32)bufferSize
{
    UInt32 filled = 0;
    if (self.fetchBlock) {
        filled = self.fetchBlock(buffer,bufferSize);
    }
    return filled;
}

- (void)onFetchPlanarSample:(MRFetchPlanarSample)block
{
    NSLog(@"Warning: audio queue not imp [-onFetchPlanarSample].");
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
   AudioQueuePause(self.audioQueue);
}

@end
