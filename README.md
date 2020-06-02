
![](md/imgs/MR-16-9.png)[![](md/imgs/ffmpeg.png)](http://ffmpeg.org/) 


> 我对 **FFmpeg** 充满了兴趣，因此会抽时间出来找些相关资料学习下，最终的目标是封装出一个 **跨平台播放器**。

# Foreword

本工程是笔者 2017 年创建的，当时的目的是为了消化下 kxmovie 的源码，将封装好的代码给他精简下，比葫芦画瓢自己写一边，前几个 demo 使用 2.x 版本的 FFmepg，然后替换成 3.x 版本以此来熟悉 FFmpeg 的 API。

谁曾想 3 年过去了，我的目标还差很远，虽然研究出了音视频的渲染但离目标还差得远，考虑到现在是 2020 年了，研究 2.x 版本没有实际意义了，因此本系列教程将会先使用 3.x 版本，然后升级到 4.x 版本。

从 2020 年开始本工程将不再使用 xcconfig 配置 FFmpeg 路径，取而代之的是使用 CocoaPod 来集成，工程管理上更加方便也更加现代化，避免在工程配置方面浪费时间。

我已经把编译好的 FFmpeg 库制作成了 MRFFmpegPod 库，这个库是 [MRFFToolChainPod](https://github.com/debugly/MRFFToolChainPod) 的组成部分，后续会根据需要增加更多的库。简单的说就是为编译好的静态库编写了配套的 podspec 文件，感兴趣的话可以去看下。如果您对如何编译 FFmpeg 工具库感兴趣，可移步这里 [MRFFToolChainBuildShell](https://github.com/debugly/MRFFToolChainBuildShell) 查看具体的编译脚本。

工程完全采用 Pod lib 的形式开发，也就是说我会把所有的封装代码都放在 FFmpegTutorial 这个 Pod 库里，该库依赖了 MRFFmpegPod 库，相应的配套 Demo 工程放在 Example 文件夹里，光 Pod 库就用了两个呢，所以学习本教程一点都不吃亏，即使对 FFmpeg 教程本身不感兴趣，也可以学习下如何去制作 Pod 库，如何开发 Pod 库的一些相关技巧，在开发实际项目时是很实用的（我负责的项目完全都是用 Pod 库管理的，其中有一半都是 Development Pods，另一半则是编译好的 Pod Binary）。



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
- 0x06:   [整理代码，封装解码器](md/0x06.md)

# TODO

**为了提升代码质量，决定重新编写教程，因此以下为 TODO List！**

**为了提升代码质量，决定重新编写教程，因此以下为 TODO List！**

**为了提升代码质量，决定重新编写教程，因此以下为 TODO List！**

**之前的老代码实现了音视频的不同渲染方式，可以通过 git 将代码切到这次 36e4f8cdcf1f9a293426dea802a39560747fdeec 提交进行查看**


- 0x07：[将 avframe 转成 UIImage，使用 UIImageView 渲染]

- 0x08：[将 avframe 转成 CIImage，使用 GLKView 渲染]

- 0x09：[将 avframe 转成 CMSampleBufferRef，使用 AVSampleBufferDisplayLayer 渲染，60fps]

- 0x10：[使用 AudioUnit 渲染音频]

- 0x11：[使用 AudioQueue 渲染音频]

- 0x12：[将音视频同步，为封装播放器做准备]

- 0x13：[封装 MRMoviePlayer 播放器]

### Just For Fun

- 0xF0：[黑白电视机雪花屏、灰色色阶图] 

### Cross-platform

本教程的终极目标是写一款 **跨平台播放器**，理想很丰满，显示很骨感，这是一项庞大的工程，我会分阶段来实现。

第一阶段：先完成一款 iOS 平台的播放，因为我本人是做 iOS 开发，这个平台是我最熟悉的平台了，因为没写过播放器，所以这个阶段的代码不是很成熟，前期改动可能会多些，以弥补思考不严密与规划不正确带来的问题。从长远来讲为了实现跨平台，不应当使用 Cocoa 特有的技术，比如 NSThread，GCD等，这完全是给自己挖坑😂！但是为了照顾广大 iOS 开发者零基础入门，我还是放弃了 C++ Thread 或  pthread 等实现方式，从而降低学习的门槛，让大家不用去学那么多乱七八糟的东西。

第二阶段：移植到 macOS 平台，这一阶段需要对平台不兼容接口进行处理，主要是视频渲染方面的，另外需要考虑后续的移植问题，设计出优良的方便移植的接口。移植完毕后考虑学习下使用 MetalKit 渲染，和 VideoToolbox 硬解等。

第三阶段：移植到 Android 平台，这个阶段的主要问题是将第一阶段使用的平台相关的 API 替换成跨平台的，主要包括线程和锁，还要学习 JNI 调用，音视频如何渲染，demo 工程怎么管理依赖有没有 cocoapods 一样的工具可用？

第四阶段：移植到 windows 平台，因为好多年没有使用 Windows 系统了，所以这个可能是当前最没兴趣的了，还有余力的话，可以搞搞。

# Usage

克隆该仓库之后，项目并不能运行起来，因为项目依赖的 MRFFmpegPod 库还没有下载下来，需要执行

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

由于 Github 在国内不稳定，pod install 的过程需要将几十兆的 FFmpeg 库下载下来，~~安装过程中如有失败属于正常现象，请多次几次，或者通过配置 HOST，翻墙等办法解决~~,最新代码版本不再从 github 下载，放到了测试机上，安装速度非常快！

## Ends

- Please give me an issue or a star or pull request！
- New members are always welcome!

Good Luck,Thank you！
