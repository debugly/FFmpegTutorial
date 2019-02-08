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
@property (strong, nonatomic) NSData *samples;
@property (assign, nonatomic) NSUInteger offset;
///for planer
@property (strong, nonatomic) NSData *left;
@property (strong, nonatomic) NSData *right;
@property (assign, nonatomic) NSUInteger leftOffset;
@property (assign, nonatomic) NSUInteger rightOffset;

@end

NS_ASSUME_NONNULL_END
