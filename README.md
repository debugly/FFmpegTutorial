[![](md/imgs/ffmpeg.png)](http://ffmpeg.org/) 


> 从我个人的经验来看使用 **FFmpeg** 封装一个播放器，是有一定门槛的，为了让更多零基础的 iOS/macOS 开发人员快速入门，我编写了这个的教程。

# Foreword

本工程是笔者 2017 年创建的，原本是想把 kxmovie 的源码比葫芦画瓢自己写一边，前几个 demo 使用 2.x 版本的 FFmepg，然后替换成 3.x 版本以此来熟悉 FFmpeg 的 API，了解播放器内部实现的细节，后续萌生了自己封装播放器的想法...

3 年过去了，我仅仅摸索出了音视频的渲染而已，离目标相差很远，决定 2020 年重启该项目，并且使用 3.x 版本，等 iOS 版本的播放器完成后，专门写一篇如何升级到 4.x 版本的教程。工程采用 Pod 开发库（Development Pod）的形式来组织，所有的封装代码都放在 FFmpegTutorial 里，该开发库依赖了 [MRFFmpegPod](https://github.com/debugly/MRFFToolChainPod) 库。

工程目录结构如下：

```
├── Example
│   └── iOS //iOS 配套demo
│       ├── FFmpegTutorial-iOS
│       ├── FFmpegTutorial-iOS.xcodeproj
│       ├── FFmpegTutorial-iOS.xcworkspace
│       ├── Podfile
│       ├── Podfile.lock
│       ├── Pods
│       └── Tests
├── FFmpegTutorial // demo 工程依赖了这个 Development Pod
│   ├── Assets
│   └── Classes
│       ├── 0x01  //具体教程源码
│       ├── 0x02
│       ├── 0x03
│       ├── 0x04
│       ├── 0x05
│       ├── 0x06
│       ├── 0x07
│       ...
│       └── common //通用类
├── FFmpegTutorial.podspec
├── LICENSE
├── README.md
└── md
		├── 0x00.md //教程配套文档
    ├── 0x01.md
    ├── 0x02.md
    ├── 0x03.md
    ...

```



# Anti-Illiteracy

- 0x01：[常见封装格式介绍](md/illiteracy/0x01.md)
- 0x02：[播放器总体架构设计](md/illiteracy/0x02.md)
- 0x03：[封装 NSThread，支持 join](md/illiteracy/0x03.md)

# Tutorial

- 0x00：[FFmpeg简介及编译方法](md/0x00.md) 
- 0x01：[查看编译时配置信息、支持的协议、版本号](md/0x01.md)
- 0x02：[查看音视频码流基础信息](md/0x02.md)
- 0x03：[读包线程与 AVPacket 缓存队列](md/0x03.md)
- 0x04：[多线程解码](md/0x04.md)
- 0x05：[渲染线程与 AVFrame 缓存队列](md/0x05.md)
- 0x06：[整理代码，封装解码器](md/0x06.md)
- 0x07：[使用 UIImageView 渲染视频帧](md/0x07.md)

# TODO

**为了提升代码质量，决定重新编写教程，下面是 TODO List！**

**为了提升代码质量，决定重新编写教程，下面是 TODO List！**

**为了提升代码质量，决定重新编写教程，下面是 TODO List！**

**之前的老代码实现了音视频的不同渲染方式，可以通过 git 将代码切到这次 36e4f8cdcf1f9a293426dea802a39560747fdeec 提交进行查看**


- 0x08：[将 avframe 转成 CIImage，使用 GLKView 渲染]

- 0x09：[将 avframe 转成 CMSampleBufferRef，使用 AVSampleBufferDisplayLayer 渲染，60fps]

- 0x10：[使用 AudioUnit 渲染音频]

- 0x11：[使用 AudioQueue 渲染音频]

- 0x12：[将音视频同步，为封装播放器做准备]

- 0x13：[封装 MRMoviePlayer 播放器]

### Just For Fun

- 0xF0：[黑白电视机雪花屏、灰色色阶图] 

### Cross-platform

本教程的终极目标是写一款 **跨平台播放器**，理想很丰满，现实很骨感，这是一项庞大的工程，我会分阶段来完成，计划如下：

第一阶段：先完成一款 iOS 平台的播放，我本人做 iOS 开发多年，这个平台最为熟悉，由于没写过播放器，因此代码可能不是很成熟，前期改动可能会多些，以弥补思考不严密与规划不正确带来的问题。从长远来讲为了实现跨平台，不应当使用 Cocoa 特有的技术，比如 NSThread，GCD等，这完全是给自己挖坑😂！但是为了照顾广大 iOS 开发者零基础入门，我还是放弃了 C++ Thread 或  pthread 等实现方式，从而降低学习的门槛，让大家不用去学那么多乱七八糟的东西。

第二阶段：移植到 macOS 平台，这一阶段需要对平台不兼容接口进行处理，主要是视频渲染方面的，另外需要考虑后续的移植问题，设计出优良的方便移植的接口。移植完毕后考虑学习下使用 MetalKit 渲染，和 VideoToolbox 硬解等。

第三阶段：移植到 Android 平台，这个阶段的主要问题是将前两个阶段使用的 Cocoa API 替换成跨平台 API，主要包括线程和锁，还要学习 JNI 调用，音视频如何渲染，重新创建配套的 Demo 工程，学习如何管理依赖（有没有 cocoapods 一样的工具呢？）...

第四阶段：移植到 windows 平台，好多年没有使用 Windows 系统了，没有太大的兴趣，所以要看有没有跟多的精力了。

# Usage

克隆该仓库之后，项目并不能运行起来，因为项目依赖的 [MRFFmpegPod](https://github.com/debugly/MRFFToolChainPod) 库还没有下载下来，需要执行

**pod install --project-directory=Example/iOS**

```bash
➜  StudyFFmpeg git:(03) ✗ pod install --project-directory=Example/iOS
will install MRFFmpeg3.4.7
Analyzing dependencies
Downloading dependencies
Generating Pods project
Integrating client project
Pod installation complete! There are 2 dependencies from the Podfile and 2 total pods installed.
```

成功安装后就可以打开 **Example/iOS/FFmpegTutorial-iOS.xcworkspace** 运行了，支持模拟器和真机！

由于 Github 在国内不稳定，pod install 的过程需要将几十兆的 FFmpeg 库下载下来，~~安装过程中如有失败属于正常现象，请多次几次，或者通过配置 HOST，翻墙等办法解决~~,最新代码已经不再从 github 下载，放到了测试机上，安装速度非常快！

## Ends

- Please give me an issue or a star or pull request！
- New members are always welcome!

Good Luck,Thank you！
