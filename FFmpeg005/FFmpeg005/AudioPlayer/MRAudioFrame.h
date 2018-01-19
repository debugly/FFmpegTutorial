//
//  MRAudioFrame.h
//  FFmpeg005
//
//  Created by 许乾隆 on 2018/1/14.
//  Copyright © 2018年 Awesome FFmpeg Study Demo. All rights reserved.
//

#import <Foundation/Foundation.h>

@interface MRAudioFrame : NSObject

@property (readwrite, nonatomic) float position;
@property (readwrite, nonatomic) float duration;
@property (readwrite, nonatomic, strong) NSData *samples;

@end
