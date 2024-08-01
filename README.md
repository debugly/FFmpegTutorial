[![](md/imgs/ffmpeg.png)](https://ffmpeg.org/) 

> 帮助零基础的 iOS/macOS 开发人员快速学习音视频技术，主要包括了 FFmpeg API 的使用，以及 iOS/macOS 平台多种音视频渲染技术的对比。 
> 
> 感觉有用的话给个 Star 吧😊

[![Stargazers repo roster for @debugly/FFmpegTutorial](https://reporoster.com/stars/debugly/FFmpegTutorial)](https://github.com/debugly/FFmpegTutorial/stargazers)

# Usage

## iOS 示例工程:

```bash
git clone https://github.com/debugly/FFmpegTutorial.git
cd FFmpegTutorial/Example/iOS
pod install
open FFmpegTutorial-iOS.xcworkspace
```

运行效果:

![](md/imgs/ios-snapshot-1.png)

![](md/imgs/ios-snapshot-2.png)

## macOS 示例工程:

```bash
git clone https://github.com/debugly/FFmpegTutorial.git
cd FFmpegTutorial/Example/macOS
pod install
open FFmpegTutorial-macOS.xcworkspace
```

![](md/imgs/macos-snapshot-1.png)

![](md/imgs/macos-snapshot-2.png)

![](md/imgs/macos-snapshot-3.png)

## Introduction

为方便管理依赖，项目使用 Pod 开发库（Development Pod）的形式来组织，所有对 FFmpeg 的封装代码都放在 FFmpegTutorial 库里，如何编译 FFmpeg 不是本教程的重点，在 pod install 时会自动下载已经预编译好的 FFmpeg 库，编译 FFmpeg 的脚本也是开源的 [[MRFFToolChainBuildShell](https://github.com/debugly/MRFFToolChainBuildShell)]([debugly/MRFFToolChainBuildShell: use github action auto compile FFmpeg libs. (使用 github action 自动预编译 FFmpeg 等库，跟 ijkplayer 配套使用。)](https://github.com/debugly/MRFFToolChainBuildShell))。

教程共分为六个部分，提供了 iOS 和 macOS 的上层调用示例，使用 Objective-C 语言开发:

一、音视频基础

- OpenGL Version:查看编译时配置信息、支持的协议、版本号;OpengGL信息
- Custom Thread:封装 NSThread，方便后续调用
- Movie Prober:查看音视频流信息
- Read Packet:读取音视频包
- Decode Packet:音视频解码
- Custom Decoder:抽取解码类，封装解码逻辑

二、视频渲染

- Core API:使用 Core Graphics/Core Image/Core Media 渲染视频帧
- Legacy OpenGL/OpenGL ES2:渲染 BGRA/NV12/NV21/YUV420P/UYVY/YUYV 视频桢
- Modern OpenGL/OpenGL ES3:渲染 BGRA/NV12/NV21/YUV420P/UYVY/YUYV 视频桢
- Modern OpenGL(Rectangle Texture):渲染 BGRA/NV12/NV21/YUV420P/UYVY/YUYV 视频桢
- Metal:渲染 BGRA/NV12/NV21/YUV420P/UYVY/YUYV 视频桢

三、音频渲染

- AudioUnit:支持 S16,S16P,Float,FloatP 格式，采样率支持 44.1K,48K,96K,192K
- AudioQueue:支持 S16,Float格式，采样率支持 44.1K,48K,96K,192K
- 封装 AudioUnit 和 AudioQueue 渲染逻辑，调用者无需感知

四、封装播放器

- VideoFrameQueue:增加 VideoFrame 缓存队列，不再阻塞解码线程
- PacketQueue:增加 AVPacket 缓存队列，创建解码线程
- VideoRendering Embed:创建视频渲染线程，将视频相关逻辑封装到播放器内
- AudioRendering Embed:将音频相关逻辑封装到播放器内
- Show Play Progress:显示音视频播放进度
- Sync Audio And Video:音视频同步

五、趣味实验

- 黑白电视机雪花屏、灰色色阶图、三个小球

六、实用工具

- 高效视频抽帧器:[MRVideoToPicture](https://github.com/debugly/MRVideoToPicture)

## Cross-Platform

本教程相对于商用播放器存在很大差距，仅仅用来科普FFmpeg和Apple平台的音视频渲染技术。

如果对播放器感兴趣，可以了解下我移植到的跨平台 [ijkplayer](https://github.com/debugly/ijkplayer) ，增加了字幕、视频旋转、Metal 渲染、HDR等功能！

## Donate

编写这个教程，花费了七年的时间，期间工程重构了三次，不记得熬了多少个夜晚去死磕遇到的问题...

希望这些教程能够为新人学习音视频渲染提供上帮助，请买杯咖啡给我提提神儿。

![donate.jpg](https://i.postimg.cc/xdVqnBLp/IMG-7481.jpg)
