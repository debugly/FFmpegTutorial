# use_frameworks!
platform :ios,'8.0'

workspace 'StudyFFmpeg.xcworkspace'
FF_3_4_7='3.4.7'
FF_4_2_2='4.2.2'

def Pod_FF(prjo,v)
  
    project "#{prjo}/#{prjo}.xcodeproj"
    
    pod 'MRFFmpegPod', :podspec => "https://raw.githubusercontent.com/debugly/MRFFmpeg-Libs/master/MRFFmpeg#{v}.podspec"
end

def Pod_Target(t,v=FF_3_4_7)
  
  puts("Target:#{t} will use FFmpeg:#{v}")
  target t do
      Pod_FF(t,v)
  end
  
  
end

def line(c)
  if c >= 0 then
    arr = Array.new(c) {
      '-'
    }
    puts(arr.join(''))
  end
end

line(40)
Pod_Target('FFmpeg001')
line(40)
