//
//  MR0x22AudioRendererImpProtocol.h
//  FFmpegTutorial-iOS
//
//  Created by Matt Reach on 2020/7/17.
//  Copyright © 2020 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef UInt32(^MRFetchPacketSample)(uint8_t*buffer,UInt32 bufferSize);

@protocol MR0x22AudioRendererImpProtocol <NSObject>

@required;
- (void)setup:(int)sampleRate isFloatFmt:(BOOL)isFloat;
- (void)onFetchPacketSample:(MRFetchPacketSample)block;
- (void)play;

@end

NS_ASSUME_NONNULL_END
