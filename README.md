
![](md/imgs/MR-16-9.png)[![](md/imgs/ffmpeg.png)](http://ffmpeg.org/) 


> 我对 FFmpeg 充满了兴趣，因此抽时间找些资料自己学习下，最终目标是自己能够封装出一个 iOS 版的播放器。

# Matt Reach's Awesome FFmpeg Study Demo

- 第 〇 天：[编译 FFmpeg，简单了解在 Mac 平台如何使用](md/000.md) √

- 第 ① 天：[查看编译 config，支持的协议](md/001.md) √

- 第 ② 天：[查看音视频流信息](md/002.md) √

- 第 ③ 天：[打造播放器核心驱动](md/003.md) √ 

- 第 ④ 天：[将 avframe 转成 UIImage，使用 UIImageView 渲染](md/004.md) √

- 第 ⑤ 天：[将 avframe 转成 CIImage，使用 GLKView 渲染](md/005.md) √

- 第 ⑥ 天：[将 avframe 转成 CMSampleBufferRef，使用 AVSampleBufferDisplayLayer 渲染，60fps](md/006.md) √
- 第 ⑦ 天：[使用 AudioUnit 渲染音频](md/007.md)
- 第 ⑧ 天：[使用 AudioQueue 渲染音频](md/008.md)
- 第 ⑨ 天：[封装 MRMoviePlayer 视频播放器](md/009.md)
- 第 ⑩ 天：[拓展：使用 OpenGL 渲染视频](md/010.md)
- 第 ⑪ 天：[移植到 Mac 平台](md/011.md)
- 第 ⑫ 天：[移植到 Win 平台](md/012.md)

# Usage

克隆该仓库之后，项目并不能运行起来，因为项目依赖的 FFmpeg 库还没有下载下载，需要执行**一次**脚本:

```
sh init.sh
```

然后就会自动下载并且解压好需要的 FFmpeg 库了！

编译好的 FFmpeg 库放在[这里](https://github.com/debugly/FFmpeg-iOS-build-script/tree/source)，需要的话可以单独下载使用！
