
![](md/imgs/MR-16-9.png)[![](md/imgs/ffmpeg.png)](http://ffmpeg.org/) 


> 我对 **FFmpeg** 充满了兴趣，因此会抽时间出来找些相关资料自己学习下，最终的目标是凭借一己之力封装出一个 **跨平台播放器**。

# Foreword

该工程是笔者 2017 年创建的，当时的打算是前几个 demo 使用 2.x 版本的 FFmepg，然后替换成 3.x 版本以此来熟悉 FFmpeg 的 API 。

但是 3 年过去了，我的目标还没实现😅😅😅说来惭愧，毕竟现在是 2020 年了，研究 2.x 版本没有实际意义了，所以 demo 将改为 3.x -> 4.x 版本。

2020 年工程将不再使用 xcconfig 配置 FFmpeg 路径，改用制作 Pod 库的，使用 CocoaPod 来管理，这样更加方便。

制作好的 FFmpeg Pod 库放在这里 [MRFFToolChainPod](https://github.com/debugly/MRFFToolChainPod) ，简单的说就是为编译好的静态库编写了配套的 podspec 文件，感兴趣的话可以看下。

如果您对如何编译 FFmpeg 工具库感兴趣，可移步这里 [MRFFToolChainBuildShell](https://github.com/debugly/MRFFToolChainBuildShell) 查看具体的编译脚本。


# Matt Reach's Awesome FFmpeg Study Demo

- 第 〇 天：[编译 iOS 平台的 FFmpeg 库，简单了解在 Mac 平台如何使用](md/000.md) √

- 第 ① 天：[查看编译 config，支持的协议](md/001.md) √

- 第 ② 天：[查看音视频流信息](md/002.md) √

- 第 ③ 天：[打造播放器核心驱动](md/003.md) √ 

- 第 ④ 天：[将 avframe 转成 UIImage，使用 UIImageView 渲染](md/004.md) √

- 第 ⑤ 天：[将 avframe 转成 CIImage，使用 GLKView 渲染](md/005.md) √

- 第 ⑥ 天：[将 avframe 转成 CMSampleBufferRef，使用 AVSampleBufferDisplayLayer 渲染，60fps](md/006.md) √

- 第 ⑦ 天：[使用 AudioUnit 渲染音频](md/007.md) √

- 第 ⑧ 天：[使用 AudioQueue 渲染音频](md/008.md) √

- 第 ⑨ 天：[将 FFmpeg 升级到 3.x 版本](md/009.md)

后面没打勾是指对应的博客文档还没写好，demo是OK的。

# Learning plan

- 第 ⑩ 天：[将音视频同步，为封装播放器做准备](md/010.md)
- 第 ⑪ 天：[封装 MRMoviePlayer 播放器](md/011.md)

### Cross-platform

- [使用 MetalKit 渲染视频]()
- [使用 VideoToolbox 硬件解码H264]()
- [移植到 Mac 平台](md/012.md)
- [使用 OpenGL 渲染视频](md/013.md)
- [使用 OpenAL 渲染音频](md/014.md)
- [移植到 Win 平台](md/016.md)

# Fun learning

- 第 ⑥-① 天：[黑白电视机雪花屏、灰色色阶图](md/006-1.md) √

# Usage

克隆该仓库之后，项目并不能运行起来，因为项目依赖的 FFmpeg 库还没有下载下来，需要执行

**pod install**

```
----------------------------------------
Target:FFmpeg001 will use FFmpeg:3.4.7
----------------
Target:FFmpeg002 will use FFmpeg:3.4.7
----------------
Target:FFmpeg003 will use FFmpeg:3.4.7
----------------
Target:FFmpeg004 will use FFmpeg:3.4.7
----------------
Target:FFmpeg005 will use FFmpeg:3.4.7
----------------
Target:FFmpeg006 will use FFmpeg:3.4.7
----------------
Target:FFmpeg006-1 will use FFmpeg:3.4.7
----------------
Target:FFmpeg007 will use FFmpeg:3.4.7
----------------
Target:FFmpeg008 will use FFmpeg:3.4.7
----------------
Target:FFmpeg009 will use FFmpeg:3.4.7
----------------------------------------
Analyzing dependencies
Downloading dependencies
Generating Pods project
Integrating client projects
Pod installation complete! There is 1 dependency from the Podfile and 1 total pod installed.
```

成功后就可以打开 **StudyFFmpeg.xcworkspace** 运行了，支持模拟器和真机！

## Ends

Good Luck！Welcome give me an issue or a star or pull request！

Thank you！