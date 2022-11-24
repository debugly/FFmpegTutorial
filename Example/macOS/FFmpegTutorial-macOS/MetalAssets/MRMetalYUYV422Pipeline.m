//
//  MRMetalYUYV422Pipeline.m
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/11/24.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//

#import "MRMetalYUYV422Pipeline.h"

@implementation MRMetalYUYV422Pipeline

+ (MTLPixelFormat)_MTLPixelFormat
{
    return MTLPixelFormatGBGR422;
}

@end
