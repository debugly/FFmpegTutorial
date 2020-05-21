#
# Be sure to run `pod lib lint FFmpegTutorial.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'FFmpegTutorial'
  s.version          = '0.1.5'
  s.summary          = 'A short description of FFmpegTutorial.'

# This description is used to generate tags and improve search results.
#   * Think: What does it do? Why did you write it? What is the focus?
#   * Try to keep it short, snappy and to the point.
#   * Write the description between the DESC delimiters below.
#   * Finally, don't worry about the indent, CocoaPods strips it!

  s.description      = <<-DESC
TODO: Add long description of the pod here.
                       DESC

  s.homepage         = 'https://github.com/qianlongxu/FFmpegTutorial'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'MattReach' => 'qianlongxu@gmail.com' }
  s.source           = { :git => 'https://github.com/debugly/FFmpegTutorial.git', :tag => s.version.to_s }

  s.ios.deployment_target = '8.0'
  s.static_framework = true
  
  s.subspec 'common' do |ss|
    ss.source_files = 'FFmpegTutorial/Classes/common/**/*.{h,m}'
    ss.public_header_files = 'FFmpegTutorial/Classes/common/headers/public/*.h' 'FFmpegTutorial/Classes/common/*.h'
    ss.private_header_files = 'FFmpegTutorial/Classes/common/headers/private/*.h'
  end

  s.subspec '0x01' do |ss|
    ss.source_files = 'FFmpegTutorial/Classes/0x01/*.{h,m}'
    ss.public_header_files = 'FFmpegTutorial/Classes/0x01/*.h'
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

  s.dependency 'MRFFmpegPod'
  
end
