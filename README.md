
![](md/imgs/MR-16-9.png)[![](md/imgs/ffmpeg.png)](http://ffmpeg.org/) 


> 我对 **FFmpeg** 充满了兴趣，因此会抽时间出来找些相关资料自己学习下，最终的目标是凭借一己之力封装出一个 **跨平台播放器**。

# Foreword

该工程是笔者 2017 年创建的，当时的打算是前几个 demo 使用 2.x 版本的 FFmepg，然后替换成 3.x 版本以此来熟悉 FFmpeg 的 API。

但是 3 年过去了，我的目标还没实现😅😅😅说来惭愧，毕竟现在是 2020 年了，研究 2.x 版本没有实际意义了，因此该教程将会先使用 3.x 版本，然后升级到 4.x 版本。

2020 年开始工程将不再使用 xcconfig 配置 FFmpeg 路径，取而代之的是使用 CocoaPod 来集成，这样做更加方便也更加现代化，减少在工程配置方面浪费不必要的时间。

制作好的 MRFFmpegPod 库放在这里 [MRFFToolChainPod](https://github.com/debugly/MRFFToolChainPod) ，简单的说就是为编译好的静态库编写了配套的 podspec 文件，感兴趣的话可以看下。如果您对如何编译 FFmpeg 工具库感兴趣，可移步这里 [MRFFToolChainBuildShell](https://github.com/debugly/MRFFToolChainBuildShell) 查看具体的编译脚本。

工程完全采用 Pod 库的形式，也就是说我会把所有的封装代码都放在 FFmpegTutorial 这个 Pod 库里，该库依赖了 MRFFmpegPod 库，相应的配套 Demo 工程放在 Example 文件夹里，光 Pod 库就用了两个呢，所以学习本教程一点都不吃亏，即使对 FFmpeg 教程本身不感兴趣，也可以学习下如何去制作 Pod 库，如何开发 Pod 库的一些相关技巧哈，这个在实际项目中是很实用的（我负责的公司项目完全都是用 Pod 库管理的，其中有一半都是 Development Pods）。

# Matt Reach's Awesome FFmpeg Tutorial

- 0x00：[FFmpeg简介及编译方法](md/0x00.md) 
- 0x01：[查看编译时配置信息、支持的协议、版本号](md/0x01.md)
- 0x02：[查看视频流基础信息](md/0x02.md)

# Anti-Illiteracy

- 0x01：[常见封装格式介绍](md/illiteracy/0x01.md)

# TODO

**为了提升代码质量，决定重新编写教程，因此以下为 TODO List！**

**为了提升代码质量，决定重新编写教程，因此以下为 TODO List！**

**为了提升代码质量，决定重新编写教程，因此以下为 TODO List！**

**如果想看之前的代码可以通过 git 切到 old 分支即可！**

- 0x03：[打造播放器核心驱动]

- 0x04：[将 avframe 转成 UIImage，使用 UIImageView 渲染]

- 0x05：[将 avframe 转成 CIImage，使用 GLKView 渲染]

- 0x06：[将 avframe 转成 CMSampleBufferRef，使用 AVSampleBufferDisplayLayer 渲染，60fps]

- 0x07：[使用 AudioUnit 渲染音频]

- 0x08：[使用 AudioQueue 渲染音频]

- 0x09：[将 FFmpeg 升级到 3.x 版本]

- 0x10：[将音视频同步，为封装播放器做准备]

- 0x11：[封装 MRMoviePlayer 播放器]

### Cross-platform

本教程的终极目标是写一款**跨平台播放器**，理想很丰满，显示很骨感，这是一项庞大的工程，我会分阶段来实现。

第一阶段：先完成一款 iOS 平台的播放，因为我本人是做 iOS 开发，这个平台是我最熟悉的平台了，因为没写过播放器，所以这个阶段的代码不是很成熟，前期改动可能会多些，以弥补思考不严密与规划不正确带来的问题。

第二阶段：移植到 macOS 平台，这一阶段需要对平台不兼容接口进行处理，主要是视频渲染方面的，另外需要考虑后续的移植问题，设计出优良的方便移植的接口。移植完毕后考虑使用 MetalKit 渲染，和 VideoToolbox 硬解。

第三阶段：移植到 Android 平台，有了移植的经验，这个阶段的主要问题是研究 JNI，音视频如何渲染，demo工程怎么管理依赖有没有 cocoapods 一样的工具？（我没做过相关开发）

第四阶段：移植到 windows 平台，因为好多年没有使用 Windows 系统了，所以这个可能是当前最没兴趣的了，还有余力的话，可以搞搞。

# Just For Fun

- 0xF0：[黑白电视机雪花屏、灰色色阶图](md/006-1.md) √

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
