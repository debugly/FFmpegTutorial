
[![](ffmpeg.png)](http://ffmpeg.org/)
 
> 我对 FFmpeg 充满了兴趣，因此找些资料自己学习下，目标是封装个 iOS 版的播放器，这个工程是我练习的demo，记录我学习的过程。

先下载个 Mac 平台的，为日后封装 iOS 版播放器提供帮助，比如查看视频的相关信息，确定audio streamid，audio video streamid 等，这些都很有帮助！

# 下载 Mac 平台的

地址：[http://www.ffmpegmac.net/](http://www.ffmpegmac.net/)

下载完毕后加入到 bin 目录，然后随便找个视频

- 使用 ffmpeg 转码

```c
ffmpeg -i ~/Desktop/ffmpeg-test/uglybetty.mp4 ~/Desktop/ffmpeg-test/ugly.mov
``` 
 
更多的参数含义可查看 [雷霄骅博客](http://blog.csdn.net/leixiaohua1020/article/details/12751349).
 
- 使用 ffprobe 查看视频格式信息
 
```c
ffprobe ugly.mov 
ffprobe version 3.3 Copyright (c) 2007-2017 the FFmpeg developers
built with llvm-gcc 4.2.1 (LLVM build 2336.11.00)
configuration: --prefix=/Volumes/Ramdisk/sw --enable-gpl --enable-pthreads --enable-version3 --enable-libspeex --enable-libvpx --disable-decoder=libvpx --enable-libmp3lame --enable-libtheora --enable-libvorbis --enable-libx264 --enable-avfilter --enable-libopencore_amrwb --enable-libopencore_amrnb --enable-filters --enable-libgsm --enable-libvidstab --enable-libx265 --disable-doc --arch=x86_64 --enable-runtime-cpudetect
libavutil      55. 58.100 / 55. 58.100
libavcodec     57. 89.100 / 57. 89.100
libavformat    57. 71.100 / 57. 71.100
libavdevice    57.  6.100 / 57.  6.100
libavfilter     6. 82.100 /  6. 82.100
libswscale      4.  6.100 /  4.  6.100
libswresample   2.  7.100 /  2.  7.100
libpostproc    54.  5.100 / 54.  5.100
Input #0, mov,mp4,m4a,3gp,3g2,mj2, from 'ugly.mov':
Metadata:
major_brand     : qt  
minor_version   : 512
compatible_brands: qt  
encoder         : Lavf57.71.100
Duration: 00:04:57.71, start: 0.000000, bitrate: 483 kb/s
Stream #0:0(eng): Video: h264 (High) (avc1 / 0x31637661), yuv420p, 608x336 [SAR 1:1 DAR 38:21], 347 kb/s, 24 fps, 24 tbr, 12288 tbn, 48 tbc (default)
Metadata:
  handler_name    : DataHandler
  encoder         : Lavc57.89.100 libx264
Stream #0:1(eng): Audio: aac (LC) (mp4a / 0x6134706D), 44100 Hz, stereo, fltp, 129 kb/s (default)
Metadata:
  handler_name    : DataHandler

```