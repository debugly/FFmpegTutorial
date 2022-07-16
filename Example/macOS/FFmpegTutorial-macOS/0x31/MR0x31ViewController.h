//
//  MR0x31ViewController.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/7/16.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//
// 0x03:查看音视频流信息
// 0x04:创建读包线程，读取音视频包
// 0x05:音视频解码
// 0x06:创建解码器类
// 0x10:创建视频缩放类
// 0x11:使用 Core Graphics 渲染视频桢
// 0x12:使用 Core Animation 渲染视频桢
// 0x13:使用 Core Media 渲染视频桢
// 0x14:使用 OpenGL 渲染 NV12 视频桢
// 0x141:抽取 OpenGLCompiler 类，封装 OpenGL Shader 相关逻辑
// 0x142:使用 OpenGL 渲染 YUV420P 视频桢
// 0x143:使用 OpenGL 渲染 UYVY422 视频桢
// 0x144:使用 OpenGL 渲染 YUYV422 视频桢
// 0x145:使用 OpenGL 渲染 NV21 视频桢
// 0x151:使用 OpenGL 3 渲染 NV12 视频桢
// 0x152:使用 OpenGL 3 渲染 YUV420P 视频桢
// 0x153:使用 OpenGL 3 渲染 UYVY422 视频桢
// 0x154:使用 OpenGL 3 渲染 YUYV422 视频桢
// 0x155:使用 OpenGL 3 渲染 NV21 视频桢
// 0x16:使用 OpenGL 3 FBO 截图
// 0x20:封装音频重采样类，方便转出指定的采样格式
// 0x21:使用 AudioUnit 渲染音频桢，解码速度慢，渲染速度快，因此声音断断续续的
// 0x22:增加Frame缓存队列，解决断断续续问题
// 0x23:使用 AudioQueue 渲染音频桢
// 0x24:抽取 AudioRenderer 类，封装底层音频渲染逻辑
// 0x30:增加 VideoFrame 缓存队列，不再阻塞解码线程
// 0x31:增加 AVPacket 缓存队列，创建解码线程

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MR0x31ViewController : NSViewController

@end

NS_ASSUME_NONNULL_END
