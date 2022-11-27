//
//  MRMetalViewController.h
//  FFmpegTutorial-macOS
//
//  Created by qianlongxu on 2022/11/22.
//  Copyright © 2022 Matt Reach's Awesome FFmpeg Tutotial. All rights reserved.
//
//使用 Metal 渲染 BGRA/NV12/NV21/YUV420P/UYVY422/YUYV422 视频桢
//在intel集成显卡上 YUV420P 视频桢显示异常，这是 metal 的bug

#import <Cocoa/Cocoa.h>

NS_ASSUME_NONNULL_BEGIN

@interface MRMetalViewController : NSViewController

@end

NS_ASSUME_NONNULL_END
