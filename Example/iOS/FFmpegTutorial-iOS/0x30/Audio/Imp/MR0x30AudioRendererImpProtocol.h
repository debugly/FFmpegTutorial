//
//  MR0x30AudioRendererImpProtocol.h
//  FFmpegTutorial-iOS
//
//  Created by Matt Reach on 2020/7/17.
//  Copyright © 2020 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef UInt32(^MRFetchPacketSample)(uint8_t*buffer,UInt32 bufferSize);
typedef UInt32(^MRFetchPlanarSample)(uint8_t*left,UInt32 leftSize,uint8_t*right,UInt32 rightSize);

@protocol MR0x30AudioRendererImpProtocol <NSObject>

@required;
- (void)play;

@optional;
- (void)setup:(int)sampleRate isFloatFmt:(BOOL)isFloat;
- (void)setup:(int)sampleRate isFloatFmt:(BOOL)isFloat isPacket:(BOOL)isPacket;
- (void)onFetchPacketSample:(MRFetchPacketSample)block;
- (void)onFetchPlanarSample:(MRFetchPlanarSample)block;

@end

NS_ASSUME_NONNULL_END
