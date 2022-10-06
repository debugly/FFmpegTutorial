#
# Be sure to run `pod lib lint FFmpegTutorial.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'FFmpegTutorial'
  s.version          = '0.5.12'
  s.summary          = '适合 iOS/macOS 开发人员学习的 FFmpeg 教程.'
  s.description      = <<-DESC
  为了让更多零基础的 iOS/macOS 开发人员少走弯路，我编写了这个 FFmpeg 学习教程，最终的目标是封装一个播放器。
                       DESC

  s.homepage         = 'https://debugly.cn/FFmpegTutorial/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'MattReach' => 'qianlongxu@gmail.com' }
  s.source           = { :git => 'https://github.com/debugly/FFmpegTutorial.git', :tag => s.version.to_s }

  s.ios.deployment_target = '9.0'
  s.osx.deployment_target = '10.11'
  s.static_framework = true
  
  s.subspec 'common' do |ss|
    ss.source_files = 'FFmpegTutorial/Classes/common/**/*.{h,c,m}'
    ss.public_header_files = [
      'FFmpegTutorial/Classes/common/*.h',
      'FFmpegTutorial/Classes/common/hud/*.h',
      'FFmpegTutorial/Classes/common/videoRenderer/mac/MRVideoRendererProtocol.h'
    ]
    ss.private_header_files = 'FFmpegTutorial/Classes/common/headers/private/*.h'
    ss.osx.exclude_files = 'FFmpegTutorial/Classes/common/hud/ios/*.*'
    ss.ios.exclude_files = 'FFmpegTutorial/Classes/common/hud/mac/*.*'
  end

  s.subspec '0x01' do |ss|
    ss.source_files = 'FFmpegTutorial/Classes/0x01/*.{h,m}'
    ss.public_header_files = 'FFmpegTutorial/Classes/0x01/*.h'
    ss.ios.exclude_files = 'FFmpegTutorial/Classes/0x01/OpenGLVersionHelper.{h,m}'
  end
  
  s.subspec '0x02' do |ss|
    ss.source_files = 'FFmpegTutorial/Classes/0x02/*.{h,m}'
    ss.public_header_files = 'FFmpegTutorial/Classes/0x02/*.h'
  end

  s.subspec '0x03' do |ss|
    ss.source_files = 'FFmpegTutorial/Classes/0x03/*.{h,m}'
    ss.public_header_files = 'FFmpegTutorial/Classes/0x03/*.h'
  end

  s.subspec '0x04' do |ss|
    ss.source_files = 'FFmpegTutorial/Classes/0x04/*.{h,m}'
    ss.public_header_files = 'FFmpegTutorial/Classes/0x04/*.h'
  end

  s.subspec '0x05' do |ss|
    ss.source_files = 'FFmpegTutorial/Classes/0x05/*.{h,m}'
    ss.public_header_files = 'FFmpegTutorial/Classes/0x05/*.h'
  end

  s.subspec '0x06' do |ss|
    ss.source_files = 'FFmpegTutorial/Classes/0x06/*.{h,m}'
    ss.public_header_files = 'FFmpegTutorial/Classes/0x06/*.h'
  end

  s.subspec '0x10' do |ss|
    ss.source_files = 'FFmpegTutorial/Classes/0x10/*.{h,m}'
    ss.public_header_files = 'FFmpegTutorial/Classes/0x10/FFPlayer0x10.h'
  end

  s.subspec '0x20' do |ss|
    ss.source_files = 'FFmpegTutorial/Classes/0x20/*.{h,m}'
    ss.public_header_files = 'FFmpegTutorial/Classes/0x20/FFPlayer0x20.h'
  end

  s.subspec '0x31' do |ss|
    ss.source_files = 'FFmpegTutorial/Classes/0x31/*.{h,m}'
    ss.public_header_files = 'FFmpegTutorial/Classes/0x31/FFPlayer0x31.h'
  end

  s.subspec '0x32' do |ss|
    ss.source_files = 'FFmpegTutorial/Classes/0x32/*.{h,m}'
    ss.public_header_files = 'FFmpegTutorial/Classes/0x32/FFPlayer0x32.h', 'FFmpegTutorial/Classes/0x32/MRVideoRendererProtocol.h'
  end

  s.subspec '0x33' do |ss|
    ss.source_files = 'FFmpegTutorial/Classes/0x33/**/*.{h,m}'
    ss.public_header_files = 'FFmpegTutorial/Classes/0x33/FFPlayer0x33.h', 'FFmpegTutorial/Classes/0x33/MRVideoRendererProtocol.h', 'FFmpegTutorial/Classes/0x33/MR0x33AudioRendererProtocol.h'
  end

  s.subspec '0x34' do |ss|
    ss.source_files = 'FFmpegTutorial/Classes/0x34/**/*.{h,m}'
    ss.public_header_files = 'FFmpegTutorial/Classes/0x34/FFPlayer0x34.h', 'FFmpegTutorial/Classes/0x34/MRVideoRendererProtocol.h', 'FFmpegTutorial/Classes/0x34/MR0x34AudioRendererProtocol.h'
  end

  s.subspec '0x35' do |ss|
    ss.source_files = 'FFmpegTutorial/Classes/0x35/**/*.{h,m}'
    ss.public_header_files = 'FFmpegTutorial/Classes/0x35/FFPlayer0x35.h', 'FFmpegTutorial/Classes/0x35/MRVideoRendererProtocol.h', 'FFmpegTutorial/Classes/0x35/MR0x35AudioRendererProtocol.h'
  end

  s.subspec '0x36' do |ss|
    ss.source_files = 'FFmpegTutorial/Classes/0x36/**/*.{h,m}'
    ss.public_header_files = 'FFmpegTutorial/Classes/0x36/FFPlayer0x36.h', 'FFmpegTutorial/Classes/0x36/MRVideoRendererProtocol.h', 'FFmpegTutorial/Classes/0x36/MR0x36AudioRendererProtocol.h'
  end

  s.subspec '0x50' do |ss|
    ss.source_files = 'FFmpegTutorial/Classes/0x50/*.{h,m}'
    ss.public_header_files = 'FFmpegTutorial/Classes/0x50/FFPlayer0x50.h'
  end

  s.dependency 'MRFFmpegPod'
  s.osx.framework = 'OpenGL'
  s.ios.framework = 'OpenGLES'

end
