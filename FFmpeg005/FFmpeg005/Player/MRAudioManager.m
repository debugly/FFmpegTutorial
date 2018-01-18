//
//  MRAudioManager.m
//  HelloWorld
//
//  Created by xuqianlong on 15/5/22.
//  Copyright (c) 2015年 xuqianlong. All rights reserved.
//

@import CoreAudio;
@import AudioUnit;
@import AudioToolbox;

#import "MRAudioManager.h"
//#import <CoreAudio/CoreAudioTypes.h>
//#import <CoreFoundation/CoreFoundation.h>
#import <AudioToolbox/AudioToolbox.h>
#import <AVFoundation/AVFoundation.h>
#import <Accelerate/Accelerate.h>

#define kMax_Frame_Size     4096
#define kMax_Chan           2
#define kMax_Sample_Dumped  5

@interface MRAudioManagerPrivateImp : MRAudioManager<MRAudioManager>
{
    bool        _initialized;
    bool        _activated;
    float       *_outData;
    AudioUnit   _audioUnit;
    AudioStreamBasicDescription _outputFormat;
}

@property (nonatomic,readonly) NSInteger   numOutputChannels;
@property (nonatomic,readonly) Float64  samplingRate;
@property (nonatomic,readonly) UInt32   numBytesPerSample;
@property (nonatomic,readwrite) Float32  outputVolume;
@property (nonatomic,readonly) bool     playing;
@property (nonatomic,readonly,copy) NSString *audioRoute;

@property (nonatomic,copy) MRAudioManagerOutputBlock outputBlock;
@property (nonatomic) bool playAfterSessionEndInterruption;

- (bool) checkAudioRoute;
- (bool) setupAudioSession;
- (bool) checkSessionProperties;
//渲染音频数据；
- (bool) renderFrames:(UInt32) numFrames
               ioData:(AudioBufferList *)ioData;

@end

@implementation MRAudioManagerPrivateImp

static inline bool checkError(OSStatus error,const char *operation)
{
    if (error == noErr) {return NO;}
    char str[20] = {0};
    *(UInt32 *)(str + 1) = CFSwapInt32HostToBig(error);
    if (isprint(str[1]) && isprint(str[2]) && isprint(str[3]) && isprint(str[4]))
    {
        str[0] = str[5] = '\'';
        str[6] = '\0';
    }else{
        sprintf(str, "%d",(int)error);
    }
    
    return YES;
}

- (void)audioRouteChanged:(NSNotification *)notifi
{
    ///TODO
}

static inline void LLLsessionPropertyListener(void * inClientData,
                                              AudioSessionPropertyID inID,
                                              UInt32 inDataSize,
                                              const void * inData)
{
    MRAudioManagerPrivateImp *am = (__bridge MRAudioManagerPrivateImp *)inClientData;
    if (inID == kAudioSessionProperty_AudioRouteChange) {
        
        if ([am checkAudioRoute]) {
            [am checkSessionProperties];
        }
        
    }else if (inID == kAudioSessionProperty_CurrentHardwareOutputVolume){
        
        if (inData && inDataSize == 4) {
            am.outputVolume = *(float *)inData;
        }
        
    }
}

///音频渲染回调；
static inline OSStatus LLLRenderCallback(void *inRefCon,
                                         AudioUnitRenderActionFlags    * ioActionFlags,
                                         const AudioTimeStamp          * inTimeStamp,
                                         UInt32                        inOutputBusNumber,
                                         UInt32                        inNumberFrames,
                                         AudioBufferList                * ioData)
{
    MRAudioManagerPrivateImp *am = (__bridge MRAudioManagerPrivateImp *)inRefCon;
    return [am renderFrames:inNumberFrames ioData:ioData];
}

static inline void LLLsessionInterruptionListener(void *inClientData, UInt32 inInterruption)
{
    MRAudioManagerPrivateImp *am = (__bridge MRAudioManagerPrivateImp *)inClientData;
    
    if (inInterruption == kAudioSessionBeginInterruption) {
        
        am.playAfterSessionEndInterruption = am.playing;
        [am pause];
        
    } else if (inInterruption == kAudioSessionEndInterruption) {
        
        if (am.playAfterSessionEndInterruption) {
            am.playAfterSessionEndInterruption = NO;
            [am play];
        }
    }
}

- (instancetype)init
{
    self = [super init];
    if (self) {
        _outData = (float *)calloc(kMax_Frame_Size * kMax_Chan, sizeof(float));
        _outputVolume = 0.5;
    }
    return self;
}

- (void)dealloc
{
    if (_outData) {
        free(_outData);
        _outData = NULL;
    }
}

- (bool) checkAudioRoute
{
    AVAudioSessionRouteDescription *routeDescription = [[AVAudioSession sharedInstance]currentRoute];
    //    NSArray *inputs = routeDescription.inputs;
    NSArray *outputs = routeDescription.outputs;
    
    //    UInt32 propertySize = sizeof(CFStringRef);
    //    CFStringRef route;
    //    if (checkError(AudioSessionGetProperty(kAudioSessionProperty_AudioRoute, &propertySize, &route), "Counldn't check the audio route")) {
    //        return NO;
    //    }
    //    _audioRoute = CFBridgingRelease(route);
    
    AVAudioSessionPortDescription *outPut = [outputs lastObject];
    _audioRoute = outPut.portName;
    return YES;
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary<NSKeyValueChangeKey,id> *)change context:(void *)context
{
    if([@"outputVolume" isEqualToString:keyPath]){
        NSLog(@"outputVolume changed:%@",change);
    }
}

- (bool) setupAudioSession
{
    // --- Setup Audio Session  ---
    [[AVAudioSession sharedInstance]setCategory:AVAudioSessionCategoryPlayback withOptions:AVAudioSessionCategoryOptionDefaultToSpeaker error:nil];
    
    //    UInt32 sessionCategory = kAudioSessionCategory_MediaPlayback;
    //    //UInt32 sessionCategory = kAudioSessionCategory_PlayAndRecord;
    //    if (checkError(AudioSessionSetProperty(kAudioSessionProperty_AudioCategory, sizeof(sessionCategory), &sessionCategory), "Couldn't set audio category")) {
    //        return NO;
    //    }
    
    [[NSNotificationCenter defaultCenter]addObserver:self selector:@selector(audioRouteChanged:) name:AVAudioSessionRouteChangeNotification object:nil];
    //    if (checkError(AudioSessionAddPropertyListener(kAudioSessionProperty_AudioRouteChange,
    //                                                   LLLsessionPropertyListener,
    //                                                   (__bridge void*)(self)),
    //                   "Couldn't add audio session property listener"))
    //    {
    //        // just warning
    //    }
    
    [[AVAudioSession sharedInstance]addObserver:self forKeyPath:@"outputVolume" options:NSKeyValueObservingOptionNew context:nil];
    
    //    if (checkError(AudioSessionAddPropertyListener(kAudioSessionProperty_CurrentHardwareOutputVolume,
    //                                                   LLLsessionPropertyListener,
    //                                                   (__bridge void*)(self)),
    //                   "Couldn't add audio session property listener"))
    //    {
    //        // just warning
    //    }
    
    
#if !TARGET_IPHONE_SIMULATOR
    Float32 preferredBufferSize = 0.0232;
    if (checkError(AudioSessionSetProperty(kAudioSessionProperty_PreferredHardwareIOBufferDuration,
                                           sizeof(preferredBufferSize),
                                           &preferredBufferSize),
                   "Couldn't set the preferred buffer duration")) {
        
        // just warning
    }
#endif
    
    [[AVAudioSession sharedInstance]setActive:YES error:nil];
    //    if (checkError(AudioSessionSetActive(YES), "Couldn't activate the audio session")) {
    //        return NO;
    //    }
    
    [self checkSessionProperties];
    
    // ----- Audio Unit Setup -----
    
    // Describe the output unit.
    
    AudioComponentDescription desc = {0};
    desc.componentType = kAudioUnitType_Output;
    desc.componentSubType = kAudioUnitSubType_RemoteIO;
    desc.componentManufacturer = kAudioUnitManufacturer_Apple;
    
    // Get component
    AudioComponent component = AudioComponentFindNext(NULL, &desc);
    if (checkError(AudioComponentInstanceNew(component, &_audioUnit), "Couldn't create the output audio unit")) {
        return NO;
    }
    
    UInt32 size;
    
    // Check the output stream format
    size = sizeof(AudioStreamBasicDescription);
    if (checkError(AudioUnitGetProperty(_audioUnit, kAudioUnitProperty_StreamFormat, kAudioUnitScope_Input, 0, &_outputFormat, &size), "Couldn't get the hardware output stream format")) {
        return NO;
    }
    
    _outputFormat.mSampleRate = _samplingRate;
    if (checkError(AudioUnitSetProperty(_audioUnit,
                                        kAudioUnitProperty_StreamFormat,
                                        kAudioUnitScope_Input,
                                        0,
                                        &_outputFormat, size), "Couldn't set the hardware output stream format")) {
        // just warning
    }
    
    _numBytesPerSample = _outputFormat.mBitsPerChannel / 8;
    _numOutputChannels  = _outputFormat.mChannelsPerFrame;
    
    // Slap a render callback on the unit
    AURenderCallbackStruct callbackStruct;
    callbackStruct.inputProc = LLLRenderCallback;
    callbackStruct.inputProcRefCon = (__bridge void *)(self);
    
    if (checkError(AudioUnitSetProperty(_audioUnit,
                                        kAudioUnitProperty_SetRenderCallback,
                                        kAudioUnitScope_Input,
                                        0,
                                        &callbackStruct,
                                        sizeof(callbackStruct)),
                   "Couldn't set the render callback on the audio unit"))
        return NO;
    
    if (checkError(AudioUnitInitialize(_audioUnit),
                   "Couldn't initialize the audio unit"))
        return NO;
    
    return YES;
    
}

- (bool) checkSessionProperties
{
    [self checkAudioRoute];
    
    // Check the number of output channels.
    _numOutputChannels = [[AVAudioSession sharedInstance]outputNumberOfChannels];
    _samplingRate = [[AVAudioSession sharedInstance]sampleRate];
    _outputVolume = [[AVAudioSession sharedInstance]outputVolume];
    
    //    UInt32 size = sizeof(newNumChannels);
    
    //    if (checkError(AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareOutputNumberChannels,
    //                                           &size,
    //                                           &newNumChannels),
    //                   "Checking number of output channels"))
    //        return NO;
    
    //    LoggerAudio(2, @"We've got %lu output channels", newNumChannels);
    //
    //    // Get the hardware sampling rate. This is settable, but here we're only reading.
    //    size = sizeof(_samplingRate);
    //    if (checkError(AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareSampleRate,
    //                                           &size,
    //                                           &_samplingRate),
    //                   "Checking hardware sampling rate"))
    //
    //        return NO;
    //
    //    LoggerAudio(2, @"Current sampling rate: %f", _samplingRate);
    
    //    size = sizeof(_outputVolume);
    //    if (checkError(AudioSessionGetProperty(kAudioSessionProperty_CurrentHardwareOutputVolume,
    //                                           &size,
    //                                           &_outputVolume),
    //                   "Checking current hardware output volume"))
    //        return NO;
    //
    //    LoggerAudio(1, @"Current output volume: %f", _outputVolume);
    
    return YES;
}

- (bool) renderFrames: (UInt32) numFrames
               ioData: (AudioBufferList *) ioData
{
    //   1. 将buffer数组全部置为0；清理现场
    for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
        memset(ioData->mBuffers[iBuffer].mData, 0, ioData->mBuffers[iBuffer].mDataByteSize);
    }
    //    如果在播放，那么处理回调；
    if (_playing && _outputBlock ) {
        
        //        block回掉，获取需要render的data；
        _outputBlock(_outData, numFrames, _numOutputChannels);
        
        // Put the rendered data into the output buffer
        if (_numBytesPerSample == 4) // then we've already got floats
        {
            float zero = 0.0;
            
            for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
                
                int thisNumChannels = ioData->mBuffers[iBuffer].mNumberChannels;
                
                for (int iChannel = 0; iChannel < thisNumChannels; ++iChannel) {
                    vDSP_vsadd(_outData+iChannel, _numOutputChannels, &zero, (float *)ioData->mBuffers[iBuffer].mData, thisNumChannels, numFrames);
                }
            }
        }
        else if (_numBytesPerSample == 2) // then we need to convert SInt16 -> Float (and also scale)
        {
            //            dumpAudioSamples(@"Audio frames decoded by FFmpeg:\n",
            //                             _outData, @"% 12.4f ", numFrames, _numOutputChannels);
            
            float scale = (float)INT16_MAX;
            //            加速的，叠加算法；
            //        https://developer.apple.com/library/ios/documentation/Performance/Conceptual/vDSP_Programming_Guide/About_vDSP/About_vDSP.html#//apple_ref/doc/uid/TP40005147-CH201-SW1
            
            vDSP_vsmul(_outData, 1, &scale, _outData, 1, numFrames*_numOutputChannels);
            
#ifdef DUMP_AUDIO_DATA
            LoggerAudio(2, @"Buffer %u - Output Channels %u - Samples %u",
                        (uint)ioData->mNumberBuffers, (uint)ioData->mBuffers[0].mNumberChannels, (uint)numFrames);
#endif
            
            for (int iBuffer=0; iBuffer < ioData->mNumberBuffers; ++iBuffer) {
                
                int thisNumChannels = ioData->mBuffers[iBuffer].mNumberChannels;
                
                for (int iChannel = 0; iChannel < thisNumChannels; ++iChannel) {
                    vDSP_vfix16(_outData+iChannel, _numOutputChannels, (SInt16 *)ioData->mBuffers[iBuffer].mData+iChannel, thisNumChannels, numFrames);
                }
#ifdef DUMP_AUDIO_DATA
                dumpAudioSamples(@"Audio frames decoded by FFmpeg and reformatted:\n",
                                 ((SInt16 *)ioData->mBuffers[iBuffer].mData),
                                 @"% 8d ", numFrames, thisNumChannels);
#endif
            }
            
        }
    }
    
    return noErr;
}

#pragma mark - public

- (bool)activateAudioSession
{
    if(!_activated){
        
        ///TODO Interruption observer
        
        //        if (!_initialized) {
        //            if (checkError(AudioSessionInitialize(NULL,
        //                                                  kCFRunLoopDefaultMode,
        //                                                  LLLsessionInterruptionListener,
        //                                                  (__bridge void *)(self)),
        //                           "Couldn't initialize audio session")) {
        //                return NO;
        //            }
        //            _initialized = YES;
        //        }
        if ([self checkAudioRoute] && [self setupAudioSession]) {
            _activated = YES;
        }
    }
    return _activated;
}

- (void)deactivateAudioSession
{
    if (_activated) {
        
        [self pause];
        
        checkError(AudioUnitUninitialize(_audioUnit),
                   "Couldn't uninitialize the audio unit");
        /*
         fails with error (-10851) ?
         
         checkError(AudioUnitSetProperty(_audioUnit,
         kAudioUnitProperty_SetRenderCallback,
         kAudioUnitScope_Input,
         0,
         NULL,
         0),
         "Couldn't clear the render callback on the audio unit");
         */
        
        checkError(AudioComponentInstanceDispose(_audioUnit),
                   "Couldn't dispose the output audio unit");
        
        [[AVAudioSession sharedInstance]setActive:NO error:nil];
        
        //        checkError(AudioSessionSetActive(NO),"Couldn't deactivate the audio session");
        
        [[NSNotificationCenter defaultCenter]removeObserver:self];
        [[AVAudioSession sharedInstance] removeObserver:self forKeyPath:@"outputVolume"];
        //        checkError(AudioSessionRemovePropertyListenerWithUserData(kAudioSessionProperty_AudioRouteChange,
        //                                                                  LLLsessionPropertyListener,
        //                                                                  (__bridge void *)(self)),
        //                   "Couldn't remove audio session property listener");
        //
        //        checkError(AudioSessionRemovePropertyListenerWithUserData(kAudioSessionProperty_CurrentHardwareOutputVolume,
        //                                                                  LLLsessionPropertyListener,
        //                                                                  (__bridge void *)(self)),
        //                   "Couldn't remove audio session property listener");
        //
        _activated = NO;
        _initialized = NO;
    }
}

- (void) pause
{
    if (_playing) {
        
        _playing = checkError(AudioOutputUnitStop(_audioUnit),
                              "Couldn't stop the output unit");
    }
}

- (bool) play
{
    if (!_playing) {
        
        if ([self activateAudioSession]) {
            
            _playing = !checkError(AudioOutputUnitStart(_audioUnit),
                                   "Couldn't start the output unit");
        }
    }
    
    return _playing;
}


@end

@implementation MRAudioManager

+ (id<MRAudioManager>)audioManager
{
    static MRAudioManagerPrivateImp *audioManger = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        audioManger = [[MRAudioManagerPrivateImp alloc]init];
    });
    return audioManger;
}

@end

