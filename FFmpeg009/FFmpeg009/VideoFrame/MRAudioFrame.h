//
//  MRAudioFrame.h
//  FFmpeg007
//
//  Created by 许乾隆 on 2019/1/25.
//  Copyright © 2019 Awesome FFmpeg Study Demo. All rights reserved.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@interface MRAudioFrame : NSObject

@property (assign, nonatomic) float position;
@property (assign, nonatomic) float duration;
///for packet
@property (strong, nonatomic) NSData *samples4packet;
@property (assign, nonatomic) NSUInteger samplesOffset;
///for planar
@property (strong, nonatomic) NSData *leftPlanar;
@property (strong, nonatomic) NSData *rightPlanar;
@property (assign, nonatomic) NSUInteger leftOffset;
@property (assign, nonatomic) NSUInteger rightOffset;

@end

NS_ASSUME_NONNULL_END
