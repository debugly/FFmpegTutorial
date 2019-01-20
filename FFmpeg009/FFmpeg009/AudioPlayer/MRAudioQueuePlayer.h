//
//  MRAudioQueuePlayer.h
//  FFmpeg009
//
//  Created by 许乾隆 on 2018/2/22.
//  Copyright © 2018年 Awesome FFmpeg Study Demo. All rights reserved.
//  开源地址: https://github.com/debugly/StudyFFmpeg

#import <Foundation/Foundation.h>

@interface MRAudioQueuePlayer : NSObject

- (void)playURLString:(NSString *)url;
- (void)stop;

@end
