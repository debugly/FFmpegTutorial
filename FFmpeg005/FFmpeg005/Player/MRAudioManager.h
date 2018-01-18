//
//  MRAudioManager.h
//  HelloWorld
//
//  Created by xuqianlong on 15/5/22.
//  Copyright (c) 2015年 xuqianlong. All rights reserved.
//

#import <Foundation/Foundation.h>

typedef void(^MRAudioManagerOutputBlock)(float *data, UInt32 numFrames, UInt32 numChannels);

@protocol MRAudioManager <NSObject>

@property (nonatomic,readonly) UInt32   numOutputChannels;
@property (nonatomic,readonly) Float64  samplingRate;
@property (nonatomic,readonly) UInt32   numBytesPerSample;
@property (nonatomic,readonly) Float32  outputVolume;
@property (nonatomic,readonly) bool     playing;
@property (nonatomic,readonly,copy) NSString *audioRoute;

@property (nonatomic,copy) MRAudioManagerOutputBlock outputBlock;

//就绪音频Session；
- (bool) activateAudioSession;
- (void) deactivateAudioSession;
- (bool) play;
- (void) pause;

@end

@interface MRAudioManager : NSObject

+ (id<MRAudioManager>)audioManager;

@end
