//
//  MR0x32AudioRendererImpProtocol.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/9/26.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Foundation/Foundation.h>
#import <FFmpegTutorial/FFTPlayerHeader.h>

NS_ASSUME_NONNULL_BEGIN
typedef UInt32(^MRFetchSamples)(uint8_t* _Nonnull buffer[_Nullable 2],UInt32 bufferSize);

@protocol MR0x32AudioRendererImpProtocol <NSObject>

@required;
- (NSString *)name;
- (void)play;
- (void)pause;
- (void)stop;
- (void)setupAudioRender:(MRSampleFormat)fmt sampleRate:(Float64)sampleRate;
- (void)onFetchSamples:(MRFetchSamples)block;;

@end
NS_ASSUME_NONNULL_END
