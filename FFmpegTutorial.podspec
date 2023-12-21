#
# Be sure to run `pod lib lint FFmpegTutorial.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'FFmpegTutorial'
  s.version          = '0.5.24'
  s.summary          = '适合 iOS/macOS 开发人员学习的 FFmpeg 教程.'
  s.description      = <<-DESC
  帮助零基础的 iOS/macOS 开发人员快速学习FFmpeg和音视频渲染技术。
                       DESC

  s.homepage         = 'https://debugly.cn/FFmpegTutorial/'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'MattReach' => 'qianlongxu@gmail.com' }
  s.source           = { :git => 'https://github.com/debugly/FFmpegTutorial.git', :tag => s.version.to_s }

  s.ios.deployment_target = '11.0'
  s.osx.deployment_target = '10.13'
  # s.static_framework = true
  
  s.subspec 'common' do |ss|
    ss.source_files = 'FFmpegTutorial/Classes/common/**/*.{h,c,m,metal}'
    ss.public_header_files = [
      'FFmpegTutorial/Classes/common/*.h',
      'FFmpegTutorial/Classes/common/hud/*.h',
      'FFmpegTutorial/Classes/common/videoRenderer/IJKVideoRenderingProtocol.h',
      'FFmpegTutorial/Classes/common/videoRenderer/IJKOverlayAttach.h'
    ]
    ss.private_header_files = 'FFmpegTutorial/Classes/common/headers/private/*.h'
    ss.osx.exclude_files = 'FFmpegTutorial/Classes/common/hud/ios/*.*', 'FFmpegTutorial/Classes/common/videoRenderer/ios/*.*'
    ss.ios.exclude_files = 'FFmpegTutorial/Classes/common/hud/mac/*.*', 'FFmpegTutorial/Classes/common/videoRenderer/mac/*.*'
  end

  s.subspec '0x01' do |ss|
    ss.source_files = 'FFmpegTutorial/Classes/0x01/*.{h,m}'
    ss.public_header_files = 'FFmpegTutorial/Classes/0x01/*.h'
    ss.ios.exclude_files = 'FFmpegTutorial/Classes/0x01/FFTOpenGLVersionHelper.{h,m}'
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
    ss.public_header_files = 'FFmpegTutorial/Classes/0x10/FFTPlayer0x10.h'
  end

  s.subspec '0x20' do |ss|
    ss.source_files = 'FFmpegTutorial/Classes/0x20/*.{h,m}'
    ss.public_header_files = 'FFmpegTutorial/Classes/0x20/FFTPlayer0x20.h'
  end

  s.subspec '0x30' do |ss|
    ss.source_files = 'FFmpegTutorial/Classes/0x30/*.{h,m}'
    ss.public_header_files = 'FFmpegTutorial/Classes/0x30/FFTPlayer0x30.h'
  end

  s.subspec '0x31' do |ss|
    ss.source_files = 'FFmpegTutorial/Classes/0x31/*.{h,m}'
    ss.public_header_files = 'FFmpegTutorial/Classes/0x31/FFTPlayer0x31.h'
  end

  s.subspec '0x32' do |ss|
    ss.source_files = 'FFmpegTutorial/Classes/0x32/*.{h,m}'
    ss.public_header_files = 'FFmpegTutorial/Classes/0x32/FFTPlayer0x32.h'
  end

  s.subspec '0x33' do |ss|
    ss.source_files = 'FFmpegTutorial/Classes/0x33/**/*.{h,m}'
    ss.public_header_files = 'FFmpegTutorial/Classes/0x33/FFTPlayer0x33.h'
  end

  s.subspec '0x34' do |ss|
    ss.source_files = 'FFmpegTutorial/Classes/0x34/**/*.{h,m}'
    ss.public_header_files = 'FFmpegTutorial/Classes/0x34/FFTPlayer0x34.h'
  end

  s.subspec '0x35' do |ss|
    ss.source_files = 'FFmpegTutorial/Classes/0x35/**/*.{h,m}'
    ss.public_header_files = 'FFmpegTutorial/Classes/0x35/FFTPlayer0x35.h'
  end

  s.subspec '0x50' do |ss|
    ss.source_files = 'FFmpegTutorial/Classes/0x50/*.{h,m}'
    ss.public_header_files = 'FFmpegTutorial/Classes/0x50/FFTPlayer0x50.h'
  end

  s.pod_target_xcconfig = {
    'GCC_PREPROCESSOR_DEFINITIONS' => '$(inherited) IJK_USE_METAL_2=1',
    'MTL_LANGUAGE_REVISION' => 'Metal20'
  }
  s.ios.pod_target_xcconfig = { 'HEADER_SEARCH_PATHS' => '${PODS_ROOT}/../../../build/product/ios/universal/ffmpeg/include'}
  s.ios.xcconfig = { 'HEADER_SEARCH_PATHS' => '${PODS_ROOT}/../../../build/product/ios/universal/ffmpeg/include'}
  s.ios.vendored_libraries = 'build/product/ios/universal/*/lib/*.a'
  s.ios.framework = 'OpenGLES',"CoreFoundation","CoreVideo","VideoToolbox","CoreMedia","AudioToolbox","Security"

  s.osx.pod_target_xcconfig = { 'HEADER_SEARCH_PATHS' => '${PODS_ROOT}/../../../build/product/macos/universal/ffmpeg/include'}
  s.osx.xcconfig = { 'HEADER_SEARCH_PATHS' => '${PODS_ROOT}/../../../build/product/macos/universal/ffmpeg/include'}
  s.osx.vendored_libraries = 'build/product/macos/universal/*/lib/*.a'
  s.osx.frameworks = 'OpenGL',"CoreFoundation","CoreVideo","VideoToolbox","CoreMedia","AudioToolbox","Security"

  s.libraries = "z","bz2","iconv","lzma","xml2"

end
