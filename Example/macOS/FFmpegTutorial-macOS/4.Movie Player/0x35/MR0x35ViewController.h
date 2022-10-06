//
//  MR0x35ViewController.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/7/25.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//
// 0x30:增加 VideoFrame 缓存队列，不再阻塞解码线程
// 0x31:增加 AVPacket 缓存队列，创建解码线程
// 0x32:创建视频渲染线程，将视频相关逻辑封装到播放器内
// 0x33:将音频相关逻辑封装到播放器内
// 0x34:显示音视频播放进度
// 0x35:音视频同步
// 0x36:开始，结束，暂停，续播
// 0x37:(TODO)使用硬件加速解码
// 0x38:(TODO)使用将硬件解码数据快速上传至矩形纹理，避免拷贝解码数据
// 0x39:(TODO)两种方式将软解解码数据格式封装成 CVPixelBuffer
// 0x3a:(TODO)统一软硬解渲染逻辑
// 0x3b:(TODO)支持 Seek
// 0x3c:(TODO)支持从指定位置处播放

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MR0x35ViewController : NSViewController

@end

NS_ASSUME_NONNULL_END
