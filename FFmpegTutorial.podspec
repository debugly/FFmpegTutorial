#
# Be sure to run `pod lib lint FFmpegTutorial.podspec' to ensure this is a
# valid spec before submitting.
#
# Any lines starting with a # are optional, but their use is encouraged
# To learn more about a Podspec see https://guides.cocoapods.org/syntax/podspec.html
#

Pod::Spec.new do |s|
  s.name             = 'FFmpegTutorial'
  s.version          = '0.1.0'
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
  # s.screenshots     = 'www.example.com/screenshots_1', 'www.example.com/screenshots_2'
  s.license          = { :type => 'MIT', :file => 'LICENSE' }
  s.author           = { 'MattReach' => 'qianlongxu@gmail.com' }
  s.source           = { :git => 'https://github.com/debugly/FFmpegTutorial.git', :tag => s.version.to_s }
  # s.social_media_url = 'https://twitter.com/<TWITTER_USERNAME>'

  s.ios.deployment_target = '8.0'
  s.static_framework = true
  
  s.subspec '0x01' do |ss|
    ss.source_files = 'FFmpegTutorial/Classes/0x01/**/*'
    ss.public_header_files = 'FFmpegTutorial/Classes/0x01/**/*.h'
  end
  
  # s.source_files = 'FFmpegTutorial/Classes/**/*'
  # s.resource_bundles = {
  #   'FFmpegTutorial' => ['FFmpegTutorial/Assets/*.png']
  # }

  # s.public_header_files = 'Pod/Classes/**/*.h'
  # s.frameworks = 'UIKit', 'MapKit'
  # s.dependency 'AFNetworking', '~> 2.3'
  s.dependency 'MRFFmpegPod'
end
