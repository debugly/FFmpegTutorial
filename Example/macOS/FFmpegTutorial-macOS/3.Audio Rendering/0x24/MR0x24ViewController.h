//
//  MR0x24ViewController.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/7/14.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//
// 0x20:封装音频重采样类，方便转出指定的采样格式
// 0x21:使用 AudioUnit 渲染音频桢，解码速度慢，渲染速度快，因此声音断断续续的
// 0x22:增加Frame缓存队列，解决断断续续问题
// 0x23:使用 AudioQueue 渲染音频桢
// 0x24:抽取 AudioRenderer 类，封装底层音频渲染逻辑

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MR0x24ViewController : NSViewController

@end

NS_ASSUME_NONNULL_END
