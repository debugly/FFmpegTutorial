//
//  MR0x32AudioUnitRenderer.m
//  FFmpegTutorial-iOS
//
//  Created by Matt Reach on 2020/8/4.
//  Copyright © 2020 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MR0x32AudioUnitRenderer.h"
#import <AVFoundation/AVFoundation.h>

@interface MR0x32AudioUnitRenderer ()

@property (nonatomic,copy) MRFetchPacketSample fetchPacketBlock;
@property (nonatomic,copy) MRFetchPlanarSample fetchPlanarBlock;

//音频渲染
@property (nonatomic,assign) AudioUnit audioUnit;
@property (nonatomic,assign) BOOL isPacket;

@end

@implementation MR0x32AudioUnitRenderer

- (void)dealloc
{
    if(_audioUnit){
        AudioOutputUnitStop(_audioUnit);
        _audioUnit = NULL;
    }
}

- (void)onFetchPacketSample:(MRFetchPacketSample)block
{
    self.fetchPacketBlock = block;
}

- (void)onFetchPlanarSample:(MRFetchPlanarSample)block
{
    self.fetchPlanarBlock = block;
}

- (void)setup:(int)sampleRate
   isFloatFmt:(BOOL)isFloat
     isPacket:(BOOL)isPacket
{
    self.isPacket = isPacket;
    
    // ----- Audio Unit Setup -----

#define kOutputBus 0 //Bus 0 is used for the output side
#define kInputBus  1 //Bus 0 is used for the output side
            
    // Describe the output unit.
    
    AudioComponentDescription desc = {0};
    desc.componentType = kAudioUnitType_Output;
    desc.componentSubType = kAudioUnitSubType_RemoteIO;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    // Get component
    AudioComponent component = AudioComponentFindNext(NULL, &desc);
    OSStatus status = AudioComponentInstanceNew(component, &_audioUnit);
    NSAssert(noErr == status, @"AudioComponentInstanceNew");
    
    AudioStreamBasicDescription outputFormat;
    
    UInt32 size = sizeof(outputFormat);
    /// 获取默认的输入信息
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
    
    if (isFloat){
        outputFormat.mFormatFlags = kAudioFormatFlagIsFloat;
        outputFormat.mFramesPerPacket = 1;
        outputFormat.mBitsPerChannel = sizeof(float) * 8;
    } else {
        outputFormat.mFormatFlags = kAudioFormatFlagIsSignedInteger;
        outputFormat.mFramesPerPacket = 1;
        outputFormat.mBitsPerChannel = sizeof(SInt16) * 8;
    }
    
    if (isPacket) {
        outputFormat.mFormatFlags |= kAudioFormatFlagIsPacked;
        outputFormat.mBytesPerFrame = (outputFormat.mBitsPerChannel / 8) * outputFormat.mChannelsPerFrame;
        outputFormat.mBytesPerPacket = outputFormat.mBytesPerFrame * outputFormat.mFramesPerPacket;
    } else {
        outputFormat.mFormatFlags |= kAudioFormatFlagIsNonInterleaved;
        outputFormat.mBytesPerFrame = outputFormat.mBitsPerChannel / 8;
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

#pragma mark - 音频

///音频渲染回调；
static inline OSStatus MRRenderCallback(void *inRefCon,
                                        AudioUnitRenderActionFlags    * ioActionFlags,
                                        const AudioTimeStamp          * inTimeStamp,
                                        UInt32                        inOutputBusNumber,
                                        UInt32                        inNumberFrames,
                                        AudioBufferList                * ioData)
{
    MR0x32AudioUnitRenderer *am = (__bridge MR0x32AudioUnitRenderer *)inRefCon;
    return [am renderFrames:inNumberFrames ioData:ioData];
}

- (bool)renderFrames:(UInt32) wantFrames
              ioData:(AudioBufferList *) ioData
{
    // 1. 将buffer数组全部置为0；
    for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
        AudioBuffer audioBuffer = ioData->mBuffers[iBuffer];
        bzero(audioBuffer.mData, audioBuffer.mDataByteSize);
    }
    
    ///目标是Packet类型
    if(self.isPacket){
    
        //    numFrames = 1115
        //    SInt16 = 2;
        //    mNumberChannels = 2;
        //    ioData->mBuffers[iBuffer].mDataByteSize = 4460
        // 4460 = numFrames x SInt16 * mNumberChannels = 1115 x 2 x 2;
        
        // 2. 获取 AudioUnit 的 Buffer
        int numberBuffers = ioData->mNumberBuffers;
        
        // AudioUnit 对于 packet 形式的PCM，只会提供一个 AudioBuffer
        if (numberBuffers >= 1) {
            
            AudioBuffer audioBuffer = ioData->mBuffers[0];
            //这个是 AudioUnit 给我们提供的用于存放采样点的buffer
            uint8_t *buffer = audioBuffer.mData;
            // 长度可以这么计算，也可以使用 audioBuffer.mDataByteSize 获取
            //                ///每个采样点占用的字节数:
            //                UInt32 bytesPrePack = self.outputFormat.mBitsPerChannel / 8;
            //                ///Audio的Frame是包括所有声道的，所以要乘以声道数；
            //                const NSUInteger frameSizeOf = 2 * bytesPrePack;
            //                ///向缓存的音频帧索要wantBytes个音频采样点: wantFrames x frameSizeOf
            //                NSUInteger bufferSize = wantFrames * frameSizeOf;
            const UInt32 bufferSize = audioBuffer.mDataByteSize;
            /* 对于 AV_SAMPLE_FMT_S16 而言，采样点是这么分布的:
             S16_L,S16_R,S16_L,S16_R,……
             AudioBuffer 也需要这样的排列格式，因此直接copy即可；
             同理，对于 FLOAT 也是如此左右交替！
             */
            
            ///3. 获取 bufferSize 个字节，并塞到 buffer 里；
            [self fetchPacketSample:buffer wantBytes:bufferSize];
        } else {
            NSLog(@"what's wrong?");
        }
    }
    
    ///目标是Planar类型，Mac平台支持整形和浮点型，交错和二维平面
    
    else {
        
        //    numFrames = 558
        //    float = 4;
        //    ioData->mBuffers[iBuffer].mDataByteSize = 2232
        // 2232 = numFrames x float = 558 x 4;
        // FLTP = FLOAT + Planar;
        // FLOAT: 具体含义是使用 float 类型存储量化的采样点，比 SInt16 精度要高出很多！当然空间也大些！
        // Planar: 二维的，所以会把左右声道使用两个数组分开存储，每个数组里的元素是同一个声道的！
        
        //when outputFormat.mChannelsPerFrame == 2
        if (ioData->mNumberBuffers == 2) {
            // 2. 向缓存的音频帧索要 ioData->mBuffers[0].mDataByteSize 个字节的数据
            /*
             Float_L,Float_L,Float_L,Float_L,……  -> mBuffers[0].mData
             Float_R,Float_R,Float_R,Float_R,……  -> mBuffers[1].mData
             左对左，右对右
             
             同理，对于 S16P 也是如此！一一对应！
             */
            //3. 获取左右声道数据
            [self fetchPlanarSample:ioData->mBuffers[0].mData leftSize:ioData->mBuffers[0].mDataByteSize right:ioData->mBuffers[1].mData rightSize:ioData->mBuffers[1].mDataByteSize];
        }
        //when outputFormat.mChannelsPerFrame == 1;不会左右分开
        else {
            [self fetchPlanarSample:ioData->mBuffers[0].mData leftSize:ioData->mBuffers[0].mDataByteSize right:NULL rightSize:0];
        }
    }
    return noErr;
}

- (UInt32)fetchPacketSample:(uint8_t*)buffer
                  wantBytes:(UInt32)bufferSize
{
    UInt32 filled = 0;
    if (self.fetchPacketBlock) {
        filled = self.fetchPacketBlock(buffer,bufferSize);
    }
    return filled;
}

- (UInt32)fetchPlanarSample:(uint8_t*)left
                   leftSize:(UInt32)leftSize
                      right:(uint8_t*)right
                  rightSize:(UInt32)rightSize
{
    UInt32 filled = 0;
    if (self.fetchPlanarBlock) {
        filled = self.fetchPlanarBlock(left,leftSize,right,rightSize);
    }
    return filled;
}

- (void)setup:(int)sampleRate isFloatFmt:(BOOL)isFloat
{
    NSAssert(NO, @"Please call [setup:isFloatFmt:isPacket]");
}

- (void)play
{
    OSStatus status = AudioOutputUnitStart(_audioUnit);
    NSAssert(noErr == status, @"AudioOutputUnitStart");
}

- (void)pause
{
    OSStatus status = AudioOutputUnitStop(_audioUnit);
    NSAssert(noErr == status, @"AudioOutputUnitStop");
}

@end
