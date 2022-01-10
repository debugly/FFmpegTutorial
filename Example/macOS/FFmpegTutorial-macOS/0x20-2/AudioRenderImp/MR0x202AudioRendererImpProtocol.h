//
//  MR0x202AudioRendererImpProtocol.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/9/26.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef UInt32(^MRFetchPacketSample)(uint8_t*buffer,UInt32 bufferSize);
typedef UInt32(^MRFetchPlanarSample)(uint8_t*left,UInt32 leftSize,uint8_t*right,UInt32 rightSize);

@protocol MR0x202AudioRendererImpProtocol <NSObject>

@required;
- (void)play;
- (void)pause;
- (void)stop;

@optional;
- (void)setup:(int)sampleRate isFloatFmt:(BOOL)isFloat;
- (void)setup:(int)sampleRate isFloatFmt:(BOOL)isFloat isPacket:(BOOL)isPacket;
- (void)onFetchPacketSample:(MRFetchPacketSample)block;
- (void)onFetchPlanarSample:(MRFetchPlanarSample)block;

@end

NS_ASSUME_NONNULL_END
