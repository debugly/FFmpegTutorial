//
//  MR0x32AudioUnitRenderer.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/9/26.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x32AudioUnitRenderer.h"
#import <AVFoundation/AVFoundation.h>

@interface MR0x32AudioUnitRenderer ()

@property (nonatomic, copy) MRFetchSamples fetchBlock;
//音频渲染
@property (nonatomic, assign) AudioUnit audioUnit;
@property (nonatomic, assign) BOOL isPacket;

@end

@implementation MR0x32AudioUnitRenderer

- (void)dealloc
{
    [self stop];
}

- (NSString *)name
{
    return @"AudioUnit";
}

- (void)onFetchSamples:(MRFetchSamples)block
{
    self.fetchBlock = block;
}

- (void)play
{
    if (self.audioUnit) {
        OSStatus status = AudioOutputUnitStart(self.audioUnit);
        NSAssert(noErr == status, @"AudioOutputUnitStart");
    }
}

- (void)pause
{
    if (self.audioUnit) {
        OSStatus status = AudioOutputUnitStop(self.audioUnit);
        NSAssert(noErr == status, @"AudioOutputUnitStart");
    }
}

- (void)stop
{
    if (self.audioUnit) {
        OSStatus status = AudioOutputUnitStop(self.audioUnit);
        NSAssert(noErr == status, @"AudioOutputUnitStart");
        self.audioUnit = NULL;
    }
}

- (void)setupAudioRender:(MRSampleFormat)fmt sampleRate:(Float64)sampleRate
{
    {
        // ----- Audio Unit Setup -----
#define kOutputBus 0 //Bus 0 is used for the output side
#define kInputBus  1 //Bus 0 is used for the output side
        
        // Describe the output unit.
        
        AudioComponentDescription desc = {0};
        desc.componentType = kAudioUnitType_Output;
    #if TARGET_OS_IOS
        desc.componentSubType = kAudioUnitSubType_RemoteIO;
    #else
        desc.componentSubType = kAudioUnitSubType_DefaultOutput;
    #endif
        desc.componentManufacturer = kAudioUnitManufacturer_Apple;
        
        // Get component
        AudioComponent component = AudioComponentFindNext(NULL, &desc);
        OSStatus status = AudioComponentInstanceNew(component, &_audioUnit);
        NSAssert(noErr == status, @"AudioComponentInstanceNew");
        
        AudioStreamBasicDescription outputFormat;
        
        UInt32 size = sizeof(outputFormat);
        // 获取默认的输入信息
        AudioUnitGetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, kOutputBus, &outputFormat, &size);
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
            outputFormat.mFormatFlags |= kAudioFormatFlagIsNonInterleaved;
            outputFormat.mBytesPerFrame = outputFormat.mBitsPerChannel / 8;
            outputFormat.mBytesPerPacket = outputFormat.mBytesPerFrame * outputFormat.mFramesPerPacket;
        } else {
            outputFormat.mFormatFlags |= kAudioFormatFlagIsPacked;
            outputFormat.mBytesPerFrame = (outputFormat.mBitsPerChannel / 8) * outputFormat.mChannelsPerFrame;
            outputFormat.mBytesPerPacket = outputFormat.mBytesPerFrame * outputFormat.mFramesPerPacket;
        }
        
        status = AudioUnitSetProperty(_audioUnit,
                             kAudioUnitProperty_StreamFormat,
                             kAudioUnitScope_Input,
                             kOutputBus,
                             &outputFormat, size);
        NSAssert(noErr == status, @"AudioUnitSetProperty");
        //get之后刷新这个值；
        //_targetSampleRate  = (int)outputFormat.mSampleRate;
        
        UInt32 flag = 0;
        AudioUnitSetProperty(_audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Input, kInputBus, &flag, sizeof(flag));
        AudioUnitSetProperty(_audioUnit, kAudioOutputUnitProperty_EnableIO, kAudioUnitScope_Output, kInputBus, &flag, sizeof(flag));
        // Slap a render callback on the unit
        AURenderCallbackStruct callbackStruct;
        callbackStruct.inputProc = MRRenderCallback;
        callbackStruct.inputProcRefCon = (__bridge void *)(self);
        
        status = AudioUnitSetProperty(_audioUnit,
                             kAudioUnitProperty_SetRenderCallback,
                             kAudioUnitScope_Input,
                             kOutputBus,
                             &callbackStruct,
                             sizeof(callbackStruct));
        NSAssert(noErr == status, @"AudioUnitSetProperty");
        status = AudioUnitInitialize(_audioUnit);
        NSAssert(noErr == status, @"AudioUnitInitialize");
#undef kOutputBus
#undef kInputBus
    }
}

//音频渲染回调；
static inline OSStatus MRRenderCallback(void *inRefCon,
                                        AudioUnitRenderActionFlags    * ioActionFlags,
                                        const AudioTimeStamp          * inTimeStamp,
                                        UInt32                        inOutputBusNumber,
                                        UInt32                        inNumberFrames,
                                        AudioBufferList                * ioData)
{
    uint8_t * buffer[2] = { 0 };
    UInt32 bufferSize = 0;
    // 1. 将buffer数组全部置为0；
    for (int i = 0; i < ioData->mNumberBuffers; i++) {
        AudioBuffer audioBuffer = ioData->mBuffers[i];
        bzero(audioBuffer.mData, audioBuffer.mDataByteSize);
        buffer[i] = (uint8_t *)audioBuffer.mData;
        bufferSize = audioBuffer.mDataByteSize;
    }
    
    MR0x32AudioUnitRenderer *am = (__bridge MR0x32AudioUnitRenderer *)inRefCon;
    [am fillBuffers:buffer byteSize:bufferSize];
    return noErr;
}

- (void)fillBuffers:(uint8_t *[2])buffer
           byteSize:(UInt32)bufferSize
{
    if (self.fetchBlock) {
        self.fetchBlock(buffer, bufferSize);
    }
}

@end
