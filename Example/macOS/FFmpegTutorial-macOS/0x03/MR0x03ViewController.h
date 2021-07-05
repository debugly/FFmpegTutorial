//
//  MR0x03ViewController.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2021/4/15.
//  Copyright © 2021 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//
// 读包模块设计；独立线程，读到之后放入一个缓存区中，供解码线程消耗；

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MR0x03ViewController : NSViewController

@end

NS_ASSUME_NONNULL_END
