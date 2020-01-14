# FFmpeg Version

FF_3_4_7='3.4.7'
FF_4_2_2='4.2.2'

# use_frameworks!
platform :ios,'8.0'

workspace 'StudyFFmpeg.xcworkspace'

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
line(16)
Pod_Target('FFmpeg002')
line(16)
Pod_Target('FFmpeg003')
line(16)
Pod_Target('FFmpeg004')
line(16)
Pod_Target('FFmpeg005')
line(16)
Pod_Target('FFmpeg006')
line(16)
Pod_Target('FFmpeg006-1')
line(16)
Pod_Target('FFmpeg007')
line(16)
Pod_Target('FFmpeg008')
line(16)
Pod_Target('FFmpeg009')
line(40)
