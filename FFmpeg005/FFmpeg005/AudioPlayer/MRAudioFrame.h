//
//  MRAudioFrame.h
//  FFmpeg005
//
//  Created by Matt Reach on 2017/12/21.
//  Copyright © 2018年 Awesome FFmpeg Study Demo. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MRAudioFrame : NSObject

@property (readwrite, nonatomic) float position;
@property (readwrite, nonatomic) float duration;
@property (readwrite, nonatomic, strong) NSData *samples;

@end
