//
//  MRAudioPlayer.h
//  FFmpeg008
//
//  Created by Matt Reach on 2018/2/21.
//  Copyright © 2018年 Awesome FFmpeg Study Demo. All rights reserved.
//  开源地址: https://github.com/debugly/StudyFFmpeg
//

#import <Foundation/Foundation.h>

@interface MRAudioPlayer : NSObject

- (void)playURLString:(NSString *)url;
- (void)stop;

@end
